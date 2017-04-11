
local ModelRobot = requireFW("src.global.functions.class")("ModelRobot")

local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local DamageCalculator       = requireFW("src.app.utilities.DamageCalculator")
local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local MovePathFunctions      = requireFW("src.app.utilities.MovePathFunctions")
local ReachableAreaFunctions = requireFW("src.app.utilities.ReachableAreaFunctions")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local TableFunctions         = requireFW("src.app.utilities.TableFunctions")
local Actor                  = requireFW("src.global.actors.Actor")

local assert, pairs = assert, pairs
local math, table   = math, table

local ACTION_CODES          = ActionCodeFunctions.getFullList()
local SEARCH_PATH_LENGTH    = 10
local PRODUCTION_CANDIDATES = {                                                                                             -- ADJUSTABLE
    Factory = {
        Infantry   = 1500,
        Mech       = 0,
        Bike       = 1200,
        Recon      = -999999,
        Flare      = -999999,
        AntiAir    = 500,
        Tank       = 2000,
        MediumTank = 1800,
        WarTank    = 1600,
        Artillery  = 1400,
        AntiTank   = 1000,
        Rockets    = 200,
        Missiles   = -999999,
        Rig        = -999999,
    },
    Airport = {
        Fighter         = -999999,
        Bomber          = 0,
        Duster          = 1200,
        BattleCopter    = 1800,
        TransportCopter = -999999,
    },
    Seaport = {
        Battleship = 0,
        Carrier    = -999999,
        Submarine  = 0,
        Cruiser    = 900,
        Lander     = -999999,
        Gunboat    = 1000,
    }
}

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

local function calculateUnitValueRatio(self)
    local aiUnitValue, humanUnitValue = 0, 0
    local func                        = function(modelUnit)
        if (modelUnit:getPlayerIndex() == self.m_PlayerIndexForHuman) then
            humanUnitValue = humanUnitValue + modelUnit:getProductionCost() * modelUnit:getCurrentHP() / 100
        else
            aiUnitValue    = aiUnitValue    + modelUnit:getProductionCost() * modelUnit:getCurrentHP() / 100
        end
    end

    self.m_ModelUnitMap:forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    if (humanUnitValue > 0) then
        return aiUnitValue / humanUnitValue
    else
        return 1
    end
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

local function getReachableAreaOnCandicateGridIndex(self, modelUnit, candicateGridIndex)
    local modelTileMap = self.m_ModelTileMap
    local mapSize      = modelTileMap:getMapSize()
    return ReachableAreaFunctions.createArea(
        candicateGridIndex,
        math.max(SEARCH_PATH_LENGTH, modelUnit:getMoveRange()),
        function(gridIndex)
            if (not GridIndexFunctions.isWithinMap(gridIndex, mapSize)) then
                return nil
            else
                return modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(modelUnit)
            end
        end
    )
end

local function getPossibleDamageInPlayerTurn(self, robotUnit, gridIndex, minBaseDamage)
    minBaseDamage             = minBaseDamage or 0
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
        if ((attacker:getPlayerIndex() == playerIndexForHuman) and (attacker.getBaseDamage)) then
            local baseDamage = attacker:getBaseDamage(unitType)
            if ((not baseDamage) or (baseDamage < minBaseDamage)) then
                return
            end

            local minRange, maxRange = attacker:getAttackRangeMinMax()
            if (not attacker:canAttackAfterMove()) then
                local attackerGridIndex = attacker:getGridIndex()
                local distance          = GridIndexFunctions.getDistance(attackerGridIndex, gridIndex)
                if ((distance <= maxRange) and (distance >= minRange)) then
                    damage = damage + DamageCalculator.getAttackDamage(attacker, attackerGridIndex, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true)
                end
            elseif (maxRange + math.min(attacker:getMoveRange(), attacker:getCurrentFuel()) >= GridIndexFunctions.getDistance(attacker:getGridIndex(), gridIndex)) then
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

