
local ActionTranslatorForCampaign = {}

local Producible              = requireFW("src.app.components.Producible")
local ActionCodeFunctions     = requireFW("src.app.utilities.ActionCodeFunctions")
local DamageCalculator        = requireFW("src.app.utilities.DamageCalculator")
local GameConstantFunctions   = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions      = requireFW("src.app.utilities.GridIndexFunctions")
local LocalizationFunctions   = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions  = requireFW("src.app.utilities.SerializationFunctions")
local SkillModifierFunctions  = requireFW("src.app.utilities.SkillModifierFunctions")
local SingletonGetters        = requireFW("src.app.utilities.SingletonGetters")
local TableFunctions          = requireFW("src.app.utilities.TableFunctions")
local VisibilityFunctions     = requireFW("src.app.utilities.VisibilityFunctions")
local Actor                   = requireFW("src.global.actors.Actor")
local ComponentManager        = requireFW("src.global.components.ComponentManager")

local getLocalizedText             = LocalizationFunctions.getLocalizedText
local getModelFogMap               = SingletonGetters.getModelFogMap
local getModelPlayerManager        = SingletonGetters.getModelPlayerManager
local getModelTileMap              = SingletonGetters.getModelTileMap
local getModelTurnManager          = SingletonGetters.getModelTurnManager
local getModelUnitMap              = SingletonGetters.getModelUnitMap
local getRevealedTilesAndUnitsData = VisibilityFunctions.getRevealedTilesAndUnitsData
local isUnitVisible                = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local ipairs, pairs, next          = ipairs, pairs, next
local math                         = math

local ACTION_CODES                   = ActionCodeFunctions.getFullList()
local MESSAGE_PARAM_OUT_OF_SYNC      = {"OutOfSync"}
local IGNORED_ACTION_KEYS_FOR_SERVER = {"revealedTiles", "revealedUnits"}

local LOGOUT_INVALID_ACCOUNT_PASSWORD = {
    actionCode    = ACTION_CODES.ActionLogout,
    messageCode   = 81,
    messageParams = {"InvalidAccountOrPassword"},
}
local RUN_SCENE_MAIN_DEFEATED_PLAYER = {
    actionCode    = ACTION_CODES.ActionRunSceneMain,
    messageCode   = 81,
    messageParams = {"DefeatedPlayer"},
}
local RUN_SCENE_MAIN_ENDED_WAR = {
    actionCode    = ACTION_CODES.ActionRunSceneMain,
    messageCode   = 81,
    messageParams = {"EndedWar"},
}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getPlayersCountWithWarFieldFileName(warFieldFileName)
    return requireFW("res.data.templateWarField." .. warFieldFileName).playersCount
end

local function getGameTypeIndexWithWarConfiguration(warConfiguration)
    return getPlayersCountWithWarFieldFileName(warConfiguration.warFieldFileName) * 2 - 3 + (warConfiguration.isFogOfWarByDefault and 1 or 0)
end

local function isGridInPathNodes(gridIndex, pathNodes)
    for _, node in ipairs(pathNodes) do
        if (GridIndexFunctions.isEqual(gridIndex, node)) then
            return true
        end
    end

    return false
end

local function isModelUnitDiving(modelUnit)
    return (modelUnit.isDiving) and (modelUnit:isDiving())
end

local function isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath)
    local pathNodes  = rawPath.pathNodes
    local pathLength = #pathNodes
    if (pathLength == 1) then
        return false
    end

    local modelUnitMap = getModelUnitMap(modelWar)
    local destination  = pathNodes[pathLength]
    local playerIndex  = modelUnitMap:getModelUnit(pathNodes[1]):getPlayerIndex()
    local modelUnit    = modelUnitMap:getModelUnit(destination)
    return (modelUnit) and
        (isUnitVisible(modelWar, destination, modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), playerIndex))
end

local function countModelUnitOnMapWithPlayerIndex(modelUnitMap, playerIndex)
    local count = 0
    modelUnitMap:forEachModelUnitOnMap(function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            count = count + 1
        end
    end)

    return count
end

local function getIncomeOnBeginTurn(modelWar)
    local playerIndex = getModelTurnManager(modelWar):getPlayerIndex()
    local income      = 0
    getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        if ((modelTile.getIncomeAmount) and (modelTile:getPlayerIndex() == playerIndex)) then
            income = income + (modelTile:getIncomeAmount() or 0)
        end
    end)

    return income
end

local function areAllUnitsDestroyedOnBeginTurn(modelWar)
    local playerIndex   = getModelTurnManager(modelWar):getPlayerIndex()
    local modelTileMap  = getModelTileMap(modelWar)
    local modelUnitMap  = getModelUnitMap(modelWar)
    local mapSize       = modelUnitMap:getMapSize()
    local width, height = mapSize.width, mapSize.height
    local hasUnit       = false

    for x = 1, width do
        for y = 1, height do
            local gridIndex = {x = x, y = y}
            local modelUnit = modelUnitMap:getModelUnit(gridIndex)
            if ((modelUnit) and (modelUnit:getPlayerIndex() == playerIndex)) then
                hasUnit = true
                if ((modelUnit.getCurrentFuel)                                            and
                    (modelUnit:getCurrentFuel() <= modelUnit:getFuelConsumptionPerTurn()) and
                    (modelUnit:shouldDestroyOnOutOfFuel()))                               then

                    local modelTile = modelTileMap:getModelTile(gridIndex)
                    if ((modelTile.canRepairTarget) and (modelTile:canRepairTarget(modelUnit))) then
                        return false
                    end
                else
                    return false
                end
            end
        end
    end

    return hasUnit
