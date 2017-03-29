
local ModelRobot = requireFW("src.global.functions.class")("ModelRobot")

local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local DamageCalculator       = requireFW("src.app.utilities.DamageCalculator")
local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local MovePathFunctions      = requireFW("src.app.utilities.MovePathFunctions")
local ReachableAreaFunctions = requireFW("src.app.utilities.ReachableAreaFunctions")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")

local assert, pairs = assert, pairs
local math, table   = math, table

local ACTION_CODES = ActionCodeFunctions.getFullList()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function popRandomElement(array)
    local length = #array
    if (length == 0) then
        return nil
    else
        local index = math.random(length)
        local element = array[index]
        table.remove(array, index)
        return element
    end
end

local function isModelUnitLoaded(self, modelUnit)
    return self.m_ModelUnitMap:getLoadedModelUnitWithUnitId(modelUnit:getUnitId()) ~= nil
end

local function getReachableArea(self, modelUnit, passableGridIndex, blockedGridIndex)
    local modelUnitMap = self.m_ModelUnitMap
    local modelTileMap = self.m_ModelTileMap
    local mapSize      = modelUnitMap:getMapSize()

    return ReachableAreaFunctions.createArea(
        modelUnit:getGridIndex(),
        math.min(modelUnit:getMoveRange(), modelUnit:getCurrentFuel()),
        function(gridIndex)
            if ((not GridIndexFunctions.isWithinMap(gridIndex, mapSize))                            or
                ((blockedGridIndex) and (GridIndexFunctions.isEqual(gridIndex, blockedGridIndex)))) then
                return nil
            elseif ((passableGridIndex) and (GridIndexFunctions.isEqual(gridIndex, passableGridIndex))) then
                return modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(modelUnit)
            else
                local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
                if ((existingModelUnit) and (existingModelUnit:getTeamIndex() ~= modelUnit:getTeamIndex())) then
                    return nil
                else
                    return modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(modelUnit)
                end
            end
        end
    )
end

local function getPossibleDamageInPlayerTurn(self, robotUnit, gridIndex)
    local modelWar            = self.m_ModelWar
    local playerIndexForHuman = self.m_PlayerIndexForHuman
    local modelUnitMap        = self.m_ModelUnitMap
    local unitType            = robotUnit:getUnitType()
    local damage              = 0
    local mapSize             = modelUnitMap:getMapSize()
    local passableGridIndex
    if ((not GridIndexFunctions.isEqual(robotUnit:getGridIndex(), gridIndex)) and (not isModelUnitLoaded(self, robotUnit))) then
        passableGridIndex = robotUnit:getGridIndex()
    end

    modelUnitMap:forEachModelUnitOnMap(function(attacker)
        if ((attacker:getPlayerIndex() == playerIndexForHuman) and
            (attacker.getBaseDamage)                           and
            (attacker:getBaseDamage(unitType)))                then

            local minRange, maxRange = attacker:getAttackRangeMinMax()
            if (not attacker:canAttackAfterMove()) then
                local attackerGridIndex = attacker:getGridIndex()
                local distance          = GridIndexFunctions.getDistance(attackerGridIndex, gridIndex)
                if ((distance <= maxRange) and (distance >= minRange)) then
                    damage = damage + DamageCalculator.getAttackDamage(attacker, attackerGridIndex, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true)
                end
            else
                local reachableArea = getReachableArea(self, attacker, passableGridIndex, gridIndex)
                for _, gridIndexWithinAttackRange in pairs(GridIndexFunctions.getGridsWithinDistance(gridIndex, minRange, maxRange, mapSize)) do
                    local x, y = gridIndexWithinAttackRange.x, gridIndexWithinAttackRange.y
                    if ((reachableArea[x]) and (reachableArea[x][y])) then
                        damage = damage + DamageCalculator.getAttackDamage(attacker, gridIndexWithinAttackRange, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true)
                        break
                    end
                end
            end
        end
    end)

    modelUnitMap:forEachModelUnitLoaded(function(attacker)
        local loader = modelUnitMap:getModelUnit(attacker:getGridIndex())
        if ((attacker:getPlayerIndex() == playerIndexForHuman) and
            (attacker.getBaseDamage)                           and
            (attacker:getBaseDamage(unitType))                 and
            (attacker:canAttackAfterMove())                    and
            (loader:hasLoadUnitId(attacker:getUnitId()))       and
            (loader:canLaunchModelUnit()))                     then

            local minRange, maxRange = attacker:getAttackRangeMinMax()
            local reachableArea      = getReachableArea(self, attacker, passableGridIndex, gridIndex)
            for _, gridIndexWithinAttackRange in pairs(GridIndexFunctions.getGridsWithinDistance(gridIndex, minRange, maxRange, mapSize)) do
                local x, y = gridIndexWithinAttackRange.x, gridIndexWithinAttackRange.y
                if ((reachableArea[x]) and (reachableArea[x][y])) then
                    damage = damage + DamageCalculator.getAttackDamage(attacker, gridIndexWithinAttackRange, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true)
                    break
                end
            end
        end
    end)

    return damage