local function isUnitThreatened(self, robotUnit, gridIndex, minDamage)
    minDamage                 = math.min(minDamage or 50, robotUnit:getCurrentHP())
    local modelWar            = self.m_ModelWar
    local playerIndexForHuman = self.m_PlayerIndexForHuman
    local modelUnitMap        = self.m_ModelUnitMap
    local unitType            = robotUnit:getUnitType()
    local mapSize             = modelUnitMap:getMapSize()
    local isThreatened        = false
    local passableGridIndex
    if ((not GridIndexFunctions.isEqual(robotUnit:getGridIndex(), gridIndex)) and (not isModelUnitLoaded(self, robotUnit))) then
        passableGridIndex = robotUnit:getGridIndex()
    end

    modelUnitMap:forEachModelUnitOnMap(function(attacker)
        if ((not isThreatened) and (attacker:getPlayerIndex() == playerIndexForHuman) and (attacker.getBaseDamage) and (attacker:getBaseDamage(unitType))) then
            local minRange, maxRange = attacker:getAttackRangeMinMax()
            if (not attacker:canAttackAfterMove()) then
                local attackerGridIndex = attacker:getGridIndex()
                local distance          = GridIndexFunctions.getDistance(attackerGridIndex, gridIndex)
                if ((distance <= maxRange)                                                                                                                       and
                    (distance >= minRange)                                                                                                                       and
                    (DamageCalculator.getAttackDamage(attacker, attackerGridIndex, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true) >= minDamage)) then
                    isThreatened = true
                end

            elseif (maxRange + math.min(attacker:getMoveRange(), attacker:getCurrentFuel()) >= GridIndexFunctions.getDistance(attacker:getGridIndex(), gridIndex)) then
                local reachableArea = getReachableArea(self, attacker, passableGridIndex, gridIndex)
                for _, gridIndexWithinAttackRange in pairs(GridIndexFunctions.getGridsWithinDistance(gridIndex, minRange, maxRange, mapSize)) do
                    local x, y = gridIndexWithinAttackRange.x, gridIndexWithinAttackRange.y
                    if ((reachableArea[x])                                                                                                                                    and
                        (reachableArea[x][y])                                                                                                                                 and
                        (DamageCalculator.getAttackDamage(attacker, gridIndexWithinAttackRange, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true) >= minDamage)) then
                        isThreatened = true
                        break
                    end
                end
            end
        end
    end)

    modelUnitMap:forEachModelUnitLoaded(function(attacker)
        local loader = modelUnitMap:getModelUnit(attacker:getGridIndex())
        if ((not isThreatened)                                 and
            (attacker:getPlayerIndex() == playerIndexForHuman) and
            (attacker.getBaseDamage)                           and
            (attacker:getBaseDamage(unitType))                 and
            (attacker:canAttackAfterMove())                    and
            (loader:hasLoadUnitId(attacker:getUnitId()))       and
            (loader:canLaunchModelUnit()))                     then

            local minRange, maxRange = attacker:getAttackRangeMinMax()
            local reachableArea      = getReachableArea(self, attacker, passableGridIndex, gridIndex)
            for _, gridIndexWithinAttackRange in pairs(GridIndexFunctions.getGridsWithinDistance(gridIndex, minRange, maxRange, mapSize)) do
                local x, y = gridIndexWithinAttackRange.x, gridIndexWithinAttackRange.y
                if ((reachableArea[x])                                                                                                                                    and
                    (reachableArea[x][y])                                                                                                                                 and
                    (DamageCalculator.getAttackDamage(attacker, gridIndexWithinAttackRange, attacker:getCurrentHP(), robotUnit, gridIndex, modelWar, true) >= minDamage)) then
                    isThreatened = true
                    break
                end
            end
        end
    end)

    return isThreatened
end

local function getBetterScoreAndAction(oldScore, oldAction, newScore, newAction)
    if (not newScore) then
        return oldScore, oldAction
    elseif ((not oldScore)                                  or
        (newScore > oldScore)                               or
        ((newScore == oldScore) and (math.random(2) == 1))) then
        return newScore, newAction
    else
        return oldScore, oldAction
    end
end

--------------------------------------------------------------------------------
-- The score calculators.
--------------------------------------------------------------------------------
local function getScoreForPosition(self, modelUnit, gridIndex)
    local score
    if ((GameConstantFunctions.isTypeInCategory(modelUnit:getUnitType(), "InfantryUnits")) or (not isUnitThreatened(self, modelUnit, gridIndex))) then
        score = 0                                                                                                               -- ADJUSTABLE
    else
        score = -math.min(modelUnit:getCurrentHP(), 50) * (2 + modelUnit:getProductionCost() / 1000)                            -- ADJUSTABLE
    end

    local modelTile = self.m_ModelTileMap:getModelTile(gridIndex)
    if ((modelTile.canRepairTarget) and (modelTile:canRepairTarget(modelUnit))) then
        score = score + (10 - modelUnit:getNormalizedCurrentHP()) * 10                                                          -- ADJUSTABLE
        if ((modelUnit.hasPrimaryWeapon) and (modelUnit:hasPrimaryWeapon())) then
            local maxAmmo = modelUnit:getPrimaryWeaponMaxAmmo()
            score = score + (maxAmmo - modelUnit:getPrimaryWeaponCurrentAmmo()) / maxAmmo * 5                                   -- ADJUSTABLE
        end
    end

    local teamIndex = modelUnit:getTeamIndex()
    if (modelTile:getTeamIndex() == teamIndex) then
        local tileType = modelTile:getTileType()
        if     (tileType == "Factory") then score = score + (-500)                                                              -- ADJUSTABLE
        elseif (tileType == "Airport") then score = score + (-200)                                                              -- ADJUSTABLE
        elseif (tileType == "Seaport") then score = score + (-150)                                                              -- ADJUSTABLE
        end
    elseif ((modelTile.getCurrentCapturePoint) and (not modelUnit.getCaptureAmount)) then
        score = score - 50                                                                                                      -- ADJUSTABLE
    end

    local reachableArea = getReachableAreaOnCandicateGridIndex(self, modelUnit, gridIndex)
    local minDistanceToEnemyTiles
    self.m_ModelTileMap:forEachModelTile(function(modelTileOnMap)
        local x, y = modelTileOnMap:getGridIndex().x, modelTileOnMap:getGridIndex().y
        if ((reachableArea[x])                            and
            (reachableArea[x][y])                         and
            (modelTileOnMap.getCurrentCapturePoint)       and
            (modelTileOnMap:getTeamIndex() ~= teamIndex)) then
            local distance = reachableArea[x][y].totalMoveCost
            local tileType = modelTileOnMap:getTileType()
            if ((tileType == "Factory") or (tileType == "Airport") or (tileType == "Seaport") or (tileType == "CommandTower")) then
                distance = distance / 2                                                                                         -- ADJUSTABLE
            end
            if (modelTileOnMap:getPlayerIndex() == 0) then
                distance = distance / 2
            end
            if (modelTileOnMap:getCurrentCapturePoint() < 20) then
                distance = distance * 1.5                                                                                       -- ADJUSTABLE
            end

            if (not minDistanceToEnemyTiles) then
                minDistanceToEnemyTiles = distance
            else
                minDistanceToEnemyTiles = math.min(minDistanceToEnemyTiles, distance)
            end
        end
    end)
    if (minDistanceToEnemyTiles) then
        score = score + (minDistanceToEnemyTiles) * (-20)                                                                       -- ADJUSTABLE
    else
        score = score + (math.max(SEARCH_PATH_LENGTH, modelUnit:getMoveRange()) + 1) * (-20 * 1.5)                              -- ADJUSTABLE
    end

    local distanceToEnemyUnits, enemyUnitsCount = 0, 0
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnitOnMap)
        if (modelUnitOnMap:getPlayerIndex() == self.m_PlayerIndexForHuman) then
            distanceToEnemyUnits = distanceToEnemyUnits + GridIndexFunctions.getDistance(modelUnitOnMap:getGridIndex(), gridIndex)
            enemyUnitsCount      = enemyUnitsCount + 1
        end
    end)
    if (enemyUnitsCount > 0) then
        score = score + (distanceToEnemyUnits / enemyUnitsCount) * (-10)                                                        -- ADJUSTABLE
    end

    return score