end

local function getRepairableModelUnits(modelWar)
    local playerIndex  = getModelTurnManager(modelWar):getPlayerIndex()
    local modelUnitMap = getModelUnitMap(modelWar)
    local modelTileMap = getModelTileMap(modelWar)
    local units        = {}

    modelUnitMap:forEachModelUnitOnMap(function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndex) then
                local modelTile = modelTileMap:getModelTile(modelUnit:getGridIndex())
                if ((modelTile.canRepairTarget) and (modelTile:canRepairTarget(modelUnit))) then
                    units[#units + 1] = modelUnit
                end
            end
        end)
        :forEachModelUnitLoaded(function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndex) then
                local loader = modelUnitMap:getModelUnit(modelUnit:getGridIndex())
                if ((loader:canRepairLoadedModelUnit()) and (loader:hasLoadUnitId(modelUnit:getUnitId()))) then
                    units[#units + 1] = modelUnit
                end
            end
        end)

    table.sort(units, function(unit1, unit2)
        local cost1, cost2 = unit1:getProductionCost(), unit2:getProductionCost()
        return (cost1 > cost2)                                             or
            ((cost1 == cost2) and (unit1:getUnitId() < unit2:getUnitId()))
    end)

    return units
end

local function getRepairAmountAndCost(modelUnit, fund, maxNormalizedRepairAmount, costModifier)
    local productionCost         = math.floor(modelUnit:getProductionCost() * costModifier)
    local normalizedCurrentHP    = modelUnit:getNormalizedCurrentHP()
    local normalizedRepairAmount = math.min(
        10 - normalizedCurrentHP,
        maxNormalizedRepairAmount,
        math.floor(fund * 10 / productionCost)
    )

    return (normalizedRepairAmount + normalizedCurrentHP) * 10 - modelUnit:getCurrentHP(),
        math.floor(normalizedRepairAmount * productionCost / 10)
end

local function generateRepairDataOnBeginTurn(modelWar)
    local modelUnitMap              = getModelUnitMap(modelWar)
    local modelPlayer               = getModelPlayerManager(modelWar):getModelPlayer(getModelTurnManager(modelWar):getPlayerIndex())
    local skillConfiguration        = modelPlayer:getModelSkillConfiguration()
    local fund                      = modelPlayer:getFund() + getIncomeOnBeginTurn(modelWar)
    local maxNormalizedRepairAmount = GameConstantFunctions.getBaseNormalizedRepairAmount() + SkillModifierFunctions.getRepairAmountModifier(skillConfiguration)
    local costModifier              = 1 -- + SkillModifierFunctions.getRepairCostModifier(skillConfiguration) / 100

    local onMapData, loadedData
    for _, modelUnit in ipairs(getRepairableModelUnits(modelWar)) do
        local repairAmount, repairCost = getRepairAmountAndCost(modelUnit, fund, maxNormalizedRepairAmount, costModifier)
        local unitID                   = modelUnit:getUnitId()
        if (modelUnitMap:getLoadedModelUnitWithUnitId(unitID)) then
            loadedData         = loadedData or {}
            loadedData[unitID] = {
                unitID       = unitID,
                repairAmount = repairAmount,
            }
        else
            onMapData         = onMapData or {}
            onMapData[unitID] = {
                unitID       = unitID,
                repairAmount = repairAmount,
                gridIndex    = GridIndexFunctions.clone(modelUnit:getGridIndex()),
            }
        end
        fund = fund - repairCost
    end

    return {
        onMapData     = onMapData,
        loadedData    = loadedData,
        remainingFund = fund,
    }
end

local function generateSupplyDataOnBeginTurn(modelWar, repairData)
    local modelUnitMap          = getModelUnitMap(modelWar)
    local playerIndex           = getModelTurnManager(modelWar):getPlayerIndex()
    local mapSize               = modelUnitMap:getMapSize()
    local repairDataOnMap       = repairData.onMapData
    local repairDataLoaded      = repairData.loadedData
    local onMapData, loadedData

    local updateOnMapData = function(supplier)
        if ((supplier:getPlayerIndex() == playerIndex) and (supplier.canSupplyModelUnit)) then
            if (((repairDataOnMap) and (repairDataOnMap[supplier:getUnitId()]))                                                        or
                (not ((supplier:shouldDestroyOnOutOfFuel()) and (supplier:getCurrentFuel() <= supplier:getFuelConsumptionPerTurn())))) then

                for _, adjacentGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(supplier:getGridIndex(), mapSize)) do
                    local target = modelUnitMap:getModelUnit(adjacentGridIndex)
                    if ((target) and (supplier:canSupplyModelUnit(target))) then
                        local unitID = target:getUnitId()
                        if (((not repairDataOnMap) or (not repairDataOnMap[unitID]))                                                         and
                            ((not onMapData)       or (not onMapData[unitID]))                                                               and
                            (not ((target:shouldDestroyOnOutOfFuel()) and (target:getCurrentFuel() <= target:getFuelConsumptionPerTurn())))) then

                            onMapData         = onMapData or {}
                            onMapData[unitID] = {
                                unitID    = unitID,
                                gridIndex = adjacentGridIndex,
                            }
                        end
                    end
                end
            end
        end
    end

    local updateLoadedData = function(supplier)
        if ((supplier:getPlayerIndex() == playerIndex) and
            (supplier.canSupplyLoadedModelUnit)        and
            (supplier:canSupplyLoadedModelUnit())      and
            (not supplier:canRepairLoadedModelUnit())) then
            if (((repairDataOnMap) and (repairDataOnMap[supplier:getUnitId()]))                                                        or
                (not ((supplier:shouldDestroyOnOutOfFuel()) and (supplier:getCurrentFuel() <= supplier:getFuelConsumptionPerTurn())))) then

                for _, unitID in pairs(supplier:getLoadUnitIdList()) do
                    loadedData         = loadedData or {}
                    loadedData[unitID] = {unitID = unitID}
                end
            end
        end
    end

    modelUnitMap:forEachModelUnitOnMap(updateOnMapData)
        :forEachModelUnitOnMap(        updateLoadedData)
        :forEachModelUnitLoaded(       updateLoadedData)

    if ((not onMapData) and (not loadedData)) then
        return nil
    else
        return {
            onMapData  = onMapData,
            loadedData = loadedData,
        }
    end
