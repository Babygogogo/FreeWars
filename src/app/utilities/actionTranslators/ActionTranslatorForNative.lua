
local ActionTranslatorForNative = {}

local Producible			  = requireFW("src.app.components.Producible")
local ActionCodeFunctions	 = requireFW("src.app.utilities.ActionCodeFunctions")
local DamageCalculator		= requireFW("src.app.utilities.DamageCalculator")
local GameConstantFunctions   = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions	  = requireFW("src.app.utilities.GridIndexFunctions")
local LocalizationFunctions   = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions  = requireFW("src.app.utilities.SerializationFunctions")
local SkillModifierFunctions  = requireFW("src.app.utilities.SkillModifierFunctions")
local SingletonGetters		= requireFW("src.app.utilities.SingletonGetters")
local TableFunctions		  = requireFW("src.app.utilities.TableFunctions")
local VisibilityFunctions	 = requireFW("src.app.utilities.VisibilityFunctions")
local Actor				   = requireFW("src.global.actors.Actor")
local ComponentManager		= requireFW("src.global.components.ComponentManager")

local getLocalizedText			 = LocalizationFunctions.getLocalizedText
local getModelFogMap			   = SingletonGetters.getModelFogMap
local getModelPlayerManager		= SingletonGetters.getModelPlayerManager
local getModelTileMap			  = SingletonGetters.getModelTileMap
local getModelTurnManager		  = SingletonGetters.getModelTurnManager
local getModelUnitMap			  = SingletonGetters.getModelUnitMap
local getRevealedTilesAndUnitsData = VisibilityFunctions.getRevealedTilesAndUnitsData
local isUnitVisible				= VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local ipairs, pairs, next		  = ipairs, pairs, next
local math						 = math

local ACTION_CODES = ActionCodeFunctions.getFullList()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
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
	local income	  = 0
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
	local mapSize	   = modelUnitMap:getMapSize()
	local width, height = mapSize.width, mapSize.height
	local hasUnit	   = false

	for x = 1, width do
		for y = 1, height do
			local gridIndex = {x = x, y = y}
			local modelUnit = modelUnitMap:getModelUnit(gridIndex)
			if ((modelUnit) and (modelUnit:getPlayerIndex() == playerIndex)) then
				hasUnit = true
				if ((modelUnit.getCurrentFuel)											and
					(modelUnit:getCurrentFuel() <= modelUnit:getFuelConsumptionPerTurn()) and
					(modelUnit:shouldDestroyOnOutOfFuel()))							   then

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
	local units		= {}

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
		return (cost1 > cost2)											 or
			((cost1 == cost2) and (unit1:getUnitId() < unit2:getUnitId()))
	end)

	return units
end

local function getRepairAmountAndCost(modelUnit, fund, maxNormalizedRepairAmount, costModifier)
	local productionCost		 = math.floor(modelUnit:getProductionCost() * costModifier)
	local normalizedCurrentHP	= modelUnit:getNormalizedCurrentHP()
	local normalizedRepairAmount = math.min(
		10 - normalizedCurrentHP,
		maxNormalizedRepairAmount,
		math.floor(fund * 10 / productionCost)
	)

	return (normalizedRepairAmount + normalizedCurrentHP) * 10 - modelUnit:getCurrentHP(),
		math.floor(normalizedRepairAmount * productionCost / 10)
end

local function generateRepairDataOnBeginTurn(modelWar)
	local modelUnitMap			  = getModelUnitMap(modelWar)
	local modelPlayer			   = getModelPlayerManager(modelWar):getModelPlayer(getModelTurnManager(modelWar):getPlayerIndex())
	local skillConfiguration		= modelPlayer:getModelSkillConfiguration()
	local fund					  = modelPlayer:getFund() + getIncomeOnBeginTurn(modelWar)
	local maxNormalizedRepairAmount = GameConstantFunctions.getBaseNormalizedRepairAmount() + SkillModifierFunctions.getRepairAmountModifierForSkillConfiguration(skillConfiguration)
	local costModifier			  = 1 -- + SkillModifierFunctions.getRepairCostModifier(skillConfiguration) / 100

	local onMapData, loadedData
	for _, modelUnit in ipairs(getRepairableModelUnits(modelWar)) do
		local repairAmount, repairCost = getRepairAmountAndCost(modelUnit, fund, maxNormalizedRepairAmount, costModifier)
		local unitID				   = modelUnit:getUnitId()
		if (modelUnitMap:getLoadedModelUnitWithUnitId(unitID)) then
			loadedData		 = loadedData or {}
			loadedData[unitID] = {
				unitID	   = unitID,
				repairAmount = repairAmount,
			}
		else
			onMapData		 = onMapData or {}
			onMapData[unitID] = {
				unitID	   = unitID,
				repairAmount = repairAmount,
				gridIndex	= GridIndexFunctions.clone(modelUnit:getGridIndex()),
			}
		end
		fund = fund - repairCost
	end

	return {
		onMapData	 = onMapData,
		loadedData	= loadedData,
		remainingFund = fund,
	}