end

local function getScoreForActionAttack(self, modelUnit, gridIndex, targetGridIndex, attackDamage, counterDamage)
    if (not attackDamage) then
        return nil
    end

    local targetTile = self.m_ModelTileMap:getModelTile(targetGridIndex)
    local tileType   = targetTile:getTileType()
    if (tileType == "Meteor") then
        return math.min(attackDamage, targetTile:getCurrentHP())                                                                -- ADJUSTABLE
    end

    local targetUnit = self.m_ModelUnitMap:getModelUnit(targetGridIndex)
    attackDamage     = math.min(attackDamage, targetUnit:getCurrentHP())
    local score      = 10 + attackDamage * (2 + targetUnit:getProductionCost() / 1000 + math.max(0, self.m_UnitValueRatio - 1)) -- ADJUSTABLE
    if (targetUnit:getCurrentHP() <= attackDamage) then
        score = score + 30                                                                                                      -- ADJUSTABLE
    end

    if ((targetUnit.isCapturingModelTile) and (targetUnit:isCapturingModelTile())) then
        if (targetTile:getCurrentCapturePoint() > targetUnit:getCaptureAmount()) then
            score = score + 20                                                                                                  -- ADJUSTABLE
        else
            score = score + 200                                                                                                 -- ADJUSTABLE
        end
        if ((tileType == "Headquarters") or (tileType == "Factory") or (tileType == "Airport") or (tileType == "Seaport")) then
            score = score + 99999                                                                                               -- ADJUSTABLE
        end
    end

    if (counterDamage) then
        local attackerHP = modelUnit:getCurrentHP()
        counterDamage    = math.min(counterDamage, attackerHP)
        score            = score + (-counterDamage * (2 + modelUnit:getProductionCost() / 1000))                                -- ADJUSTABLE
        if (attackerHP == counterDamage) then
            score = score + (-20)                                                                                               -- ADJUSTABLE
        end
    end

    return score
end

local function getScoreForActionCaptureModelTile(self, modelUnit, gridIndex)
    local modelTile           = self.m_ModelTileMap:getModelTile(gridIndex)
    local currentCapturePoint = modelTile:getCurrentCapturePoint()
    local captureAmount       = modelUnit:getCaptureAmount()
    if (captureAmount >= currentCapturePoint) then
        return 10000                                                                                                            -- ADJUSTABLE
    elseif (captureAmount < currentCapturePoint / 3) then
        return 0                                                                                                                -- ADJUSTABLE
    else
        local tileValue = 0
        local tileType  = modelTile:getTileType()
        if     (tileType == "Headquarters")  then tileValue = tileValue + 40                                                    -- ADJUSTABLE
        elseif (tileType == "Factory")       then tileValue = tileValue + 60                                                    -- ADJUSTABLE
        elseif (tileType == "Airport")       then tileValue = tileValue + 50                                                    -- ADJUSTABLE
        elseif (tileType == "Seaport")       then tileValue = tileValue + 50                                                    -- ADJUSTABLE
        elseif (tileType == "City")          then tileValue = tileValue + 40                                                    -- ADJUSTABLE
        elseif (tileType == "CommandTower")  then tileValue = tileValue + 60                                                    -- ADJUSTABLE
        elseif (tileType == "Radar")         then tileValue = tileValue + 40                                                    -- ADJUSTABLE
        else                                      tileValue = tileValue + 20                                                    -- ADJUSTABLE
        end

        if (captureAmount >= currentCapturePoint / 2) then
            return tileValue                                                                                                    -- ADJUSTABLE
        else
            return tileValue / 2                                                                                                -- ADJUSTABLE
        end
    end
end

local function getScoreForActionJoinModelUnit(self, modelUnit, gridIndex)
    if (self.m_ModelUnitMap:getModelUnit(gridIndex):isStateIdle()) then
        return nil
    end
    return -200                                                                                                                 -- ADJUSTABLE
end

local function getScoreForActionLaunchSilo(self, unitValueMap, targetGridIndex)
    local score = 10000                                                                                                         -- ADJUSTABLE
    for _, gridIndex in pairs(GridIndexFunctions.getGridsWithinDistance(targetGridIndex, 0, 2, self.m_MapSize)) do
        score = score + unitValueMap[gridIndex.x][gridIndex.y]                                                                  -- ADJUSTABLE
    end

    return score
