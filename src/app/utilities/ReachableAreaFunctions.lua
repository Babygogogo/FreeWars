
--[[--------------------------------------------------------------------------------
-- ReachableAreaFunctions是和ReachableArea相关的函数集合。
-- 所谓ReachableArea就是玩家操作unit时，在地图上绘制的可移动范围。
-- 主要职责：
--   计算及访问ReachableArea
-- 使用场景举例：
--   玩家操作单时，需要调用这里的函数
-- 其他：
--   这些函数原本都是在ModelActionPlanner内的，由于planner日益臃肿，因此独立出来。
--   计算ReachableArea时，势必会顺便计算出各个格子的最短移动路径，因此把这些路径都记录下来，方便MovePath二次利用
--]]--------------------------------------------------------------------------------

local ReachableAreaFunctions = {}

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")

local coroutine = coroutine
local pairs	 = pairs

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function updateAvailableGridList(list, listIndex, gridIndex, prevGridIndex, totalMoveCost)
	local newNode = {
		gridIndex	 = GridIndexFunctions.clone(gridIndex),
		prevGridIndex = (prevGridIndex) and (GridIndexFunctions.clone(prevGridIndex)) or (nil),
		totalMoveCost = totalMoveCost,
	}

	local length = #list
	for i = listIndex + 1, length do
		if (GridIndexFunctions.isEqual(list[i].gridIndex, gridIndex)) then
			if (list[i].totalMoveCost > totalMoveCost) then
				list[i] = newNode
			end
			return
		end
	end
	list[length + 1] = newNode
end

local function reorderListWithMinMoveCost(list, startingIndex)
	local indexForMinMoveCost = startingIndex
	local minMoveCost		 = list[indexForMinMoveCost].totalMoveCost
	for i = startingIndex + 1, #list do
		if (list[i].totalMoveCost < minMoveCost) then
			indexForMinMoveCost = i
			minMoveCost		 = list[i].totalMoveCost
		end
	end

	if (indexForMinMoveCost ~= startingIndex) then
		list[indexForMinMoveCost], list[startingIndex] = list[startingIndex], list[indexForMinMoveCost]
	end

	return list[startingIndex]
end

local function updateArea(area, gridIndex, prevGridIndex, totalMoveCost)
	local x, y = gridIndex.x, gridIndex.y
	area[x]	= area[x]	or {}
	area[x][y] = area[x][y] or {}

	local areaNode = area[x][y]
	if ((areaNode.totalMoveCost) and (areaNode.totalMoveCost <= totalMoveCost)) then
		return false
	else
		areaNode.prevGridIndex = (prevGridIndex) and (GridIndexFunctions.clone(prevGridIndex)) or nil
		areaNode.totalMoveCost = totalMoveCost

		return true
	end
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ReachableAreaFunctions.getAreaNode(area, gridIndex)
	if ((area) and (gridIndex) and (area[gridIndex.x])) then
		return area[gridIndex.x][gridIndex.y]
	else
		return nil
	end
end

function ReachableAreaFunctions.createArea(origin, maxMoveCost, moveCostGetter, shouldYield)
	local area, availableGridList = {}, {}
	updateAvailableGridList(availableGridList, 0, origin, nil, 0)

	local listIndex = 1
	while (listIndex <= #availableGridList) do
		if (shouldYield) then
			coroutine.yield()
		end

		local listNode		 = reorderListWithMinMoveCost(availableGridList, listIndex)
		local currentGridIndex = listNode.gridIndex
		local totalMoveCost	= listNode.totalMoveCost

		if (updateArea(area, currentGridIndex, listNode.prevGridIndex, totalMoveCost)) then
			for _, nextGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(currentGridIndex)) do
				local nextMoveCost = moveCostGetter(nextGridIndex)
				if ((nextMoveCost) and (nextMoveCost + totalMoveCost <= maxMoveCost)) then
					updateAvailableGridList(availableGridList, listIndex, nextGridIndex, currentGridIndex, nextMoveCost + totalMoveCost)
				end
			end
		end

		listIndex = listIndex + 1
	end

	return area
end

function ReachableAreaFunctions.findNearestCapturableTile(modelTileMap, modelUnitMap, modelUnit, shouldYield)
	local area, availableGridList = {}, {}
	updateAvailableGridList(availableGridList, 0, modelUnit:getGridIndex(), nil, 0)

	local teamIndex = modelUnit:getTeamIndex()
	local mapSize   = modelTileMap:getMapSize()
	local listIndex = 1
	while (listIndex <= #availableGridList) do
		if (shouldYield) then
			coroutine.yield()
		end

		local listNode		  = reorderListWithMinMoveCost(availableGridList, listIndex)
		local currentGridIndex  = listNode.gridIndex
		local totalMoveCost	 = listNode.totalMoveCost
		local modelTile		 = modelTileMap:getModelTile(currentGridIndex)
		local existingModelUnit = modelUnitMap:getModelUnit(currentGridIndex)

		if ((modelTile.getCurrentCapturePoint)																				and
			(modelTile:getTeamIndex() ~= teamIndex)																		   and
			((not existingModelUnit) or (existingModelUnit == modelUnit) or (existingModelUnit:getTeamIndex() ~= teamIndex))) then
			return modelTile
		elseif (updateArea(area, currentGridIndex, nil, totalMoveCost)) then
			for _, nextGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(currentGridIndex, mapSize)) do
				local nextMoveCost = modelTileMap:getModelTile(nextGridIndex):getMoveCostWithModelUnit(modelUnit)
				if (nextMoveCost) then
					updateAvailableGridList(availableGridList, listIndex, nextGridIndex, nil, totalMoveCost + nextMoveCost)
				end
			end
		end

		listIndex = listIndex + 1
	end

	return nil
end

function ReachableAreaFunctions.createDistanceMap(modelTileMap, modelUnit, distination, shouldYield)
	local area, availableGridList = {}, {}
	updateAvailableGridList(availableGridList, 0, distination, nil, 0)

	local mapSize   = modelTileMap:getMapSize()
	local listIndex = 1
	while (listIndex <= #availableGridList) do
		if (shouldYield) then
			coroutine.yield()
		end

		local listNode		 = reorderListWithMinMoveCost(availableGridList, listIndex)
		local currentGridIndex = listNode.gridIndex
		local totalMoveCost	= listNode.totalMoveCost

		if (updateArea(area, currentGridIndex, nil, totalMoveCost)) then
			local nextMoveCost = modelTileMap:getModelTile(currentGridIndex):getMoveCostWithModelUnit(modelUnit)
			if (nextMoveCost) then
				for _, nextGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(currentGridIndex, mapSize)) do
					updateAvailableGridList(availableGridList, listIndex, nextGridIndex, nil, totalMoveCost + nextMoveCost)
				end
			end
		end

		listIndex = listIndex + 1
	end

	local maxDistance = 0
	for x = 1, mapSize.width do
		area[x] = area[x] or {}
		for y = 1, mapSize.height do
			if (area[x][y]) then
				area[x][y] = area[x][y].totalMoveCost
				maxDistance = math.max(maxDistance, area[x][y])
			end
		end
	end

	return area, maxDistance
end

return ReachableAreaFunctions