end

local function canDoActionSupplyModelUnit(focusModelUnit, destination, modelUnitMap)
    if (focusModelUnit.canSupplyModelUnit) then
        for _, gridIndex in pairs(GridIndexFunctions.getAdjacentGrids(destination, modelUnitMap:getMapSize())) do
            local modelUnit = modelUnitMap:getModelUnit(gridIndex)
            if ((modelUnit)                                     and
                (modelUnit ~= focusModelUnit)                   and
                (focusModelUnit:canSupplyModelUnit(modelUnit))) then
                return true
            end
        end
    end

    return false
end

local function validateDropDestinations(action, modelWar)
    local destinations = action.dropDestinations
    if (#destinations < 1) then
        return false
    end

    local modelUnitMap             = getModelUnitMap(modelWar)
    local modelTileMap             = getModelTileMap(modelWar)
    local mapSize                  = modelTileMap:getMapSize()
    local pathNodes                = action.path.pathNodes
    local loaderBeginningGridIndex = pathNodes[1]
    local loaderEndingGridIndex    = pathNodes[#pathNodes]
    local loaderModelUnit          = modelUnitMap:getFocusModelUnit(loaderBeginningGridIndex, action.launchUnitID)
    local loaderEndingModelTile    = modelTileMap:getModelTile(loaderEndingGridIndex)
    local playerIndex              = loaderModelUnit:getPlayerIndex()

    for i = 1, #destinations do
        local droppingUnitID    = destinations[i].unitID
        local droppingGridIndex = destinations[i].gridIndex
        local droppingModelUnit = modelUnitMap:getLoadedModelUnitWithUnitId(droppingUnitID)
        if ((not droppingModelUnit)                                                                         or
            (not loaderModelUnit:hasLoadUnitId(droppingUnitID))                                             or
            (not GridIndexFunctions.isWithinMap(droppingGridIndex, mapSize))                                or
            (not GridIndexFunctions.isAdjacent(droppingGridIndex, loaderEndingGridIndex))                   or
            (not loaderEndingModelTile:getMoveCostWithModelUnit(droppingModelUnit))                         or
            (not modelTileMap:getModelTile(droppingGridIndex):getMoveCostWithModelUnit(droppingModelUnit))) then
            return false
        end

        local existingModelUnit = modelUnitMap:getModelUnit(droppingGridIndex)
        if ((existingModelUnit)                                                                                                                                                           and
            (existingModelUnit ~= loaderModelUnit)                                                                                                                                        and
            (isUnitVisible(modelWar, droppingGridIndex, existingModelUnit:getUnitType(), isModelUnitDiving(existingModelUnit), existingModelUnit:getPlayerIndex(), playerIndex))) then
            return false
        end

        for j = i + 1, #destinations do
            local additionalDestination = destinations[j]
            if ((GridIndexFunctions.isEqual(droppingGridIndex, additionalDestination.gridIndex)) or
                (droppingUnitID == additionalDestination.unitID))                                then
                return false
            end
        end
    end

    return true
end

local function isDropDestinationBlocked(destination, modelUnitMap, loaderModelUnit)
    local existingModelUnit = modelUnitMap:getModelUnit(destination.gridIndex)
    return (existingModelUnit) and (existingModelUnit ~= loaderModelUnit)
end

local function translateDropDestinations(rawDestinations, modelUnitMap, loaderModelUnit)
    local translatedDestinations = {}
    local isDropBlocked
    for i = 1, #rawDestinations do
        if (isDropDestinationBlocked(rawDestinations[i], modelUnitMap, loaderModelUnit)) then
            isDropBlocked = true
        else
            translatedDestinations[#translatedDestinations + 1] = rawDestinations[i]
        end
    end

    return translatedDestinations, isDropBlocked
end

local function getLostPlayerIndexForActionAttack(modelWar, attacker, target, attackDamage, counterDamage)
    local modelUnitMap = getModelUnitMap(modelWar)
    if ((target.getUnitType) and (attackDamage >= target:getCurrentHP())) then
        local playerIndex = target:getPlayerIndex()
        if (countModelUnitOnMapWithPlayerIndex(modelUnitMap, playerIndex) == 1) then
            return playerIndex
        end
    elseif ((counterDamage) and (counterDamage >= attacker:getCurrentHP())) then
        local playerIndex = attacker:getPlayerIndex()
        if (countModelUnitOnMapWithPlayerIndex(modelUnitMap, playerIndex) == 1) then
            return playerIndex
        end
    else
        return nil
    end
end

local function createActionForServer(action)
    return TableFunctions.clone(action, IGNORED_ACTION_KEYS_FOR_SERVER)
end

local function createActionReloadSceneWar(modelWar, playerAccount, messageCode, messageParams)
    local _, playerIndex = getModelPlayerManager(modelWar):getModelPlayerWithAccount(playerAccount)
    return {
        actionCode    = ACTION_CODES.ActionReloadSceneWar,
        warData       = modelWar:toSerializableTableForPlayerIndex(playerIndex),
        messageCode   = messageCode,
        messageParams = messageParams,
    }
end

local function isPlayerInTurnInWar(modelWar, playerAccount)
    local playerIndex = getModelTurnManager(modelWar):getPlayerIndex()
    return getModelPlayerManager(modelWar):getModelPlayer(playerIndex):getAccount() == playerAccount
end

local function isPlayerAliveInWar(modelWar, playerAccount)
    local modelPlayer = getModelPlayerManager(modelWar):getModelPlayerWithAccount(playerAccount)
    return (modelPlayer) and (modelPlayer:isAlive())
end

local function createActionWait(warID, actionID, path, launchUnitID, revealedTiles, revealedUnits)
    return {
        actionCode    = ACTION_CODES.ActionWait,
        actionID      = actionID,
        launchUnitID  = launchUnitID,
        path          = path,
        revealedTiles = revealedTiles,
        revealedUnits = revealedUnits,
        warID         = warID,
    }
end

--------------------------------------------------------------------------------
-- The translate functions.
--------------------------------------------------------------------------------
-- This translation ignores the existing unit of the same player at the end of the path, so that the actions of Join/Attack/Wait can reuse this function.
local function translatePath(path, launchUnitID, modelWar)
    local modelTurnManager   = getModelTurnManager(modelWar)
    local modelUnitMap       = getModelUnitMap(modelWar)
    local playerIndexInTurn  = modelTurnManager:getPlayerIndex()
    local rawPathNodes       = path.pathNodes
    local beginningGridIndex = rawPathNodes[1]
    local mapSize            = modelUnitMap:getMapSize()
    local focusModelUnit     = modelUnitMap:getFocusModelUnit(beginningGridIndex, launchUnitID)
    local isWithinMap        = GridIndexFunctions.isWithinMap

    if (not isWithinMap(beginningGridIndex, mapSize)) then
        return nil, "ActionTranslatorForCampaign-translatePath() a node in the path is not within the map."
    elseif (not focusModelUnit) then
        return nil, "ActionTranslatorForCampaign-translatePath() there is no unit on the starting grid of the path."
    elseif (focusModelUnit:getPlayerIndex() ~= playerIndexInTurn) then
        return nil, "ActionTranslatorForCampaign-translatePath() the owner player of the moving unit is not in his turn."
    elseif (not focusModelUnit:isStateIdle()) then
        return nil, "ActionTranslatorForCampaign-translatePath() the moving unit is not in idle state."
    elseif (not modelTurnManager:isTurnPhaseMain()) then
        return nil, "ActionTranslatorForCampaign-translatePath() the turn phase is not 'main'."
    end

    local teamIndexInTurn      = getModelPlayerManager(modelWar):getModelPlayer(playerIndexInTurn):getTeamIndex()
    local modelTileMap         = getModelTileMap(modelWar)
    local translatedPathNodes  = {GridIndexFunctions.clone(beginningGridIndex)}
    local translatedPath       = {pathNodes = translatedPathNodes}
    local totalFuelConsumption = 0
    local maxFuelConsumption   = math.min(focusModelUnit:getCurrentFuel(), focusModelUnit:getMoveRange())

    for i = 2, #rawPathNodes do
        local gridIndex = rawPathNodes[i]
        if (not GridIndexFunctions.isAdjacent(rawPathNodes[i - 1], gridIndex)) then
            return nil, "ActionTranslatorForCampaign-translatePath() the path is invalid because some grids are not adjacent to previous ones."
        elseif (isGridInPathNodes(gridIndex, translatedPathNodes)) then
            return nil, "ActionTranslatorForCampaign-translatePath() some grids in the path are the same."
        elseif (not isWithinMap(gridIndex, mapSize)) then
            return nil, "ActionTranslatorForCampaign-translatePath() a node in the path is not within the map."
        end

        local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
        if ((existingModelUnit) and (existingModelUnit:getTeamIndex() ~= teamIndexInTurn)) then
            if (isUnitVisible(modelWar, gridIndex, existingModelUnit:getUnitType(), isModelUnitDiving(existingModelUnit), existingModelUnit:getPlayerIndex(), playerIndexInTurn)) then
                return nil, "ActionTranslatorForCampaign-translatePath() the path is invalid because it is blocked by a visible enemy unit."
            else
                translatedPath.isBlocked = true
            end
        end

        local fuelConsumption = modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(focusModelUnit)
        if (not fuelConsumption) then
            return nil, "ActionTranslatorForCampaign-translatePath() the path is invalid because some tiles on it is impassable."
        end

        totalFuelConsumption = totalFuelConsumption + fuelConsumption
        if (totalFuelConsumption > maxFuelConsumption) then
            return nil, "ActionTranslatorForCampaign-translatePath() the path is invalid because the fuel consumption is too high."
        end

        if (not translatedPath.isBlocked) then
            translatedPath.fuelConsumption                = totalFuelConsumption
            translatedPathNodes[#translatedPathNodes + 1] = GridIndexFunctions.clone(gridIndex)
        end
    end

    return translatedPath
end

local function translateActivateSkill(action)
    local modelWar         = action.modelWar
    local skillID          = action.skillID
    local skillLevel       = action.skillLevel
    local isActiveSkill    = action.isActiveSkill
    local modelTurnManager = getModelTurnManager(modelWar)
    local modelPlayer      = getModelPlayerManager(modelWar):getModelPlayer(modelTurnManager:getPlayerIndex())
    if ((not modelTurnManager:isTurnPhaseMain())                                                                                                           or
        ((isActiveSkill) and ((not modelWar:isActiveSkillEnabled()) or ((modelWar:isSkillDeclarationEnabled()) and (not modelPlayer:canActivateSkill())))) or
        ((not isActiveSkill) and (not modelWar:isPassiveSkillEnabled()))                                                                                   or
        (modelPlayer:getEnergy() < modelWar:getModelSkillDataManager():getSkillPoints(skillID, skillLevel, isActiveSkill)))                                then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = VisibilityFunctions.getRevealedTilesAndUnitsDataForSkillActivation(modelWar, skillID)
    local actionActivateSkill = {
        actionCode    = ACTION_CODES.ActionActivateSkill,
        actionID      = action.actionID,
        warID         = action.warID,
        skillID       = skillID,
        skillLevel    = skillLevel,
        isActiveSkill = isActiveSkill,
        revealedTiles = revealedTiles,
        revealedUnits = revealedUnits,
    }
    return actionActivateSkill
end

local function translateAttack(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local modelUnitMap        = getModelUnitMap(modelWar)
    local attacker            = modelUnitMap:getFocusModelUnit(rawPath.pathNodes[1], launchUnitID)
    local targetGridIndex     = action.targetGridIndex
    local attackTarget        = modelUnitMap:getModelUnit(targetGridIndex) or getModelTileMap(modelWar):getModelTile(targetGridIndex)
    if ((not ComponentManager.getComponent(attacker, "AttackDoer"))                                                                                                                                                     or
        (not GridIndexFunctions.isWithinMap(targetGridIndex, modelUnitMap:getMapSize()))                                                                                                                                or
        ((attackTarget.getUnitType) and (not isUnitVisible(modelWar, targetGridIndex, attackTarget:getUnitType(), isModelUnitDiving(attackTarget), attackTarget:getPlayerIndex(), attacker:getPlayerIndex())))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local attackDamage, counterDamage = DamageCalculator.getUltimateBattleDamage(rawPath.pathNodes, launchUnitID, targetGridIndex, modelWar)
    if (not attackDamage) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, attacker, (counterDamage) and (counterDamage >= attacker:getCurrentHP()))
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionAttack = {
            actionCode       = ACTION_CODES.ActionAttack,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            targetGridIndex  = targetGridIndex,
            attackDamage     = attackDamage,
            counterDamage    = counterDamage,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
            lostPlayerIndex  = getLostPlayerIndexForActionAttack(modelWar, attacker, attackTarget, attackDamage, counterDamage),
        }
        return actionAttack
    end
end

local function translateBeginTurn(action)
    local modelWar         = action.modelWar
    local modelTurnManager = getModelTurnManager(modelWar)
    assert(modelTurnManager:isTurnPhaseRequestToBegin())

    local actionBeginTurn = {
        actionCode       = ACTION_CODES.ActionBeginTurn,
        actionID         = action.actionID,
    }
    if (modelTurnManager:getTurnIndex() == 1) then
        actionBeginTurn.income = getIncomeOnBeginTurn(modelWar)
    else
        actionBeginTurn.lostPlayerIndex = (areAllUnitsDestroyedOnBeginTurn(modelWar)) and (modelTurnManager:getPlayerIndex()) or (nil)
        actionBeginTurn.repairData      = generateRepairDataOnBeginTurn(modelWar)
        actionBeginTurn.supplyData      = generateSupplyDataOnBeginTurn(modelWar, actionBeginTurn.repairData)
    end
    return actionBeginTurn
end

local function translateBuildModelTile(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes     = rawPath.pathNodes
    local endingGridIndex  = rawPathNodes[#rawPathNodes]
    local focusModelUnit   = getModelUnitMap(modelWar):getFocusModelUnit(rawPathNodes[1], launchUnitID)
    local modelTile        = getModelTileMap(modelWar):getModelTile(endingGridIndex)
    if ((not focusModelUnit.canBuildOnTileType)                          or
        (not focusModelUnit:canBuildOnTileType(modelTile:getTileType())) or
        (not focusModelUnit.getCurrentMaterial)                          or
        (focusModelUnit:getCurrentMaterial() < 1))                       then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        if (focusModelUnit:getBuildAmount() >= modelTile:getCurrentBuildPoint()) then
            local tiles, units = VisibilityFunctions.getRevealedTilesAndUnitsDataForBuild(modelWar, endingGridIndex, focusModelUnit)
            revealedTiles = TableFunctions.union(revealedTiles, tiles)
            revealedUnits = TableFunctions.union(revealedUnits, units)
        end
        local actionBuildModelTile = {
            actionCode       = ACTION_CODES.ActionBuildModelTile,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionBuildModelTile
    end
end

local function translateCaptureModelTile(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes    = rawPath.pathNodes
    local endingGridIndex = rawPathNodes[#rawPathNodes]
    local capturer        = getModelUnitMap(modelWar):getFocusModelUnit(rawPathNodes[1], launchUnitID)
    local captureTarget   = getModelTileMap(modelWar):getModelTile(endingGridIndex)
    if ((not capturer.canCaptureModelTile) or (not capturer:canCaptureModelTile(captureTarget))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, capturer, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local isCaptureFinished = capturer:getCaptureAmount() >= captureTarget:getCurrentCapturePoint()
        if (isCaptureFinished) then
            local tiles, units = VisibilityFunctions.getRevealedTilesAndUnitsDataForCapture(modelWar, endingGridIndex, capturer:getPlayerIndex())
            revealedTiles = TableFunctions.union(revealedTiles, tiles)
            revealedUnits = TableFunctions.union(revealedUnits, units)
        end

        local actionCapture = {
            actionCode       = ACTION_CODES.ActionCaptureModelTile,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
            lostPlayerIndex  = ((isCaptureFinished) and (captureTarget:isDefeatOnCapture()))
                and (captureTarget:getPlayerIndex())
                or  (nil),
        }
        return actionCapture
    end
end

local function translateDeclareSkill(action)
    local modelWar         = action.modelWar
    local modelTurnManager = getModelTurnManager(modelWar)
    local modelPlayer      = getModelPlayerManager(modelWar):getModelPlayer(modelTurnManager:getPlayerIndex())
    if ((not modelTurnManager:isTurnPhaseMain())                                                   or
        (not modelWar:isActiveSkillEnabled())                                                      or
        (modelPlayer:isSkillDeclared())                                                            or
        (modelPlayer:getEnergy() < modelWar:getModelSkillDataManager():getSkillDeclarationCost())) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    return action
end

local function translateDestroyOwnedModelUnit(action)
    local modelWar  = action.modelWar
    local modelUnit = getModelUnitMap(modelWar):getModelUnit(action.gridIndex)
    if ((not getModelTurnManager(modelWar):isTurnPhaseMain())                          or
        (not modelUnit)                                                                      or
        (modelUnit:getPlayerIndex() ~= getModelTurnManager(modelWar):getPlayerIndex()) or
        (not modelUnit:isStateIdle()))                                                       then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local actionDestroyOwnedModelUnit = {
        actionCode       = ACTION_CODES.ActionDestroyOwnedModelUnit,
        actionID         = action.actionID,
        warID            = action.warID,
        gridIndex        = action.gridIndex,
    }
    return actionDestroyOwnedModelUnit
end

local function translateDive(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local focusModelUnit = getModelUnitMap(modelWar):getFocusModelUnit(rawPath.pathNodes[1], launchUnitID)
    if ((not focusModelUnit.canDive) or (not focusModelUnit:canDive())) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionDive = {
            actionCode       = ACTION_CODES.ActionDive,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionDive
    end
end

local function translateDropModelUnit(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local modelUnitMap    = getModelUnitMap(modelWar)
    local rawPathNodes    = rawPath.pathNodes
    local endingGridIndex = rawPathNodes[#rawPathNodes]
    local loaderModelUnit = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    local tileType        = getModelTileMap(modelWar):getModelTile(endingGridIndex):getTileType()
    if ((not loaderModelUnit.canDropModelUnit)                 or
        (not loaderModelUnit:canDropModelUnit(tileType))       or
        (not validateDropDestinations(action, modelWar))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, loaderModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local dropDestinations, isDropBlocked = translateDropDestinations(action.dropDestinations, modelUnitMap, loaderModelUnit)
        for _, dropDestination in ipairs(dropDestinations) do
            local dropModelUnit = modelUnitMap:getLoadedModelUnitWithUnitId(dropDestination.unitID)
            local tiles, units  = getRevealedTilesAndUnitsData(modelWar, {endingGridIndex, dropDestination.gridIndex}, dropModelUnit, false)
            revealedTiles = TableFunctions.union(revealedTiles, tiles)
            revealedUnits = TableFunctions.union(revealedUnits, units)
        end

        local actionDropModelUnit = {
            actionCode       = ACTION_CODES.ActionDropModelUnit,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            dropDestinations = dropDestinations,
            isDropBlocked    = isDropBlocked,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionDropModelUnit
    end
end

local function translateEndTurn(action)
    local modelWar         = action.modelWar
    local modelTurnManager = getModelTurnManager(modelWar)
    local modelPlayer      = getModelPlayerManager(modelWar):getModelPlayer(modelTurnManager:getPlayerIndex())
    if ((not modelTurnManager:isTurnPhaseMain())                                              or
        ((modelWar:getRemainingVotesForDraw()) and (not modelPlayer:hasVotedForDraw()))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local actionEndTurn = {
        actionCode       = ACTION_CODES.ActionEndTurn,
        actionID         = action.actionID,
        warID            = action.warID,
    }
    return actionEndTurn
end

local function translateJoinModelUnit(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if (not translatedPath) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes      = rawPath.pathNodes
    local modelUnitMap      = getModelUnitMap(modelWar)
    local existingModelUnit = modelUnitMap:getModelUnit(rawPathNodes[#rawPathNodes])
    local focusModelUnit    = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    if ((#rawPathNodes == 1)                                      or
        (not existingModelUnit)                                   or
        (not focusModelUnit.canJoinModelUnit)                     or
        (not focusModelUnit:canJoinModelUnit(existingModelUnit))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionJoinModelUnit = {
            actionCode       = ACTION_CODES.ActionJoinModelUnit,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionJoinModelUnit
    end
end

local function translateLaunchFlare(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes    = rawPath.pathNodes
    local modelUnitMap    = getModelUnitMap(modelWar)
    local targetGridIndex = action.targetGridIndex
    local focusModelUnit  = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    if ((#rawPathNodes > 1)                                                                                                 or
        (not focusModelUnit.getCurrentFlareAmmo)                                                                            or
        (focusModelUnit:getCurrentFlareAmmo() == 0)                                                                         or
        (not getModelFogMap(modelWar):isFogOfWarCurrently())                                                           or
        (not GridIndexFunctions.isWithinMap(targetGridIndex, modelUnitMap:getMapSize()))                                    or
        (GridIndexFunctions.getDistance(targetGridIndex, rawPathNodes[#rawPathNodes]) > focusModelUnit:getMaxFlareRange())) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local tiles, units = VisibilityFunctions.getRevealedTilesAndUnitsDataForFlare(modelWar, targetGridIndex, focusModelUnit:getFlareAreaRadius(), focusModelUnit:getPlayerIndex())
        local actionLaunchFlare = {
            actionCode       = ACTION_CODES.ActionLaunchFlare,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            targetGridIndex  = targetGridIndex,
            launchUnitID     = launchUnitID,
            revealedTiles    = TableFunctions.union(revealedTiles, tiles),
            revealedUnits    = TableFunctions.union(revealedUnits, units),
        }
        return actionLaunchFlare
    end
end

local function translateLaunchSilo(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local modelUnitMap    = getModelUnitMap(modelWar)
    local targetGridIndex = action.targetGridIndex
    local rawPathNodes    = rawPath.pathNodes
    local focusModelUnit  = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    if ((not focusModelUnit.canLaunchSiloOnTileType)                                                                                         or
        (not focusModelUnit:canLaunchSiloOnTileType(getModelTileMap(modelWar):getModelTile(rawPathNodes[#rawPathNodes]):getTileType())) or
        (not GridIndexFunctions.isWithinMap(targetGridIndex, modelUnitMap:getMapSize())))                                                    then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionLaunchSilo = {
            actionCode       = ACTION_CODES.ActionLaunchSilo,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            targetGridIndex  = targetGridIndex,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionLaunchSilo
    end
end

local function translateLoadModelUnit(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if (not translatedPath) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local modelUnitMap    = getModelUnitMap(modelWar)
    local rawPathNodes    = rawPath.pathNodes
    local focusModelUnit  = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    local destination     = rawPathNodes[#rawPathNodes]
    local loaderModelUnit = modelUnitMap:getModelUnit(destination)
    local tileType        = getModelTileMap(modelWar):getModelTile(destination):getTileType()
    if ((#rawPathNodes == 1)                                                                                                            or
        (not loaderModelUnit)                                                                                                           or
        (not loaderModelUnit.canLoadModelUnit)                                                                                          or
        (not loaderModelUnit:canLoadModelUnit(focusModelUnit, getModelTileMap(modelWar):getModelTile(destination):getTileType()))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionLoadModelUnit = {
            actionCode       = ACTION_CODES.ActionLoadModelUnit,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionLoadModelUnit
    end
end

local function translateProduceModelUnitOnTile(action)
    local modelWar         = action.modelWar
    local modelTurnManager = getModelTurnManager(modelWar)
    local modelWarField    = modelWar:getModelWarField()
    local modelTileMap     = getModelTileMap(modelWar)
    local gridIndex        = action.gridIndex
    if ((not modelTurnManager:isTurnPhaseMain())                                    or
        (not GridIndexFunctions.isWithinMap(gridIndex, modelTileMap:getMapSize()))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local tiledID            = action.tiledID
    local playerIndex        = modelTurnManager:getPlayerIndex()
    local modelPlayerManager = getModelPlayerManager(modelWar)
    local modelTile          = modelTileMap:getModelTile(gridIndex)
    local cost               = Producible.getProductionCostWithTiledId(tiledID, modelPlayerManager)
    if ((not cost)                                                        or
        (cost > modelPlayerManager:getModelPlayer(playerIndex):getFund()) or
        (modelTile:getPlayerIndex() ~= playerIndex)                       or
        (getModelUnitMap(modelWar):getModelUnit(gridIndex))          or
        (not modelTile.canProduceUnitWithTiledId)                         or
        (not modelTile:canProduceUnitWithTiledId(tiledID)))               then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local focusModelUnit   = Actor.createModel("warOnline.ModelUnitForOnline", {
        tiledID       = tiledID,
        unitID        = 0,
        GridIndexable = gridIndex,
    })
    focusModelUnit:onStartRunning(modelWar)

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, {gridIndex}, focusModelUnit)
    local actionProduceModelUnitOnTile = {
        actionCode       = ACTION_CODES.ActionProduceModelUnitOnTile,
        actionID         = action.actionID,
        warID            = action.warID,
        gridIndex        = gridIndex,
        tiledID          = tiledID,
        cost             = cost, -- the cost can be calculated by the clients, but that calculations can be eliminated by sending the cost to clients.
        revealedTiles    = revealedTiles,
        revealedUnits    = revealedUnits,
    }
    return actionProduceModelUnitOnTile
end

local function translateProduceModelUnitOnUnit(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes   = rawPath.pathNodes
    local focusModelUnit = getModelUnitMap(modelWar):getFocusModelUnit(rawPathNodes[1], launchUnitID)
    local cost           = (focusModelUnit.getMovableProductionCost) and (focusModelUnit:getMovableProductionCost()) or (nil)
    if ((launchUnitID)                                                                                                                or
        (#rawPathNodes ~= 1)                                                                                                          or
        (not focusModelUnit.getCurrentMaterial)                                                                                       or
        (focusModelUnit:getCurrentMaterial() < 1)                                                                                     or
        (not cost)                                                                                                                    or
        (cost > getModelPlayerManager(modelWar):getModelPlayer(getModelTurnManager(modelWar):getPlayerIndex()):getFund()) or
        (not focusModelUnit.getCurrentLoadCount)                                                                                      or
        (focusModelUnit:getCurrentLoadCount() >= focusModelUnit:getMaxLoadCount()))                                                   then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    local actionProduceModelUnitOnUnit = {
        actionCode       = ACTION_CODES.ActionProduceModelUnitOnUnit,
        actionID         = action.actionID,
        warID            = action.warID,
        path             = translatedPath,
        cost             = cost,
        revealedTiles    = revealedTiles,
        revealedUnits    = revealedUnits,
    }
    return actionProduceModelUnitOnUnit
end

local function translateSupplyModelUnit(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local rawPathNodes   = rawPath.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWar)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(rawPathNodes[1], launchUnitID)
    if (not canDoActionSupplyModelUnit(focusModelUnit, rawPathNodes[#rawPathNodes], modelUnitMap)) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionSupplyModelUnit = {
            actionCode       = ACTION_CODES.ActionSupplyModelUnit,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionSupplyModelUnit
    end
end

local function translateSurface(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath) or (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local focusModelUnit = getModelUnitMap(modelWar):getFocusModelUnit(rawPath.pathNodes[1], launchUnitID)
    if ((not focusModelUnit.canSurface) or (not focusModelUnit:canSurface())) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    if (translatedPath.isBlocked) then
        local actionWait = createActionWait(action.warID, action.actionID, translatedPath, launchUnitID, revealedTiles, revealedUnits)
        return actionWait
    else
        local actionSurface = {
            actionCode       = ACTION_CODES.ActionSurface,
            actionID         = action.actionID,
            warID            = action.warID,
            path             = translatedPath,
            launchUnitID     = launchUnitID,
            revealedTiles    = revealedTiles,
            revealedUnits    = revealedUnits,
        }
        return actionSurface
    end
end

local function translateSurrender(action)
    local modelWar = action.modelWar
    if (not getModelTurnManager(modelWar):isTurnPhaseMain()) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local actionSurrender = {
        actionCode       = ACTION_CODES.ActionSurrender,
        actionID         = action.actionID,
        warID            = action.warID,
    }
    return actionSurrender
end

local function translateVoteForDraw(action)
    local modelWar = action.modelWar
    if ((not getModelTurnManager(modelWar):isTurnPhaseMain())                                               or
        (getModelPlayerManager(modelWar):getModelPlayerWithAccount(action.playerAccount):hasVotedForDraw()) or
        ((not modelWar:getRemainingVotesForDraw()) and (not action.doesAgree)))                              then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local actionVoteForDraw = {
        actionCode       = ACTION_CODES.ActionVoteForDraw,
        actionID         = action.actionID,
        warID            = action.warID,
        doesAgree        = action.doesAgree,
    }
    return actionVoteForDraw
end

local function translateWait(action)
    local modelWar                     = action.modelWar
    local rawPath, launchUnitID        = action.path, action.launchUnitID
    local translatedPath, translateMsg = translatePath(rawPath, launchUnitID, modelWar)
    if ((not translatedPath)                                              or
        (isPathDestinationOccupiedByVisibleUnit(modelWar, rawPath))) then
        return createActionReloadSceneWar(modelWar, action.playerAccount, 81, MESSAGE_PARAM_OUT_OF_SYNC)
    end

    local focusModelUnit               = getModelUnitMap(modelWar):getFocusModelUnit(translatedPath.pathNodes[1], launchUnitID)
    local revealedTiles, revealedUnits = getRevealedTilesAndUnitsData(modelWar, translatedPath.pathNodes, focusModelUnit, false)
    local actionWait = {
        actionCode       = ACTION_CODES.ActionWait,
        actionID         = action.actionID,
        warID            = action.warID,
        path             = translatedPath,
        launchUnitID     = launchUnitID,
        revealedTiles    = revealedTiles,
        revealedUnits    = revealedUnits,
    }
    return actionWait
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ActionTranslatorForCampaign.translate(action)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionTranslatorForCampaign.translate() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionActivateSkill)          then return translateActivateSkill(         action)
    elseif (actionCode == ACTION_CODES.ActionAttack)                 then return translateAttack(                action)
    elseif (actionCode == ACTION_CODES.ActionBeginTurn)              then return translateBeginTurn(             action)
    elseif (actionCode == ACTION_CODES.ActionBuildModelTile)         then return translateBuildModelTile(        action)
    elseif (actionCode == ACTION_CODES.ActionCaptureModelTile)       then return translateCaptureModelTile(      action)
    elseif (actionCode == ACTION_CODES.ActionDeclareSkill)           then return translateDeclareSkill(          action)
    elseif (actionCode == ACTION_CODES.ActionDestroyOwnedModelUnit)  then return translateDestroyOwnedModelUnit( action)
    elseif (actionCode == ACTION_CODES.ActionDive)                   then return translateDive(                  action)
    elseif (actionCode == ACTION_CODES.ActionDropModelUnit)          then return translateDropModelUnit(         action)
    elseif (actionCode == ACTION_CODES.ActionEndTurn)                then return translateEndTurn(               action)
    elseif (actionCode == ACTION_CODES.ActionJoinModelUnit)          then return translateJoinModelUnit(         action)
    elseif (actionCode == ACTION_CODES.ActionLaunchFlare)            then return translateLaunchFlare(           action)
    elseif (actionCode == ACTION_CODES.ActionLaunchSilo)             then return translateLaunchSilo(            action)
    elseif (actionCode == ACTION_CODES.ActionLoadModelUnit)          then return translateLoadModelUnit(         action)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnTile) then return translateProduceModelUnitOnTile(action)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnUnit) then return translateProduceModelUnitOnUnit(action)
    elseif (actionCode == ACTION_CODES.ActionSurface)                then return translateSurface(               action)
    elseif (actionCode == ACTION_CODES.ActionSurrender)              then return translateSurrender(             action)
    elseif (actionCode == ACTION_CODES.ActionSupplyModelUnit)        then return translateSupplyModelUnit(       action)
    elseif (actionCode == ACTION_CODES.ActionWait)                   then return translateWait(                  action)
    end
end

return ActionTranslatorForCampaign