end

local function getScoreForActionLoadModelUnit(self, modelUnit, gridIndex)
    local loader = self.m_ModelUnitMap:getModelUnit(gridIndex)
    if (not loader:canLaunchModelUnit()) then
        return -1000                                                                                                            -- ADJUSTABLE
    elseif (loader:canRepairLoadedModelUnit()) then
        return (10 - modelUnit:getNormalizedCurrentHP()) * 10                                                                   -- ADJUSTABLE
    else
        return 0
    end
end

local function getScoreForActionProduceModelUnitOnTile(self, gridIndex, tiledID, idleFactoriesCount)
    local modelUnit = Actor.createModel("warOnline.ModelUnitForOnline", {
        tiledID       = tiledID,
        unitID        = 0,
        GridIndexable = gridIndex,
    })
    modelUnit:onStartRunning(self.m_ModelWar)

    local playerIndexInTurn = modelUnit:getPlayerIndex()
    local productionCost    = modelUnit:getProductionCost()
    local fund              = self.m_ModelPlayerManager:getModelPlayer(playerIndexInTurn):getFund()
    if (productionCost > fund) then
        return nil
    end

    local tileType = self.m_ModelTileMap:getModelTile(gridIndex):getTileType()
    local unitType = modelUnit:getUnitType()
    local score    = PRODUCTION_CANDIDATES[tileType][unitType]                                                                  -- ADJUSTABLE
    if (((tileType == "Factory") and ((idleFactoriesCount - 1) * 1500 > (fund - productionCost)))  or
        ((tileType ~= "Factory") and ((idleFactoriesCount)     * 1500 > (fund - productionCost)))) then
        score = score + (-999999)                                                                                               -- ADJUSTABLE
    end

    score = score + (-getPossibleDamageInPlayerTurn(self, modelUnit, gridIndex, 15) * (2 + productionCost / 1000))              -- ADJUSTABLE

    self.m_ModelUnitMap:forEachModelUnitOnMap(function(unitOnMap)
        if (unitOnMap:getPlayerIndex() == self.m_PlayerIndexForHuman) then
            if (modelUnit.getBaseDamage) then
                local damage = math.min(modelUnit:getBaseDamage(unitOnMap:getUnitType()) or 0, unitOnMap:getCurrentHP())
                score = score + (damage * (2 + unitOnMap:getProductionCost() / 1000))                                           -- ADJUSTABLE
            end
            if (unitOnMap.getBaseDamage) then
                local damage = math.min((unitOnMap:getBaseDamage(unitType) or 0) * unitOnMap:getNormalizedCurrentHP() / 10, 100)
                score = score + (-damage * (2 + productionCost / 1000))                                                         -- ADJUSTABLE
            end
        elseif (unitOnMap:getUnitType() == unitType) then
            score = score + (-unitOnMap:getCurrentHP() * (2 + productionCost / 1000))                                           -- ADJUSTABLE
        end
    end)

    return score
end

local function getScoreForActionWait(self, modelUnit, gridIndex)
    local modelTile = self.m_ModelTileMap:getModelTile(gridIndex)
    if ((modelTile.getCurrentCapturePoint)                      and
        (not modelUnit.getCaptureAmount)                        and
        (modelTile:getTeamIndex() ~= modelUnit:getTeamIndex())) then
        return -20                                                                                                              -- ADJUSTABLE
    else
        return 0                                                                                                                -- ADJUSTABLE
    end
end

--------------------------------------------------------------------------------
-- The available action generators for units.
--------------------------------------------------------------------------------
local function getScoreAndActionAttack(self, modelUnit, gridIndex, pathNodes)
    if ((not modelUnit.getBaseDamage)                                                                                     or
        ((not modelUnit:canAttackAfterMove()) and (not GridIndexFunctions.isEqual(gridIndex, modelUnit:getGridIndex())))) then
        return nil, nil
    end

    local modelUnitMap      = self.m_ModelUnitMap
    local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
    if ((existingModelUnit) and (existingModelUnit ~= modelUnit)) then
        return nil, nil
    end

    local modelWar           = self.m_ModelWar
    local launchUnitID       = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil)
    local minRange, maxRange = modelUnit:getAttackRangeMinMax()
    local maxScore, actionForMaxScore

    for _, targetGridIndex in pairs(GridIndexFunctions.getGridsWithinDistance(gridIndex, minRange, maxRange, self.m_MapSize)) do
        local attackDamage, counterDamage = DamageCalculator.getUltimateBattleDamage(pathNodes, launchUnitID, targetGridIndex, modelWar)
        local newScore                    = getScoreForActionAttack(self, modelUnit, gridIndex, targetGridIndex, attackDamage, counterDamage)
        maxScore, actionForMaxScore       = getBetterScoreAndAction(maxScore, actionForMaxScore, newScore, {
            actionCode      = ACTION_CODES.ActionAttack,
            path            = {pathNodes = pathNodes},
            targetGridIndex = targetGridIndex,
            launchUnitID    = launchUnitID,
        })
    end

    return maxScore, actionForMaxScore
end

local function getScoreAndActionCaptureModelTile(self, modelUnit, gridIndex, pathNodes)
    local modelTile = self.m_ModelTileMap:getModelTile(gridIndex)
    if ((not modelUnit.canCaptureModelTile) or (not modelUnit:canCaptureModelTile(modelTile))) then
        return nil, nil
    end

    local existingModelUnit = self.m_ModelUnitMap:getModelUnit(gridIndex)
    if ((existingModelUnit) and (existingModelUnit ~= modelUnit)) then
        return nil, nil
    end

    return getScoreForActionCaptureModelTile(self, modelUnit, gridIndex), {
        actionCode   = ACTION_CODES.ActionCaptureModelTile,
        path         = {pathNodes = pathNodes},
        launchUnitID = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil),
    }
