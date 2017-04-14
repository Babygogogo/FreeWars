
local ModelTurnManagerForNative = requireFW("src.global.functions.class")("ModelTurnManagerForNative")

local ActionCodeFunctions   = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions    = requireFW("src.app.utilities.AuxiliaryFunctions")
local Destroyers            = requireFW("src.app.utilities.Destroyers")
local GridIndexFunctions    = requireFW("src.app.utilities.GridIndexFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")
local SupplyFunctions       = requireFW("src.app.utilities.SupplyFunctions")
local VisibilityFunctions   = requireFW("src.app.utilities.VisibilityFunctions")

local getAdjacentGrids         = GridIndexFunctions.getAdjacentGrids
local getLocalizedText         = LocalizationFunctions.getLocalizedText
local getModelFogMap           = SingletonGetters.getModelFogMap
local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher
local isUnitVisible            = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local isTileVisible            = VisibilityFunctions.isTileVisibleToPlayerIndex
local supplyWithAmmoAndFuel    = SupplyFunctions.supplyWithAmmoAndFuel

local cc               = cc
local math, os, string = math, os, string

local ACTION_CODE_BEGIN_TURN = ActionCodeFunctions.getActionCode("ActionBeginTurn")
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
local DEFAULT_TURN_DATA = {
    turnIndex     = 1,
    playerIndex   = 1,
    turnPhaseCode = TURN_PHASE_CODES.RequestToBegin,
}
local BOOT_REMINDER_INTERVAL      = 20
local BOOT_REMINDER_STARTING_TIME = 60 * 30

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function isModelUnitDiving(modelUnit)
    return (modelUnit.isDiving) and (modelUnit:isDiving())
end

local function getNextTurnAndPlayerIndex(self, playerManager)
    local nextTurnIndex   = self.m_TurnIndex
    local nextPlayerIndex = self.m_PlayerIndex + 1
    local playersCount    = playerManager:getPlayersCount()

    while (true) do
        if (nextPlayerIndex > playersCount) then
            nextPlayerIndex = 1
            nextTurnIndex   = nextTurnIndex + 1
        end

        assert(nextPlayerIndex ~= self.m_PlayerIndex, "ModelTurnManagerForNative-getNextTurnAndPlayerIndex() the number of alive players is less than 2.")

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

    modelUnit:updateView()

    if (isUnitVisible(self.m_ModelWar, modelUnit:getGridIndex(), modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), self.m_PlayerIndexForHuman)) then
        if (repairAmount >= 10) then
            SingletonGetters.getModelGridEffect(self.m_ModelWar):showAnimationRepair(modelUnit:getGridIndex())
        elseif (hasSupplied) then
            SingletonGetters.getModelGridEffect(self.m_ModelWar):showAnimationSupply(modelUnit:getGridIndex())
        end
    end
end

local function updateTileAndUnitMapOnVisibilityChanged(self)
    local modelWar    = self.m_ModelWar
    local playerIndex = self.m_PlayerIndexForHuman
    getModelUnitMap(modelWar):forEachModelUnitOnMap(function(modelUnit)
        modelUnit:setViewVisible(isUnitVisible(modelWar, modelUnit:getGridIndex(), modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), playerIndex))
    end)

    getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        modelTile:updateView()
    end)

    getScriptEventDispatcher(modelWar)
        :dispatchEvent({name = "EvtModelTileMapUpdated"})
        :dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

--------------------------------------------------------------------------------
-- The functions that runs each turn phase.
--------------------------------------------------------------------------------
local function runTurnPhaseBeginning(self)
    local callbackOnBeginTurnEffectDisappear = function()
        self.m_TurnPhaseCode = TURN_PHASE_CODES.GetFund
        self:runTurn()
    end

    self.m_View:showBeginTurnEffect(self.m_TurnIndex, self.m_ModelPlayerManager:getModelPlayer(self.m_PlayerIndex):getNickname(), callbackOnBeginTurnEffectDisappear)
end

local function runTurnPhaseGetFund(self)
    if (self.m_IncomeForNextTurn) then
        local modelPlayer = self.m_ModelPlayerManager:getModelPlayer(self.m_PlayerIndex)
        modelPlayer:setFund(modelPlayer:getFund() + self.m_IncomeForNextTurn)
        self.m_IncomeForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ConsumeUnitFuel
end

