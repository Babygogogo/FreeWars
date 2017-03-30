
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
    local score = getPossibleDamageInPlayerTurn(self, modelUnit, gridIndex) * (-modelUnit:getProductionCost() / 4000)           -- ADJUSTABLE

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

local function getScoreForActionAttack(self, modelUnit, gridIndex, targetGridIndex, attackDamage, counterDamage)
    if (not attackDamage) then
        return nil
    end

    local targetTile = self.m_ModelTileMap:getModelTile(targetGridIndex)
    if (targetTile:getTileType() == "Meteor") then
        return attackDamage                                                                                                     -- ADJUSTABLE
    end

    local targetUnit = self.m_ModelUnitMap:getModelUnit(targetGridIndex)
    local score      = attackDamage * targetUnit:getProductionCost() * 1.5 / 4000                                               -- ADJUSTABLE
    if (targetUnit:getCurrentHP() <= attackDamage) then
        score = score + 20                                                                                                      -- ADJUSTABLE
    end

    if (counterDamage) then
        local attackerHP = modelUnit:getCurrentHP()
        counterDamage    = math.min(counterDamage, attackerHP)
        score            = score + (-counterDamage * modelUnit:getProductionCost() / 4000)                                      -- ADJUSTABLE
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
    else
        local tileValue = (modelTile:getPlayerIndex() == (self.m_PlayerIndexForHuman)) and (100) or (0)                         -- ADJUSTABLE
        local tileType  = modelTile:getTileType()
        if     (tileType == "Headquarters")  then tileValue = tileValue + 300                                                   -- ADJUSTABLE
        elseif (tileType == "Factory")       then tileValue = tileValue + 200                                                   -- ADJUSTABLE
        elseif (tileType == "Airport")       then tileValue = tileValue + 150                                                   -- ADJUSTABLE
        elseif (tileType == "Seaport")       then tileValue = tileValue + 120                                                   -- ADJUSTABLE
        elseif (tileType == "City")          then tileValue = tileValue + 100                                                   -- ADJUSTABLE
        elseif (tileType == "CommandTower")  then tileValue = tileValue + 200                                                   -- ADJUSTABLE
        elseif (tileType == "Radar")         then tileValue = tileValue + 100                                                   -- ADJUSTABLE
        end

        if (captureAmount >= currentCapturePoint / 2) then
            return tileValue                                                                                                    -- ADJUSTABLE
        else
            return tileValue / 2 / math.ceil(currentCapturePoint / captureAmount)                                               -- ADJUSTABLE
        end
    end
end

local function getScoreForActionJoinModelUnit(self, modelUnit, gridIndex)
    return -200                                                                                                                 -- ADJUSTABLE
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

local function getScoreForActionWait(self, modelUnit, gridIndex)
    return 0                                                                                                                    -- ADJUSTABLE
end

--------------------------------------------------------------------------------
-- The available action generators.
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

local function getActionLaunchFlare(self)
    local focusModelUnit = self.m_FocusModelUnit
    if ((not getModelFogMap(self.m_ModelWar):isFogOfWarCurrently()) or
        (#self.m_PathNodes ~= 1)                                         or
        (not focusModelUnit.getCurrentFlareAmmo)                         or
        (focusModelUnit:getCurrentFlareAmmo() == 0))                     then
        return nil
    else
        return {
            name     = getLocalizedText(78, "LaunchFlare"),
            callback = function()
                setStateChoosingFlareTarget(self)
            end,
        }
    end
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
    if (scoreForActionLoadModelUnit) then
        return scoreForActionLoadModelUnit, actionLoadModelUnit
    end

    local scoreForActionJoinModelUnit, actionJoinModelUnit = getScoreAndActionJoinModelUnit(self, modelUnit, gridIndex, pathNodes)
    if (scoreForActionJoinModelUnit) then
        return scoreForActionJoinModelUnit, actionJoinModelUnit
    end

    local maxScore, actionForMaxScore
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionAttack(          self, modelUnit, gridIndex, pathNodes))
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionCaptureModelTile(self, modelUnit, gridIndex, pathNodes))
    maxScore, actionForMaxScore = getBetterScoreAndAction(maxScore, actionForMaxScore, getScoreAndActionWait(            self, modelUnit, gridIndex, pathNodes))

    return maxScore, actionForMaxScore
    --[[
    local list = {}
    list[#list + 1] = getActionAttack(                self)
    list[#list + 1] = getActionDive(                  self)
    list[#list + 1] = getActionSurface(               self)
    list[#list + 1] = getActionBuildModelTile(        self)
    list[#list + 1] = getActionSupplyModelUnit(       self)
    for _, action in ipairs(getActionsDropModelUnit(self)) do
        list[#list + 1] = action
    end
    list[#list + 1] = getActionLaunchFlare(           self)
    list[#list + 1] = getActionLaunchSilo(            self)
    list[#list + 1] = getActionProduceModelUnitOnUnit(self)

    local itemWait = getScoreAndActionWait(self)
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
-- The candicate units generators.
--------------------------------------------------------------------------------
local function getCandicateUnitsForPhase1(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.isCapturingModelTile)) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandicateUnitsForPhase2(self)
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

local function getCandicateUnitsForPhase3(self)
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

local function getCandicateUnitsForPhase4(self)
    local units             = {}
    local playerIndexInTurn = self.m_ModelTurnManager:getPlayerIndex()
    self.m_ModelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndexInTurn) and (modelUnit:isStateIdle()) and (modelUnit.getBaseDamage)) then
            units[#units + 1] = modelUnit
        end
    end)

    return units
end

local function getCandicateUnitsForPhase5(self)
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
-- Phase 1: move the infantries, meches and bikes.
local function getActionForPhase1(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase1(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 2
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 2: move the ranged units.
local function getActionForPhase2(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase2(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 3
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 3: move the air combat units.
local function getActionForPhase3(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase3(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 4
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 4: move the other combat units.
local function getActionForPhase4(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase4(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 5
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 5: move the other units.
local function getActionForPhase5(self)
    self.m_CandicateUnits = self.m_CandicateUnits or getCandicateUnitsForPhase5(self)
    local candicateUnit   = popRandomElement(self.m_CandicateUnits)
    if (not candicateUnit) then
        self.m_CandicateUnits = nil
        self.m_PhaseCode      = 6
        return nil
    end

    return getActionForMaxScoreWithCandicateUnit(self, candicateUnit)
end

-- Phase 6: spend energy on passive skills.
local function getActionForPhase6(self)
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

-- Phase 9: end turn.
local function getActionForPhase9(self)
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
    print("ModelRobot:getNextAction()", self.m_PhaseCode)
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