end

local function getScoreAndActionLaunchSilo(self, modelUnit, gridIndex, pathNodes)
    local modelUnitMap      = self.m_ModelUnitMap
    local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
    if ((existingModelUnit) and (existingModelUnit ~= modelUnit)) then
        return nil, nil
    end

    local tileType = self.m_ModelTileMap:getModelTile(gridIndex):getTileType()
    if ((not modelUnit.canLaunchSiloOnTileType) or (not modelUnit:canLaunchSiloOnTileType(tileType))) then
        return nil, nil
    end

    local unitValueMap = {}
    for x = 1, self.m_MapWidth do
        unitValueMap[x] = {}
        for y = 1, self.m_MapHeight do
            local targetModelUnit = modelUnitMap:getModelUnit({x = x, y = y})
            if ((not targetModelUnit) or (targetModelUnit == modelUnit)) then
                unitValueMap[x][y] = 0
            else
                local value = math.min(30, targetModelUnit:getCurrentHP() - 1) * targetModelUnit:getProductionCost() / 10
                unitValueMap[x][y] = (targetModelUnit:getPlayerIndex() == self.m_PlayerIndexForHuman) and (value) or (-value)
            end
        end
    end
    unitValueMap[gridIndex.x][gridIndex.y] = -math.min(30, modelUnit:getCurrentHP() - 1) * modelUnit:getProductionCost() / 10

    local maxScore, targetGridIndex
    for x = 1, self.m_MapWidth do
        for y = 1, self.m_MapHeight do
            local newTargetGridIndex = {x = x, y = y}
            maxScore, targetGridIndex = getBetterScoreAndAction(maxScore, targetGridIndex, getScoreForActionLaunchSilo(self, unitValueMap, newTargetGridIndex), newTargetGridIndex)
        end
    end

    return maxScore, {
        actionCode      = ACTION_CODES.ActionLaunchSilo,
        path            = {pathNodes = pathNodes},
        targetGridIndex = targetGridIndex,
        launchUnitID    = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil),
    }
end

local function getScoreAndActionJoinModelUnit(self, modelUnit, gridIndex, pathNodes)
    if (GridIndexFunctions.isEqual(gridIndex, modelUnit:getGridIndex())) then
        return nil, nil
    end

    local existingModelUnit = self.m_ModelUnitMap:getModelUnit(gridIndex)
    if ((not existingModelUnit) or (not modelUnit:canJoinModelUnit(existingModelUnit))) then
        return nil, nil
    end

    return getScoreForActionJoinModelUnit(self, modelUnit, gridIndex), {
        actionCode   = ACTION_CODES.ActionJoinModelUnit,
        path         = {pathNodes = pathNodes},
        launchUnitID = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil),
    }
end

local function getScoreAndActionLoadModelUnit(self, modelUnit, gridIndex, pathNodes)
    if (GridIndexFunctions.isEqual(gridIndex, modelUnit:getGridIndex())) then
        return nil, nil
    end

    local loader = self.m_ModelUnitMap:getModelUnit(gridIndex)
    if ((not loader)                                                                                         or
        (not loader.canLoadModelUnit)                                                                        or
        (not loader:canLoadModelUnit(modelUnit, self.m_ModelTileMap:getModelTile(gridIndex):getTileType()))) then
        return nil, nil
    end

    return getScoreForActionLoadModelUnit(self, modelUnit, gridIndex), {
        actionCode   = ACTION_CODES.ActionLoadModelUnit,
        path         = {pathNodes = pathNodes},
        launchUnitID = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil),
    }
end

local function getActionDive(self)
    local focusModelUnit = self.m_FocusModelUnit
    if ((focusModelUnit.canDive) and (focusModelUnit:canDive())) then
        return {
            name     = getLocalizedText(78, "Dive"),
            callback = function()
                sendActionDive(self)
            end,
        }
    end
end

local function getActionBuildModelTile(self)
    local tileType       = getModelTileMap(self.m_ModelWar):getModelTile(getPathNodesDestination(self.m_PathNodes)):getTileType()
    local focusModelUnit = self.m_FocusModelUnit

    if ((focusModelUnit.canBuildOnTileType)           and
        (focusModelUnit:canBuildOnTileType(tileType)) and
        (focusModelUnit:getCurrentMaterial() > 0))    then
        local buildTiledId = focusModelUnit:getBuildTiledIdWithTileType(tileType)
        local icon         = cc.Sprite:create()
        icon:setAnchorPoint(0, 0)
            :setScale(0.5)
            :playAnimationForever(AnimationLoader.getTileAnimationWithTiledId(buildTiledId))

        return {
            name     = getLocalizedText(78, "BuildModelTile"),
            icon     = icon,
            callback = function()
                sendActionBuildModelTile(self)
            end,
        }
    end
end

