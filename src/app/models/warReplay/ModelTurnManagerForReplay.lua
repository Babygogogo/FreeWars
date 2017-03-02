
local ModelTurnManagerForReplay = requireFW("src.global.functions.class")("ModelTurnManagerForReplay")

local Destroyers       = requireFW("src.app.utilities.Destroyers")
local SingletonGetters = requireFW("src.app.utilities.SingletonGetters")
local SupplyFunctions  = requireFW("src.app.utilities.SupplyFunctions")

local destroyActorUnitOnMap    = Destroyers.destroyActorUnitOnMap
local getModelPlayerManager    = SingletonGetters.getModelPlayerManager
local getModelFogMap           = SingletonGetters.getModelFogMap
local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher
local supplyWithAmmoAndFuel    = SupplyFunctions.supplyWithAmmoAndFuel

local TURN_PHASE_CODES = {
    RequestToBegin                    = 1,
    Beginning                         = 2,
    GetFund                           = 3,
    ConsumeUnitFuel                   = 4,
    RepairUnit                        = 5,
    SupplyUnit                        = 6,
    Main                              = 7,
    ResetUnitState                    = 8,
    ResetVisionForEndingTurnPlayer    = 9,
    TickTurnAndPlayerIndex            = 10,
    ResetSkillState                   = 11,
    ResetVisionForBeginningTurnPlayer = 12,
    ResetVotedForDraw                 = 13,
}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getNextTurnAndPlayerIndex(self, playerManager)
    local nextTurnIndex   = self.m_TurnIndex
    local nextPlayerIndex = self.m_PlayerIndex + 1
    local playersCount    = playerManager:getPlayersCount()

    while (true) do
        if (nextPlayerIndex > playersCount) then
            nextPlayerIndex = 1
            nextTurnIndex   = nextTurnIndex + 1
        end

        assert(nextPlayerIndex ~= self.m_PlayerIndex, "ModelTurnManagerForReplay-getNextTurnAndPlayerIndex() the number of alive players is less than 2.")

        if (playerManager:getModelPlayer(nextPlayerIndex):isAlive()) then
            return nextTurnIndex, nextPlayerIndex
        else
            nextPlayerIndex = nextPlayerIndex + 1
        end
    end
end

local function repairModelUnit(self, modelUnit, repairAmount)
    modelUnit:setCurrentHP(modelUnit:getCurrentHP() + repairAmount)
    local hasSupplied = supplyWithAmmoAndFuel(modelUnit, true)

    if (not self.m_ModelWarReplay:isFastExecutingActions()) then
        modelUnit:updateView()

        if (repairAmount >= 10) then
            SingletonGetters.getModelGridEffect(self.m_ModelWarReplay):showAnimationRepair(modelUnit:getGridIndex())
        elseif (hasSupplied) then
            SingletonGetters.getModelGridEffect(self.m_ModelWarReplay):showAnimationSupply(modelUnit:getGridIndex())
        end
    end
end

--------------------------------------------------------------------------------
-- The functions that runs each turn phase.
--------------------------------------------------------------------------------
local function runTurnPhaseBeginning(self)
    local modelWarReplay = self.m_ModelWarReplay
    local modelPlayer    = getModelPlayerManager(modelWarReplay):getModelPlayer(self.m_PlayerIndex)
    local callbackOnBeginTurnEffectDisappear = function()
        self.m_TurnPhaseCode = TURN_PHASE_CODES.GetFund
        self:runTurn()
    end

    if (not modelWarReplay:isFastExecutingActions()) then
        self.m_View:showBeginTurnEffect(self.m_TurnIndex, modelPlayer:getNickname(), callbackOnBeginTurnEffectDisappear)
    else
        callbackOnBeginTurnEffectDisappear()
    end
end

local function runTurnPhaseGetFund(self)
    if (self.m_IncomeForNextTurn) then
        local modelPlayer = getModelPlayerManager(self.m_ModelWarReplay):getModelPlayer(self.m_PlayerIndex)
        modelPlayer:setFund(modelPlayer:getFund() + self.m_IncomeForNextTurn)
        self.m_IncomeForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ConsumeUnitFuel
end

local function runTurnPhaseConsumeUnitFuel(self)
    if (self.m_TurnIndex > 1) then
        local modelWarReplay       = self.m_ModelWarReplay
        local playerIndexActing   = self.m_PlayerIndex
        local modelTileMap        = getModelTileMap(modelWarReplay)
        local modelUnitMap        = getModelUnitMap(modelWarReplay)
        local modelFogMap         = getModelFogMap( modelWarReplay)
        local mapSize             = modelTileMap:getMapSize()
        local dispatcher          = getScriptEventDispatcher(modelWarReplay)

        modelUnitMap:forEachModelUnitOnMap(function(modelUnit)
            if ((modelUnit:getPlayerIndex() == playerIndexActing) and
                (modelUnit.setCurrentFuel))                       then
                local newFuel = math.max(modelUnit:getCurrentFuel() - modelUnit:getFuelConsumptionPerTurn(), 0)
                modelUnit:setCurrentFuel(newFuel)
                    :updateView()

                if ((newFuel == 0) and (modelUnit:shouldDestroyOnOutOfFuel())) then
                    local gridIndex = modelUnit:getGridIndex()
                    local modelTile = modelTileMap:getModelTile(gridIndex)

                    if ((not modelTile.canRepairTarget) or (not modelTile:canRepairTarget(modelUnit))) then
                        modelFogMap:updateMapForPathsWithModelUnitAndPath(modelUnit, {gridIndex})
                        destroyActorUnitOnMap(modelWarReplay, gridIndex, true)
                        dispatcher:dispatchEvent({
                            name      = "EvtDestroyViewUnit",
                            gridIndex = gridIndex,
                        })
                    end
                end
            end
        end)
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.RepairUnit
end