local function runTurnPhaseConsumeUnitFuel(self)
    if (self.m_TurnIndex > 1) then
        local modelWar            = self.m_ModelWar
        local playerIndexActing   = self.m_PlayerIndex
        local modelTileMap        = getModelTileMap(modelWar)
        local modelUnitMap        = getModelUnitMap(modelWar)
        local modelFogMap         = getModelFogMap( modelWar)
        local mapSize             = modelTileMap:getMapSize()
        local dispatcher          = getScriptEventDispatcher(modelWar)
        local playerIndexForHuman = self.m_PlayerIndexForHuman
        local shouldUpdateFogMap  = self.m_ModelPlayerManager:isSameTeamIndex(playerIndexActing, playerIndexForHuman)

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
                        if (shouldUpdateFogMap) then
                            modelFogMap:updateMapForPathsWithModelUnitAndPath(modelUnit, {gridIndex})
                        end
                        Destroyers.destroyActorUnitOnMap(modelWar, gridIndex, true)
                        dispatcher:dispatchEvent({
                            name      = "EvtDestroyViewUnit",
                            gridIndex = gridIndex,
                        })

                        if (playerIndexActing == playerIndexForHuman) then
                            for _, adjacentGridIndex in pairs(getAdjacentGrids(gridIndex, mapSize)) do
                                local adjacentModelUnit = modelUnitMap:getModelUnit(adjacentGridIndex)
                                if (adjacentModelUnit) then
                                    adjacentModelUnit:setViewVisible(isUnitVisible(modelWar, adjacentGridIndex, adjacentModelUnit:getUnitType(), isModelUnitDiving(adjacentModelUnit), adjacentModelUnit:getPlayerIndex(), playerIndexActing))
                                end
                            end
                        end
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
        local modelWar = self.m_ModelWar
        local modelUnitMap  = getModelUnitMap(modelWar)

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

        self.m_ModelPlayerManager:getModelPlayer(self.m_PlayerIndex):setFund(repairData.remainingFund)
        self.m_RepairDataForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.SupplyUnit
end

local function runTurnPhaseSupplyUnit(self)
    local supplyData = self.m_SupplyDataForNextTurn
    if (supplyData) then
        local modelWar        = self.m_ModelWar
        local modelUnitMap    = getModelUnitMap(modelWar)
        local modelGridEffect = SingletonGetters.getModelGridEffect(modelWar)

        if (supplyData.onMapData) then
            for unitID, data in pairs(supplyData.onMapData) do
                local gridIndex = data.gridIndex
                local modelUnit = modelUnitMap:getModelUnit(gridIndex)
                supplyWithAmmoAndFuel(modelUnit, true)

                if (isUnitVisible(modelWar, gridIndex, modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), self.m_PlayerIndexForHuman)) then
                    modelGridEffect:showAnimationSupply(gridIndex)
                end
            end
        end

        if (supplyData.loadedData) then
            for unitID, data in pairs(supplyData.loadedData) do
                local modelUnit = modelUnitMap:getLoadedModelUnitWithUnitId(unitID)
                supplyWithAmmoAndFuel(modelUnit, true)

                local gridIndex = modelUnit:getGridIndex()
                local loader    = modelUnitMap:getModelUnit(gridIndex)
                if (isUnitVisible(modelWar, gridIndex, loader:getUnitType(), isModelUnitDiving(loader), loader:getPlayerIndex(), self.m_PlayerIndexForHuman)) then
                    modelGridEffect:showAnimationSupply(gridIndex)
                end
            end
        end

        self.m_SupplyDataForNextTurn = nil
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.Main
end

local function runTurnPhaseMain(self)
    local modelWar    = self.m_ModelWar
    local playerIndex = self.m_PlayerIndex
    getScriptEventDispatcher(modelWar):dispatchEvent({
            name        = "EvtModelPlayerUpdated",
            modelPlayer = self.m_ModelPlayerManager:getModelPlayer(playerIndex),
            playerIndex = playerIndex,
        })
        :dispatchEvent({name = "EvtModelUnitMapUpdated"})
        :dispatchEvent({name = "EvtModelTileMapUpdated"})
end

local function runTurnPhaseResetUnitState(self)
    local playerIndex      = self.m_PlayerIndex
    local func             = function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            modelUnit:setStateIdle()
                :updateView()
        end
    end

    getModelUnitMap(self.m_ModelWar):forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVisionForEndingTurnPlayer
end

local function runTurnPhaseResetVisionForEndingTurnPlayer(self)
    local playerIndex = self:getPlayerIndex()
    if (self.m_ModelPlayerManager:isSameTeamIndex(playerIndex, self.m_PlayerIndexForHuman)) then
        getModelFogMap(self.m_ModelWar):resetMapForPathsForPlayerIndex(playerIndex)
        updateTileAndUnitMapOnVisibilityChanged(self)
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.TickTurnAndPlayerIndex
end