end

local function generateSupplyDataOnBeginTurn(modelWar, repairData)
	local modelUnitMap		  = getModelUnitMap(modelWar)
	local playerIndex		   = getModelTurnManager(modelWar):getPlayerIndex()
	local mapSize			   = modelUnitMap:getMapSize()
	local repairDataOnMap	   = repairData.onMapData
	local repairDataLoaded	  = repairData.loadedData
	local onMapData, loadedData

	local updateOnMapData = function(supplier)
		if ((supplier:getPlayerIndex() == playerIndex) and (supplier.canSupplyModelUnit)) then
			if (((repairDataOnMap) and (repairDataOnMap[supplier:getUnitId()]))														or
				(not ((supplier:shouldDestroyOnOutOfFuel()) and (supplier:getCurrentFuel() <= supplier:getFuelConsumptionPerTurn())))) then

				for _, adjacentGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(supplier:getGridIndex(), mapSize)) do
					local target = modelUnitMap:getModelUnit(adjacentGridIndex)
					if ((target) and (supplier:canSupplyModelUnit(target))) then
						local unitID = target:getUnitId()
						if (((not repairDataOnMap) or (not repairDataOnMap[unitID]))														 and
							((not onMapData)	   or (not onMapData[unitID]))															   and
							(not ((target:shouldDestroyOnOutOfFuel()) and (target:getCurrentFuel() <= target:getFuelConsumptionPerTurn())))) then

							onMapData		 = onMapData or {}
							onMapData[unitID] = {
								unitID	= unitID,
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
			(supplier.canSupplyLoadedModelUnit)		and
			(supplier:canSupplyLoadedModelUnit())	  and
			(not supplier:canRepairLoadedModelUnit())) then
			if (((repairDataOnMap) and (repairDataOnMap[supplier:getUnitId()]))														or
				(not ((supplier:shouldDestroyOnOutOfFuel()) and (supplier:getCurrentFuel() <= supplier:getFuelConsumptionPerTurn())))) then

				for _, unitID in pairs(supplier:getLoadUnitIdList()) do
					loadedData		 = loadedData or {}
					loadedData[unitID] = {unitID = unitID}
				end
			end
		end
	end

	modelUnitMap:forEachModelUnitOnMap(updateOnMapData)
		:forEachModelUnitOnMap(		updateLoadedData)
		:forEachModelUnitLoaded(	   updateLoadedData)

	if ((not onMapData) and (not loadedData)) then
		return nil
	else
		return {
			onMapData  = onMapData,
			loadedData = loadedData,
		}
	end
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

local function createActionWait(actionID, path, launchUnitID)
	return {
		actionCode	= ACTION_CODES.ActionWait,
		actionID	  = actionID,
		launchUnitID  = launchUnitID,
		path		  = path,
	}
end