local function getActionSupplyModelUnit(self)
    local focusModelUnit = self.m_FocusModelUnit
    if (not focusModelUnit.canSupplyModelUnit) then
        return nil
    end

    local modelUnitMap = getModelUnitMap(self.m_ModelWar)
    for _, gridIndex in pairs(GridIndexFunctions.getAdjacentGrids(getPathNodesDestination(self.m_PathNodes), modelUnitMap:getMapSize())) do
        local modelUnit = modelUnitMap:getModelUnit(gridIndex)
        if ((modelUnit)                                     and
            (modelUnit ~= focusModelUnit)                   and
            (focusModelUnit:canSupplyModelUnit(modelUnit))) then
            return {
                name     = getLocalizedText(78, "SupplyModelUnit"),
                callback = function()
                    sendActionSupplyModelUnit(self)
                end,
            }
        end
    end

    return nil
end

local function getActionSurface(self)
    local focusModelUnit = self.m_FocusModelUnit
    if ((focusModelUnit.isDiving) and (focusModelUnit:isDiving())) then
        return {
            name     = getLocalizedText(78, "Surface"),
            callback = function()
                sendActionSurface(self)
            end,
        }
    end
end

local function getSingleActionDropModelUnit(self, unitID)
    local icon = Actor.createView("common.ViewUnit")
    icon:updateWithModelUnit(getModelUnitMap(self.m_ModelWar):getLoadedModelUnitWithUnitId(unitID))
        :ignoreAnchorPointForPosition(true)
        :setScale(0.5)

    return {
        name     = getLocalizedText(78, "DropModelUnit"),
        icon     = icon,
        callback = function()
            setStateChoosingDropDestination(self, unitID)
        end,
    }
end