local function runTurnPhaseRepairUnit(self)
    local repairData = self.m_RepairDataForNextTurn
    if (repairData) then
        local modelWarReplay = self.m_ModelWarReplay
        local modelUnitMap  = getModelUnitMap(modelWarReplay)

        if (repairData.onMapData) then
            for unitID, data in pairs(repairData.onMapData) do
                repairModelUnit(self, modelUnitMap:getModelUnit(data.gridIndex), data.repairAmount)
            end
        end
        if (repairData.loadedData) then
            for unitID, data in pairs(repairData.loadedData) do
                repairModelUnit(self, modelUnitMap:getLoadedModelUnitWithUnitId(unitID), data.repairAmount)
            end
        end

        getModelPlayerManager(modelWarReplay):getModelPlayer(self.m_PlayerIndex):setFund(repairData.remainingFund)
        self.m_RepairDataForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.SupplyUnit
end

local function runTurnPhaseSupplyUnit(self)
    local supplyData = self.m_SupplyDataForNextTurn
    if (supplyData) then
        local modelWarReplay   = self.m_ModelWarReplay
        local modelUnitMap    = getModelUnitMap(modelWarReplay)
        local modelGridEffect = (not modelWarReplay:isFastExecutingActions()) and (SingletonGetters.getModelGridEffect(modelWarReplay)) or (nil)

        if (supplyData.onMapData) then
            for unitID, data in pairs(supplyData.onMapData) do
                local gridIndex = data.gridIndex
                supplyWithAmmoAndFuel(modelUnitMap:getModelUnit(gridIndex), true)
                if (modelGridEffect) then
                    modelGridEffect:showAnimationSupply(gridIndex)
                end
            end
        end

        if (supplyData.loadedData) then
            for unitID, data in pairs(supplyData.loadedData) do
                local modelUnit = modelUnitMap:getLoadedModelUnitWithUnitId(unitID)
                supplyWithAmmoAndFuel(modelUnit, true)
                if (modelGridEffect) then
                    modelGridEffect:showAnimationSupply(modelUnit:getGridIndex())
                end
            end
        end

        self.m_SupplyDataForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.Main
end

local function runTurnPhaseMain(self)
    local modelWarReplay    = self.m_ModelWarReplay
    local playerIndex      = self.m_PlayerIndex
    getScriptEventDispatcher(modelWarReplay):dispatchEvent({
            name        = "EvtModelPlayerUpdated",
            modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex),
            playerIndex = playerIndex,
        })
        :dispatchEvent({name = "EvtModelUnitMapUpdated"})
        :dispatchEvent({name = "EvtModelTileMapUpdated"})
end

local function runTurnPhaseResetUnitState(self)
    local playerIndex = self.m_PlayerIndex
    local func        = function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            modelUnit:setStateIdle()
                :updateView()
        end
    end

    getModelUnitMap(self.m_ModelWarReplay):forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVisionForEndingTurnPlayer
end

local function runTurnPhaseResetVisionForEndingTurnPlayer(self)
    local modelFogMap = SingletonGetters.getModelFogMap(self.m_ModelWarReplay)
    modelFogMap:resetMapForPathsForPlayerIndex(self:getPlayerIndex())

    if (not self.m_ModelWarReplay:isFastExecutingActions()) then
        modelFogMap:updateView()
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.TickTurnAndPlayerIndex
end

local function runTurnPhaseTickTurnAndPlayerIndex(self)
    local modelPlayerManager = getModelPlayerManager(self.m_ModelWarReplay)
    self.m_TurnIndex, self.m_PlayerIndex = getNextTurnAndPlayerIndex(self, modelPlayerManager)

    getScriptEventDispatcher(self.m_ModelWarReplay):dispatchEvent({
        name        = "EvtPlayerIndexUpdated",
        playerIndex = self.m_PlayerIndex,
        modelPlayer = modelPlayerManager:getModelPlayer(self.m_PlayerIndex),
    })

    -- TODO: Change the weather.
    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetSkillState
end