end

--------------------------------------------------------------------------------
-- The score calculators.
--------------------------------------------------------------------------------
local function getScoreForPosition(self, modelUnit, gridIndex)
    local score = getPossibleDamageInPlayerTurn(self, modelUnit, gridIndex) * (-1)                                              -- ADJUSTABLE

    local modelTile = self.m_ModelTileMap:getModelTile(gridIndex)
    if ((modelTile.canRepairTarget) and (modelTile:canRepairTarget(modelUnit))) then
        score = score + (10 - modelUnit:getNormalizedCurrentHP()) * 10                                                          -- ADJUSTABLE
        if ((modelUnit.hasPrimaryWeapon) and (modelUnit:hasPrimaryWeapon())) then
            local maxAmmo = modelUnit:getPrimaryWeaponMaxAmmo()
            score = score + (maxAmmo - modelUnit:getPrimaryWeaponCurrentAmmo()) / maxAmmo * 5                                   -- ADJUSTABLE
        end
    end

    if ((modelTile:getTeamIndex() == modelUnit:getTeamIndex())) then
        local tileType = modelTile:getTileType()
        if     (tileType == "Factory") then score = score + (-200)                                                              -- ADJUSTABLE
        elseif (tileType == "Airport") then score = score + (-50)                                                               -- ADJUSTABLE
        elseif (tileType == "Seaport") then score = score + (-30)                                                               -- ADJUSTABLE
        end
    end

    if (self.m_PlayerHqGridIndex) then
        score = score + GridIndexFunctions.getDistance(gridIndex, self.m_PlayerHqGridIndex) * (-10)                             -- ADJUSTABLE
    end

    self.m_ModelUnitMap:forEachModelUnitOnMap(function(unitOnMap)
        if (unitOnMap:getPlayerIndex() == self.m_PlayerIndexForHuman) then
            score = score + GridIndexFunctions.getDistance(gridIndex, unitOnMap:getGridIndex()) * (-10)                         -- ADJUSTABLE
        elseif (unitOnMap ~= modelUnit) then
            score = score + GridIndexFunctions.getDistance(gridIndex, unitOnMap:getGridIndex()) * (-5)                          -- ADJUSTABLE
        end
    end)

    return score
end

--------------------------------------------------------------------------------
-- The action generators.
--------------------------------------------------------------------------------
local function generateActionCaptureModelTile(pathNodes)
    return {
        actionCode = ActionCodeFunctions.getActionCode("ActionCaptureModelTile"),
        path       = {pathNodes = pathNodes},
    }
end

local function generateActionWait(pathNodes)
    print(SerializationFunctions.toString(pathNodes))
    return {
        actionCode = ActionCodeFunctions.getActionCode("ActionWait"),
        path       = {pathNodes = pathNodes},
    }
end

--------------------------------------------------------------------------------
-- The candicate units generators.
--------------------------------------------------------------------------------
local function getCandicateUnitsForPhase1(self)
    local units               = {}
    local playerIndexForHuman = self.m_PlayerIndexForHuman
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() ~= playerIndexForHuman) and (modelUnit:isStateIdle()) and (modelUnit.isCapturingModelTile)) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