--------------------------------------------------------------------------------
-- The translate functions.
--------------------------------------------------------------------------------
-- This translation ignores the existing unit of the same player at the end of the path, so that the actions of Join/Attack/Wait can reuse this function.
local function translatePath(path, launchUnitID, modelWar)
	local modelTurnManager   = getModelTurnManager(modelWar)
	local modelUnitMap	   = getModelUnitMap(modelWar)
	local playerIndexInTurn  = modelTurnManager:getPlayerIndex()
	local rawPathNodes	   = path.pathNodes
	local beginningGridIndex = rawPathNodes[1]
	local mapSize			= modelUnitMap:getMapSize()
	local focusModelUnit	 = modelUnitMap:getFocusModelUnit(beginningGridIndex, launchUnitID)
	local isWithinMap		= GridIndexFunctions.isWithinMap

	if (not isWithinMap(beginningGridIndex, mapSize)) then
		return nil, "ActionTranslatorForNative-translatePath() a node in the path is not within the map."
	elseif (not focusModelUnit) then
		return nil, "ActionTranslatorForNative-translatePath() there is no unit on the starting grid of the path."
	elseif (focusModelUnit:getPlayerIndex() ~= playerIndexInTurn) then
		return nil, "ActionTranslatorForNative-translatePath() the owner player of the moving unit is not in his turn."
	elseif (not focusModelUnit:isStateIdle()) then
		return nil, "ActionTranslatorForNative-translatePath() the moving unit is not in idle state."
	elseif (not modelTurnManager:isTurnPhaseMain()) then
		return nil, "ActionTranslatorForNative-translatePath() the turn phase is not 'main'."
	end

	local teamIndexInTurn	  = getModelPlayerManager(modelWar):getModelPlayer(playerIndexInTurn):getTeamIndex()
	local modelTileMap		 = getModelTileMap(modelWar)
	local translatedPathNodes  = {GridIndexFunctions.clone(beginningGridIndex)}
	local translatedPath	   = {pathNodes = translatedPathNodes}
	local totalFuelConsumption = 0
	local maxFuelConsumption   = math.min(focusModelUnit:getCurrentFuel(), focusModelUnit:getMoveRange())

	for i = 2, #rawPathNodes do
		local gridIndex = rawPathNodes[i]
		if (not GridIndexFunctions.isAdjacent(rawPathNodes[i - 1], gridIndex)) then
			return nil, "ActionTranslatorForNative-translatePath() the path is invalid because some grids are not adjacent to previous ones."
		elseif (isGridInPathNodes(gridIndex, translatedPathNodes)) then
			return nil, "ActionTranslatorForNative-translatePath() some grids in the path are the same."
		elseif (not isWithinMap(gridIndex, mapSize)) then
			return nil, "ActionTranslatorForNative-translatePath() a node in the path is not within the map."
		end

		local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
		if ((existingModelUnit) and (existingModelUnit:getTeamIndex() ~= teamIndexInTurn)) then
			if (isUnitVisible(modelWar, gridIndex, existingModelUnit:getUnitType(), isModelUnitDiving(existingModelUnit), existingModelUnit:getPlayerIndex(), playerIndexInTurn)) then
				return nil, "ActionTranslatorForNative-translatePath() the path is invalid because it is blocked by a visible enemy unit."
			else
				translatedPath.isBlocked = true
			end
		end

		local fuelConsumption = modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(focusModelUnit)
		if (not fuelConsumption) then
			return nil, "ActionTranslatorForNative-translatePath() the path is invalid because some tiles on it is impassable."
		end

		totalFuelConsumption = totalFuelConsumption + fuelConsumption
		if (totalFuelConsumption > maxFuelConsumption) then
			return nil, "ActionTranslatorForNative-translatePath() the path is invalid because the fuel consumption is too high."
		end

		if (not translatedPath.isBlocked) then
			translatedPath.fuelConsumption				= totalFuelConsumption
			translatedPathNodes[#translatedPathNodes + 1] = GridIndexFunctions.clone(gridIndex)
		end
	end

	return translatedPath
end

local function translateActivateSkill(action)
	return action
end

local function translateAttack(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		local modelUnitMap				= getModelUnitMap(modelWar)
		local attacker					= modelUnitMap:getFocusModelUnit(rawPath.pathNodes[1], launchUnitID)
		local targetGridIndex			 = action.targetGridIndex
		local attackTarget				= modelUnitMap:getModelUnit(targetGridIndex) or getModelTileMap(modelWar):getModelTile(targetGridIndex)
		local attackDamage, counterDamage = DamageCalculator.getUltimateBattleDamage(rawPath.pathNodes, launchUnitID, targetGridIndex, modelWar)
		return {
			actionCode	   = ACTION_CODES.ActionAttack,
			actionID		 = action.actionID,
			path			 = translatedPath,
			launchUnitID	 = launchUnitID,
			targetGridIndex  = targetGridIndex,
			attackDamage	 = attackDamage,
			counterDamage	= counterDamage,
			lostPlayerIndex  = getLostPlayerIndexForActionAttack(modelWar, attacker, attackTarget, attackDamage, counterDamage),
		}
	end
end

local function translateBeginTurn(action)
	local modelWar		 = action.modelWar
	local modelTurnManager = getModelTurnManager(modelWar)
	assert(modelTurnManager:isTurnPhaseRequestToBegin())

	local actionBeginTurn = {
		actionCode = ACTION_CODES.ActionBeginTurn,
		actionID   = action.actionID,
	}
	if (modelTurnManager:getTurnIndex() == 1) then
		actionBeginTurn.income = getIncomeOnBeginTurn(modelWar)
	else
		actionBeginTurn.lostPlayerIndex = (areAllUnitsDestroyedOnBeginTurn(modelWar)) and (modelTurnManager:getPlayerIndex()) or (nil)
		actionBeginTurn.repairData	  = generateRepairDataOnBeginTurn(modelWar)
		actionBeginTurn.supplyData	  = generateSupplyDataOnBeginTurn(modelWar, actionBeginTurn.repairData)
	end
	return actionBeginTurn
end

local function translateBuildModelTile(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode   = ACTION_CODES.ActionBuildModelTile,
			actionID	 = action.actionID,
			path		 = translatedPath,
			launchUnitID = launchUnitID,
		}
	end
end

local function translateCaptureModelTile(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		local rawPathNodes	  = rawPath.pathNodes
		local endingGridIndex   = rawPathNodes[#rawPathNodes]
		local capturer		  = getModelUnitMap(modelWar):getFocusModelUnit(rawPathNodes[1], launchUnitID)
		local captureTarget	 = getModelTileMap(modelWar):getModelTile(endingGridIndex)
		local isCaptureFinished = capturer:getCaptureAmount() >= captureTarget:getCurrentCapturePoint()
		return {
			actionCode	  = ACTION_CODES.ActionCaptureModelTile,
			actionID		= action.actionID,
			path			= translatedPath,
			launchUnitID	= launchUnitID,
			lostPlayerIndex = ((isCaptureFinished) and (captureTarget:isDefeatOnCapture()))
				and (captureTarget:getPlayerIndex())
				or  (nil),
		}
	end
end

local function translateDestroyOwnedModelUnit(action)
	return action
end

local function translateDive(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode   = ACTION_CODES.ActionDive,
			actionID	 = action.actionID,
			path		 = translatedPath,
			launchUnitID = launchUnitID,
		}
	end
end

local function translateDropModelUnit(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		local modelUnitMap					= getModelUnitMap(modelWar)
		local loaderModelUnit				 = modelUnitMap:getFocusModelUnit(rawPath.pathNodes[1], launchUnitID)
		local dropDestinations, isDropBlocked = translateDropDestinations(action.dropDestinations, modelUnitMap, loaderModelUnit)
		return {
			actionCode	   = ACTION_CODES.ActionDropModelUnit,
			actionID		 = action.actionID,
			path			 = translatedPath,
			dropDestinations = dropDestinations,
			isDropBlocked	= isDropBlocked,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateEndTurn(action)
	return action
end

local function translateJoinModelUnit(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionJoinModelUnit,
			actionID		 = action.actionID,
			path			 = translatedPath,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateLaunchFlare(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionLaunchFlare,
			actionID		 = action.actionID,
			path			 = translatedPath,
			targetGridIndex  = action.targetGridIndex,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateLaunchSilo(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionLaunchSilo,
			actionID		 = action.actionID,
			path			 = translatedPath,
			targetGridIndex  = action.targetGridIndex,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateLoadModelUnit(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionLoadModelUnit,
			actionID		 = action.actionID,
			path			 = translatedPath,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateProduceModelUnitOnTile(action)
	local tiledID = action.tiledID
	return {
		actionCode = ACTION_CODES.ActionProduceModelUnitOnTile,
		actionID   = action.actionID,
		gridIndex  = action.gridIndex,
		tiledID	= tiledID,
		cost	   = Producible.getProductionCostWithTiledId(tiledID, getModelPlayerManager(action.modelWar)), -- the cost can be calculated by the clients, but that calculations can be eliminated by sending the cost to clients.
	}
end

local function translateProduceModelUnitOnUnit(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	local rawPathNodes		  = rawPath.pathNodes
	local focusModelUnit		= getModelUnitMap(modelWar):getFocusModelUnit(rawPathNodes[1], launchUnitID)
	return {
		actionCode = ACTION_CODES.ActionProduceModelUnitOnUnit,
		actionID   = action.actionID,
		path	   = translatedPath,
		cost	   = (focusModelUnit.getMovableProductionCost) and (focusModelUnit:getMovableProductionCost()) or (nil),
	}
end

local function translateResearchPassiveSkill(action)
	return action
end

local function translateSupplyModelUnit(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionSupplyModelUnit,
			actionID		 = action.actionID,
			path			 = translatedPath,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateSurface(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	if (translatedPath.isBlocked) then
		return createActionWait(action.actionID, translatedPath, launchUnitID)
	else
		return {
			actionCode	   = ACTION_CODES.ActionSurface,
			actionID		 = action.actionID,
			path			 = translatedPath,
			launchUnitID	 = launchUnitID,
		}
	end
end

local function translateSurrender(action)
	return action
end

local function translateUpdateReserveSkills(action)
	return action
end

local function translateWait(action)
	local modelWar			  = action.modelWar
	local rawPath, launchUnitID = action.path, action.launchUnitID
	local translatedPath		= translatePath(rawPath, launchUnitID, modelWar)
	return createActionWait(action.actionID, translatedPath, launchUnitID)
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ActionTranslatorForNative.translate(action)
	local actionCode = action.actionCode
	assert(ActionCodeFunctions.getActionName(actionCode), "ActionTranslatorForNative.translate() invalid actionCode: " .. (actionCode or ""))

	if	 (actionCode == ACTION_CODES.ActionActivateSkill)		  then return translateActivateSkill(		 action)
	elseif (actionCode == ACTION_CODES.ActionAttack)				 then return translateAttack(				action)
	elseif (actionCode == ACTION_CODES.ActionBeginTurn)			  then return translateBeginTurn(			 action)
	elseif (actionCode == ACTION_CODES.ActionBuildModelTile)		 then return translateBuildModelTile(		action)
	elseif (actionCode == ACTION_CODES.ActionCaptureModelTile)	   then return translateCaptureModelTile(	  action)
	elseif (actionCode == ACTION_CODES.ActionDestroyOwnedModelUnit)  then return translateDestroyOwnedModelUnit( action)
	elseif (actionCode == ACTION_CODES.ActionDive)				   then return translateDive(				  action)
	elseif (actionCode == ACTION_CODES.ActionDropModelUnit)		  then return translateDropModelUnit(		 action)
	elseif (actionCode == ACTION_CODES.ActionEndTurn)				then return translateEndTurn(			   action)
	elseif (actionCode == ACTION_CODES.ActionJoinModelUnit)		  then return translateJoinModelUnit(		 action)
	elseif (actionCode == ACTION_CODES.ActionLaunchFlare)			then return translateLaunchFlare(		   action)
	elseif (actionCode == ACTION_CODES.ActionLaunchSilo)			 then return translateLaunchSilo(			action)
	elseif (actionCode == ACTION_CODES.ActionLoadModelUnit)		  then return translateLoadModelUnit(		 action)
	elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnTile) then return translateProduceModelUnitOnTile(action)
	elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnUnit) then return translateProduceModelUnitOnUnit(action)
	elseif (actionCode == ACTION_CODES.ActionResearchPassiveSkill)   then return translateResearchPassiveSkill(  action)
	elseif (actionCode == ACTION_CODES.ActionSupplyModelUnit)		then return translateSupplyModelUnit(	   action)
	elseif (actionCode == ACTION_CODES.ActionSurface)				then return translateSurface(			   action)
	elseif (actionCode == ACTION_CODES.ActionSurrender)			  then return translateSurrender(			 action)
	elseif (actionCode == ACTION_CODES.ActionUpdateReserveSkills)	then return translateUpdateReserveSkills(   action)
	elseif (actionCode == ACTION_CODES.ActionWait)				   then return translateWait(				  action)
	end
end

return ActionTranslatorForNative