local function getActionsDropModelUnit(self)
    local focusModelUnit        = self.m_FocusModelUnit
    local dropDestinations      = self.m_SelectedDropDestinations
    local modelTileMap          = getModelTileMap(self.m_ModelWar)
    local loaderEndingGridIndex = getPathNodesDestination(self.m_PathNodes)

    if ((not focusModelUnit.getCurrentLoadCount)                                                               or
        (focusModelUnit:getCurrentLoadCount() <= #dropDestinations)                                            or
        (not focusModelUnit:canDropModelUnit(modelTileMap:getModelTile(loaderEndingGridIndex):getTileType()))) then
        return {}
    end

    local actions = {}
    local loaderBeginningGridIndex = self.m_FocusModelUnit:getGridIndex()
    local modelUnitMap             = getModelUnitMap(self.m_ModelWar)

    for _, unitID in ipairs(focusModelUnit:getLoadUnitIdList()) do
        if (not isModelUnitDropped(unitID, dropDestinations)) then
            local droppingModelUnit = getModelUnitMap(self.m_ModelWar):getLoadedModelUnitWithUnitId(unitID)
            if (#getAvailableDropGrids(self, droppingModelUnit, loaderBeginningGridIndex, loaderEndingGridIndex, dropDestinations) > 0) then
                actions[#actions + 1] = getSingleActionDropModelUnit(self, unitID)
            end
        end
    end

    return actions
end

local function getActionLaunchSilo(self)
    local focusModelUnit = self.m_FocusModelUnit
    local modelTile      = getModelTileMap(self.m_ModelWar):getModelTile(getPathNodesDestination(self.m_PathNodes))

    if ((focusModelUnit.canLaunchSiloOnTileType) and
        (focusModelUnit:canLaunchSiloOnTileType(modelTile:getTileType()))) then
        return {
            name     = getLocalizedText(78, "LaunchSilo"),
            callback = function()
                setStateChoosingSiloTarget(self)
            end,
        }
    else
        return nil
    end
end

local function getActionProduceModelUnitOnUnit(self)
    local focusModelUnit = self.m_FocusModelUnit
    if ((self.m_LaunchUnitID)                            or
        (#self.m_PathNodes ~= 1)                         or
        (not focusModelUnit.getCurrentMaterial)          or
        (not focusModelUnit.getMovableProductionTiledId) or
        (not focusModelUnit.getCurrentLoadCount))        then
        return nil
    else
        local produceTiledId = focusModelUnit:getMovableProductionTiledId()
        local icon           = cc.Sprite:create()
        icon:setAnchorPoint(0, 0)
            :setScale(0.5)
            :playAnimationForever(AnimationLoader.getUnitAnimationWithTiledId(produceTiledId))

        return {
            name        = string.format("%s\n%d",
                getLocalizedText(78, "ProduceModelUnitOnUnit"),
                Producible.getProductionCostWithTiledId(produceTiledId, self.m_ModelPlayerManager)
            ),
            icon        = icon,
            isAvailable = (focusModelUnit:getCurrentMaterial() >= 1)                                and
                (focusModelUnit:getMovableProductionCost() <= self.m_ModelPlayerForHuman:getFund()) and
                (focusModelUnit:getCurrentLoadCount() < focusModelUnit:getMaxLoadCount()),
            callback    = function()
                sendActionProduceModelUnitOnUnit(self)
            end,
        }
    end
end

local function getScoreAndActionWait(self, modelUnit, gridIndex, pathNodes)
    local launchUnitID = (isModelUnitLoaded(self, modelUnit)) and (modelUnit:getUnitId()) or (nil)
    if (GridIndexFunctions.isEqual(modelUnit:getGridIndex(), gridIndex)) then
        if (launchUnitID) then
            return nil, nil
        else
            return getScoreForActionWait(self, modelUnit, gridIndex), {
                actionCode   = ACTION_CODES.ActionWait,
                path         = {pathNodes = pathNodes},
                launchUnitID = launchUnitID,
            }
        end
    else
        if (self.m_ModelUnitMap:getModelUnit(gridIndex)) then
            return nil, nil
        else
            return getScoreForActionWait(self, modelUnit, gridIndex), {
                actionCode   = ACTION_CODES.ActionWait,
                path         = {pathNodes = pathNodes},
                launchUnitID = launchUnitID,
            }
        end
    end
end

local function getMaxScoreAndAction(self, modelUnit, gridIndex, pathNodes)
    local scoreForActionLoadModelUnit, actionLoadModelUnit = getScoreAndActionLoadModelUnit(self, modelUnit, gridIndex, pathNodes)
    if (actionLoadModelUnit) then
        return scoreForActionLoadModelUnit, actionLoadModelUnit
    end

    local scoreForActionJoinModelUnit, actionJoinModelUnit = getScoreAndActionJoinModelUnit(self, modelUnit, gridIndex, pathNodes)
    if (actionJoinModelUnit) then
        return scoreForActionJoinModelUnit, actionJoinModelUnit
    end

    local maxScore, actionForMaxScore
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionAttack(          self, modelUnit, gridIndex, pathNodes))
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionCaptureModelTile(self, modelUnit, gridIndex, pathNodes))
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionLaunchSilo(      self, modelUnit, gridIndex, pathNodes))
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionWait(            self, modelUnit, gridIndex, pathNodes))

    return maxScore, actionForMaxScore
    --[[
    local list = {}
    list[#list + 1] = getActionDive(                  self)
    list[#list + 1] = getActionSurface(               self)
    list[#list + 1] = getActionBuildModelTile(        self)
    list[#list + 1] = getActionSupplyModelUnit(       self)
    for _, action in ipairs(getActionsDropModelUnit(self)) do
        list[#list + 1] = action
    end
    list[#list + 1] = getActionProduceModelUnitOnUnit(self)

    assert((#list > 0) or (itemWait), "ModelRobot-getMaxScoreAndAction() the generated list has no valid action item.")
    return list, itemWait
    ]]
end

local function getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
    local maxScore, actionForMaxScore
    local reachableArea = getReachableArea(self, candicateUnit)
    for x = 1, self.m_MapWidth do
        if (reachableArea[x]) then
            for y = 1, self.m_MapHeight do
                if (reachableArea[x][y]) then
                    local gridIndex              = {x = x, y = y}
                    local pathNodes              = MovePathFunctions.createShortestPath(gridIndex, reachableArea)
                    local scoreForAction, action = getMaxScoreAndAction(self, candicateUnit, gridIndex, pathNodes)
                    if (scoreForAction) then
                        local totalScore = scoreForAction + getScoreForPosition(self, candicateUnit, gridIndex)
                        maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, totalScore, action)
                    end
                end
            end
        end
    end

    return actionForMaxScore
end

--------------------------------------------------------------------------------
-- The available action generators for production.
--------------------------------------------------------------------------------
local function getMaxScoreAndActionProduceUnitOnTileWithGridIndex(self, gridIndex, idleFactoriesCount)
    local playerIndex = self.m_ModelTurnManager:getPlayerIndex()
    local maxScore, targetTiledID
    for unitType, _ in pairs(PRODUCTION_CANDIDATES[self.m_ModelTileMap:getModelTile(gridIndex):getTileType()]) do
        local tiledID = GameConstantFunctions.getTiledIdWithTileOrUnitName(unitType, playerIndex)
        maxScore, targetTiledID = getBetterScoreAndAction(maxScore, targetTiledID, getScoreForActionProduceModelUnitOnTile(self, gridIndex, tiledID, idleFactoriesCount), tiledID)
    end

    if (not maxScore) then
        return nil, nil
    else
        return maxScore, {
            actionCode = ACTION_CODES.ActionProduceModelUnitOnTile,
            gridIndex  = gridIndex,
            tiledID    = targetTiledID,
        }
    end
end

local function getActionProduceModelUnitOnTileForMaxScore(self)
    local playerIndexInTurn  = self.m_ModelTurnManager:getPlayerIndex()
    local modelUnitMap       = self.m_ModelUnitMap
    local idleBuildingsPos   = {}
    local idleFactoriesCount = 0

    self.m_ModelTileMap:forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == playerIndexInTurn)         and
            (not modelUnitMap:getModelUnit(modelTile:getGridIndex())) and
            (modelTile.getProductionList))                            then
            idleBuildingsPos[#idleBuildingsPos + 1] = modelTile:getGridIndex()
            if (modelTile:getTileType() == "Factory") then
                idleFactoriesCount = idleFactoriesCount + 1
            end
        end
    end)

    local maxScore, actionForMaxScore
    for _, gridIndex in pairs(idleBuildingsPos) do
        maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore,
            getMaxScoreAndActionProduceUnitOnTileWithGridIndex(self, gridIndex, idleFactoriesCount)
        )
    end

    return actionForMaxScore
end

--------------------------------------------------------------------------------
-- The candicate units generators.
--------------------------------------------------------------------------------
local function getCandidateUnitsForPhase1(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.isCapturingModelTile) and (modelUnit:isCapturingModelTile())) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandidateUnitsForPhase2(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.getAttackRangeMinMax)) then
            local minRange, maxRange = modelUnit:getAttackRangeMinMax()
            if (maxRange > 1) then
                units[#units + 1] = modelUnit
            end
        end
    end)

    return units
end

local function getCandidateUnitsForPhase3(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.isCapturingModelTile)) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandidateUnitsForPhase4(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn)                             and
            (modelUnit:isStateIdle())                                                     and
            (GameConstantFunctions.isTypeInCategory(modelUnit:getUnitType(), "AirUnits")) and
            (modelUnit.getBaseDamage))                                                    then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandidateUnitsForPhase5(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.getBaseDamage)) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandidateUnitsForPhase6(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle())) then
            if (not modelUnit.getAttackRangeMinMax) then
                units[#units + 1] = modelUnit
            else
                local minRange, maxRange = modelUnit:getAttackRangeMinMax()
                if (maxRange == 1) then
                    units[#units + 1] = modelUnit
                end
            end
        end
    end)

    return units
end

local function getCandidateUntisForPhase7(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle())) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