local function runTurnPhaseResetSkillState(self)
    local playerIndex = self.m_PlayerIndex
    local modelPlayer = getModelPlayerManager(self.m_ModelWarReplay):getModelPlayer(playerIndex)
    modelPlayer:setActivatingSkill(false)
        :setCanActivateSkill(modelPlayer:isSkillDeclared())
        :setSkillDeclared(false)
        :getModelSkillConfiguration():mergePassiveAndResearchingSkills()

    local func = function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            modelUnit:updateView()
        end
    end
    getModelUnitMap(self.m_ModelWarReplay):forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVisionForBeginningTurnPlayer
end

local function runTurnPhaseResetVisionForBeginningTurnPlayer(self)
    local playerIndex = self:getPlayerIndex()
    local modelFogMap = SingletonGetters.getModelFogMap(self.m_ModelWarReplay)
    modelFogMap:resetMapForTilesForPlayerIndex(playerIndex)
        :resetMapForUnitsForPlayerIndex(playerIndex)

    if (not self.m_ModelWarReplay:isFastExecutingActions()) then
        modelFogMap:updateView()
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVotedForDraw
end

local function runTurnPhaseResetVotedForDraw(self)
    getModelPlayerManager(self.m_ModelWarReplay):getModelPlayer(self.m_PlayerIndex):setVotedForDraw(false)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.RequestToBegin
end

local function runTurnPhaseRequestToBegin(self)
    -- Do nothing.
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelTurnManagerForReplay:ctor(param)
    self.m_TurnIndex     = param.turnIndex
    self.m_PlayerIndex   = param.playerIndex
    self.m_TurnPhaseCode = param.turnPhaseCode

    return self
end

function ModelTurnManagerForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay = modelWarReplay

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelTurnManagerForReplay:toSerializableTable()
    return {
        turnIndex     = self:getTurnIndex(),
        playerIndex   = self:getPlayerIndex(),
        turnPhaseCode = self.m_TurnPhaseCode,
    }
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTurnManagerForReplay:getTurnIndex()
    return self.m_TurnIndex
end

function ModelTurnManagerForReplay:getPlayerIndex()
    return self.m_PlayerIndex
end

function ModelTurnManagerForReplay:isTurnPhaseRequestToBegin()
    return self.m_TurnPhaseCode == TURN_PHASE_CODES.RequestToBegin
end

function ModelTurnManagerForReplay:isTurnPhaseMain()
    return self.m_TurnPhaseCode == TURN_PHASE_CODES.Main
end

function ModelTurnManagerForReplay:runTurn()
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.Beginning)                         then runTurnPhaseBeginning(                        self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.GetFund)                           then runTurnPhaseGetFund(                          self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ConsumeUnitFuel)                   then runTurnPhaseConsumeUnitFuel(                  self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.RepairUnit)                        then runTurnPhaseRepairUnit(                       self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.SupplyUnit)                        then runTurnPhaseSupplyUnit(                       self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.Main)                              then runTurnPhaseMain(                             self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ResetUnitState)                    then runTurnPhaseResetUnitState(                   self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ResetVisionForEndingTurnPlayer)    then runTurnPhaseResetVisionForEndingTurnPlayer(   self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.TickTurnAndPlayerIndex)            then runTurnPhaseTickTurnAndPlayerIndex(           self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ResetSkillState)                   then runTurnPhaseResetSkillState(                  self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ResetVisionForBeginningTurnPlayer) then runTurnPhaseResetVisionForBeginningTurnPlayer(self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.ResetVotedForDraw)                 then runTurnPhaseResetVotedForDraw(                self) end
    if (self.m_TurnPhaseCode == TURN_PHASE_CODES.RequestToBegin)                    then runTurnPhaseRequestToBegin(                   self) end

    if ((self.m_TurnPhaseCode == TURN_PHASE_CODES.Main) and (self.m_CallbackOnEnterTurnPhaseMainForNextTurn)) then
        self.m_CallbackOnEnterTurnPhaseMainForNextTurn()
        self.m_CallbackOnEnterTurnPhaseMainForNextTurn = nil
    end

    return self
end

function ModelTurnManagerForReplay:beginTurnPhaseBeginning(income, repairData, supplyData, callbackOnEnterTurnPhaseMain)
    assert(self:isTurnPhaseRequestToBegin(), "ModelTurnManagerForReplay:beginTurnPhaseBeginning() invalid turn phase code: " .. self.m_TurnPhaseCode)

    self.m_IncomeForNextTurn                       = income
    self.m_RepairDataForNextTurn                   = repairData
    self.m_SupplyDataForNextTurn                   = supplyData
    self.m_CallbackOnEnterTurnPhaseMainForNextTurn = callbackOnEnterTurnPhaseMain

    runTurnPhaseBeginning(self)

    return self
end

function ModelTurnManagerForReplay:endTurnPhaseMain()
    assert(self:isTurnPhaseMain(), "ModelTurnManagerForReplay:endTurnPhaseMain() invalid turn phase code: " .. self.m_TurnPhaseCode)
    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetUnitState
    self:runTurn()

    return self
end

return ModelTurnManagerForReplay