local function runTurnPhaseTickTurnAndPlayerIndex(self)
    local modelPlayerManager = self.m_ModelPlayerManager
    self.m_TurnIndex, self.m_PlayerIndex = getNextTurnAndPlayerIndex(self, modelPlayerManager)

    getScriptEventDispatcher(self.m_ModelWar):dispatchEvent({
        name        = "EvtPlayerIndexUpdated",
        playerIndex = self.m_PlayerIndex,
        modelPlayer = modelPlayerManager:getModelPlayer(self.m_PlayerIndex),
    })

    -- TODO: Change the weather.
    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetSkillState
end

local function runTurnPhaseResetSkillState(self)
    local playerIndex = self.m_PlayerIndex
    local modelPlayer = self.m_ModelPlayerManager:getModelPlayer(playerIndex)
    modelPlayer:setActivatingSkill(false)
        :setCanActivateSkill(modelPlayer:isSkillDeclared())
        :setSkillDeclared(false)
        :getModelSkillConfiguration():mergePassiveAndResearchingSkills()

    local func = function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            modelUnit:updateView()
        end
    end

    getModelUnitMap(self.m_ModelWar):forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVisionForBeginningTurnPlayer
end

local function runTurnPhaseResetVisionForBeginningTurnPlayer(self)
    local playerIndex = self:getPlayerIndex()
    if (self.m_ModelPlayerManager:isSameTeamIndex(playerIndex, self.m_PlayerIndexForHuman)) then
        getModelFogMap(self.m_ModelWar):resetMapForTilesForPlayerIndex(playerIndex)
            :resetMapForUnitsForPlayerIndex(playerIndex)
        updateTileAndUnitMapOnVisibilityChanged(self)
    end

    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetVotedForDraw
end

local function runTurnPhaseResetVotedForDraw(self)
    self.m_ModelPlayerManager:getModelPlayer(self.m_PlayerIndex):setVotedForDraw(false)

    self.m_TurnPhaseCode = TURN_PHASE_CODES.RequestToBegin
end

local function runTurnPhaseRequestToBegin(self)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelTurnManagerForNative:ctor(param)
    self.m_TurnIndex     = param.turnIndex
    self.m_PlayerIndex   = param.playerIndex
    self.m_TurnPhaseCode = param.turnPhaseCode

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelTurnManagerForNative:toSerializableTable()
    return {
        turnIndex     = self:getTurnIndex(),
        playerIndex   = self:getPlayerIndex(),
        turnPhaseCode = self.m_TurnPhaseCode,
    }
end

--------------------------------------------------------------------------------
-- The public functions for doing actions.
--------------------------------------------------------------------------------
function ModelTurnManagerForNative:onStartRunning(modelWar)
    self.m_ModelWar             = modelWar
    self.m_ModelPlayerManager   = SingletonGetters.getModelPlayerManager(modelWar)
    self.m_ModelMessageIndiator = SingletonGetters.getModelMessageIndicator(modelWar)
    self.m_PlayerIndexForHuman  = self.m_ModelPlayerManager:getPlayerIndexForHuman()

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTurnManagerForNative:getTurnIndex()
    return self.m_TurnIndex
end

function ModelTurnManagerForNative:getPlayerIndex()
    return self.m_PlayerIndex
end

function ModelTurnManagerForNative:isTurnPhaseRequestToBegin()
    return self.m_TurnPhaseCode == TURN_PHASE_CODES.RequestToBegin
end

function ModelTurnManagerForNative:isTurnPhaseMain()
    return self.m_TurnPhaseCode == TURN_PHASE_CODES.Main
end

function ModelTurnManagerForNative:runTurn()
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

function ModelTurnManagerForNative:beginTurnPhaseBeginning(income, repairData, supplyData, callbackOnEnterTurnPhaseMain)
    assert(self:isTurnPhaseRequestToBegin(), "ModelTurnManagerForNative:beginTurnPhaseBeginning() invalid turn phase code: " .. self.m_TurnPhaseCode)

    self.m_IncomeForNextTurn                       = income
    self.m_RepairDataForNextTurn                   = repairData
    self.m_SupplyDataForNextTurn                   = supplyData
    self.m_CallbackOnEnterTurnPhaseMainForNextTurn = callbackOnEnterTurnPhaseMain

    runTurnPhaseBeginning(self)

    return self
end

function ModelTurnManagerForNative:endTurnPhaseMain()
    assert(self:isTurnPhaseMain(), "ModelTurnManagerForNative:endTurnPhaseMain() invalid turn phase code: " .. self.m_TurnPhaseCode)
    self.m_TurnPhaseCode = TURN_PHASE_CODES.ResetUnitState
    self:runTurn()

    return self
end

return ModelTurnManagerForNative