--------------------------------------------------------------------------------
-- The phases.
--------------------------------------------------------------------------------
-- Phase 1: move the infantries, meches and bikes that are capturing buildings.
local function getActionForPhase1(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase1(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 2
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 2: make the ranged units to attack enemies.
local function getActionForPhase2(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase2(self)

    local action
    while ((not action) or (action.actionCode ~= ACTION_CODES.ActionAttack)) do
        local candicateUnit = popRandomElement(self.m_CandicateUnits)
        if (not candicateUnit) then
            self.m_CandicateUnits = nil
            self.m_PhaseCode      = 3
            return nil
        end

        action = getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
    end

    return action
end

-- Phase 3: move the other infantries, meches and bikes.
local function getActionForPhase3(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase3(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 4
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 4: move the air combat units.
local function getActionForPhase4(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase4(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 5
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 5: move the other combat units.
local function getActionForPhase5(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase5(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 6
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 6: move the other units except the remaining ranged units.
local function getActionForPhase6(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUnitsForPhase6(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 7
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 7: move the remaining units.
local function getActionForPhase7(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandidateUntisForPhase7(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 8
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 8: spend energy on passive skills.
local function getActionForPhase8(self)
    if (not self.m_IsPassiveSkillEnabled) then
        self.m_PhaseCode = 9
        return nil
    end

    local modelPlayer       = self.m_ModelPlayerManager:getModelPlayer(self.m_ModelTurnManager:getPlayerIndex())
    local energy            = modelPlayer:getEnergy()
    local availableSkillIds = {}
    for skillID, energyCost in pairs(self.m_PassiveSkillData) do
        if (energy >= energyCost) then
            if (skillID ~= 11) then
                availableSkillIds[#availableSkillIds + 1] = skillID
            end
        end
    end

    local targetSkillID = popRandomElement(availableSkillIds)
    if (not targetSkillID) then
        self.m_PhaseCode = 9
        return nil
    else
        return {
            actionCode    = ACTION_CODES.ActionActivateSkill,
            skillID       = targetSkillID,
            skillLevel    = 1,
            isActiveSkill = false,
        }
    end
end

-- Phase 9: build units.
local function getActionForPhase9(self)
    local action = getActionProduceModelUnitOnTileForMaxScore(self)
    if (not action) then
        self.m_PhaseCode = 10
        return nil
    end

    return action
end

-- Phase 10: end turn.
local function getActionForPhase10(self)
    self.m_PhaseCode = nil
    return {actionCode = ACTION_CODES.ActionEndTurn}
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initPassiveSkillData(self)
    local skills                = {}
    local modelSkillDataManager = self.m_ModelSkillDataManager

    for _, skillID in pairs(modelSkillDataManager:getSkillCategory("SkillsPassive")) do
        skills[skillID] = modelSkillDataManager:getSkillPoints(skillID, 1, false)
    end

    self.m_PassiveSkillData = skills
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
    self.m_ModelSkillDataManager      = modelWar:getModelSkillDataManager()
    self.m_MapSize                    = self.m_ModelTileMap:getMapSize()
    self.m_MapWidth, self.m_MapHeight = self.m_MapSize.width, self.m_MapSize.height
    self.m_IsPassiveSkillEnabled      = modelWar:isPassiveSkillEnabled()
    self.m_PlayerIndexForHuman        = self.m_ModelPlayerManager:getPlayerIndexForHuman()

    self.m_ModelTileMap:forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == self.m_PlayerIndexForHuman) and (modelTile:getTileType() == "Headquarters")) then
            self.m_PlayerHqGridIndex = modelTile:getGridIndex()
        end
    end)

    initPassiveSkillData(self)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelRobot:getNextAction()
    local modelTurnManager = self.m_ModelTurnManager
    assert((modelTurnManager:getPlayerIndex() ~= self.m_PlayerIndexForHuman) and (modelTurnManager:isTurnPhaseMain()))

    self.m_PhaseCode      = self.m_PhaseCode or 1
    self.m_UnitValueRatio = calculateUnitValueRatio(self)
    local action
    if ((not action) and (self.m_PhaseCode == 1))  then action = getActionForPhase1( self) end
    if ((not action) and (self.m_PhaseCode == 2))  then action = getActionForPhase2( self) end
    if ((not action) and (self.m_PhaseCode == 3))  then action = getActionForPhase3( self) end
    if ((not action) and (self.m_PhaseCode == 4))  then action = getActionForPhase4( self) end
    if ((not action) and (self.m_PhaseCode == 5))  then action = getActionForPhase5( self) end
    if ((not action) and (self.m_PhaseCode == 6))  then action = getActionForPhase6( self) end
    if ((not action) and (self.m_PhaseCode == 7))  then action = getActionForPhase7( self) end
    if ((not action) and (self.m_PhaseCode == 8))  then action = getActionForPhase8( self) end
    if ((not action) and (self.m_PhaseCode == 9))  then action = getActionForPhase9( self) end
    if ((not action) and (self.m_PhaseCode == 10)) then action = getActionForPhase10(self) end

    return action
end

return ModelRobot