--------------------------------------------------------------------------------
-- The phases.
--------------------------------------------------------------------------------
-- Phase 1: move the infantries, meches and bikes.
local function getActionForPhase1(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase1(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 9
        return nil
    end

    local maxScore, actionForMaxScore
    local reachableArea = getReachableArea(self, candicateUnit)
    for x = 1, self.m_MapWidth do
        if (reachableArea[x]) then
            for y = 1, self.m_MapHeight do
                if (reachableArea[x][y]) then
                    local gridIndex        = {x = x, y = y}
                    local scoreForPosition = getScoreForPosition(self, candicateUnit, gridIndex)
                    local scoreForAct      = 0 -- TODO: calculate the score

                    local totalScore = scoreForPosition + scoreForAct
                    if ((not maxScore)                                        or
                        (totalScore > maxScore)                               or
                        ((totalScore == maxScore) and (math.random(2) == 1))) then
                        maxScore          = totalScore
                        actionForMaxScore = generateActionWait(MovePathFunctions.createShortestPath(gridIndex, reachableArea))
                    end
                end
            end
        end
    end

    return actionForMaxScore
end

-- Phase 2: request the ranged units to attack enemy.
local function getActionForPhase2(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase2(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 3
        return nil
    end
end

-- Phase 9: end turn.
local function getActionForPhase9(self)
    self.m_PhaseCode = nil
    return {actionCode = ACTION_CODES.ActionEndTurn}
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelRobot:ctor()
    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running.
--------------------------------------------------------------------------------
function ModelRobot:onStartRunning(modelWar)
    self.m_ModelWar                   = modelWar
    self.m_ModelPlayerManager         = SingletonGetters.getModelPlayerManager(modelWar)
    self.m_ModelTileMap               = SingletonGetters.getModelTileMap(      modelWar)
    self.m_ModelTurnManager           = SingletonGetters.getModelTurnManager(  modelWar)
    self.m_ModelUnitMap               = SingletonGetters.getModelUnitMap(      modelWar)
    self.m_MapSize                    = self.m_ModelTileMap:getMapSize()
    self.m_MapWidth, self.m_MapHeight = self.m_MapSize.width, self.m_MapSize.height
    self.m_PlayerIndexForHuman        = self.m_ModelPlayerManager:getPlayerIndexForHuman()

    self.m_ModelTileMap:forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == self.m_PlayerIndexForHuman) and (modelTile:getTileType() == "Headquaters")) then
            self.m_PlayerHqGridIndex = modelTile:getGridIndex()
        end
    end)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelRobot:getNextAction()
    print("ModelRobot:getNextAction()")
    local modelTurnManager = self.m_ModelTurnManager
    assert((modelTurnManager:getPlayerIndex() ~= self.m_PlayerIndexForHuman) and (modelTurnManager:isTurnPhaseMain()))

    self.m_PhaseCode = self.m_PhaseCode or 1
    local action
    if ((not action) and (self.m_PhaseCode == 1)) then action = getActionForPhase1(self) end
    if ((not action) and (self.m_PhaseCode == 2)) then action = getActionForPhase2(self) end
    if ((not action) and (self.m_PhaseCode == 3)) then action = getActionForPhase3(self) end
    if ((not action) and (self.m_PhaseCode == 4)) then action = getActionForPhase4(self) end
    if ((not action) and (self.m_PhaseCode == 5)) then action = getActionForPhase5(self) end
    if ((not action) and (self.m_PhaseCode == 6)) then action = getActionForPhase6(self) end
    if ((not action) and (self.m_PhaseCode == 7)) then action = getActionForPhase7(self) end
    if ((not action) and (self.m_PhaseCode == 8)) then action = getActionForPhase8(self) end
    if ((not action) and (self.m_PhaseCode == 9)) then action = getActionForPhase9(self) end

    return action
end

return ModelRobot
