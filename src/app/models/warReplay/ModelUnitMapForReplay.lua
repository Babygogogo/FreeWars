
local ModelUnitMapForReplay = requireFW("src.global.functions.class")("ModelUnitMapForReplay")

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")
local WarFieldManager	= requireFW("src.app.utilities.WarFieldManager")
local Actor			  = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getActorUnit(self, gridIndex)
	assert(GridIndexFunctions.isWithinMap(gridIndex, self:getMapSize()),
		"ModelUnitMapForReplay-getActorUnit() the param gridIndex is not within the map.")

	return self.m_ActorUnitsMap[gridIndex.x][gridIndex.y]
end

local function getActorUnitLoaded(self, unitID)
	return self.m_LoadedActorUnits[unitID]
end

local function createEmptyMap(width)
	local map = {}
	for x = 1, width do
		map[x] = {}
	end

	return map
end

local function createActorUnit(tiledID, unitID, x, y)
	local actorData = {
		tiledID	   = tiledID,
		unitID		= unitID,
		GridIndexable = {x = x, y = y},
	}

	return Actor.createWithModelAndViewName("warReplay.ModelUnitForReplay", actorData, "common.ViewUnit")
end

--------------------------------------------------------------------------------
-- The unit actors map.
--------------------------------------------------------------------------------
local function createActorUnitsMapWithWarFieldFileName(warFieldFileName)
	local layer			   = WarFieldManager.getWarFieldData(warFieldFileName).layers[3]
	local data, width, height = layer.data, layer.width, layer.height
	local actorUnitsMap	   = createEmptyMap(width)
	local availableUnitID	 = 1

	for x = 1, width do
		for y = 1, height do
			local tiledID = data[x + (height - y) * width]
			if (tiledID > 0) then
				actorUnitsMap[x][y] = createActorUnit(tiledID, availableUnitID, x, y)
				availableUnitID	 = availableUnitID + 1
			end
		end
	end

	return actorUnitsMap, {width = width, height = height}, availableUnitID, {}
end

local function createActorUnitsMapWithUnitMapData(unitMapData, warFieldFileName)
	local layer		 = WarFieldManager.getWarFieldData(warFieldFileName).layers[3]
	local width, height = layer.width, layer.height
	local mapSize	   = {width = width, height = height}

	local actorUnitsMap = createEmptyMap(width)
	for _, unitData in pairs(unitMapData.unitsOnMap) do
		local gridIndex = unitData.GridIndexable
		assert(GridIndexFunctions.isWithinMap(gridIndex, mapSize), "ModelUnitMapForReplay-createActorUnitsMapWithUnitMapData() the gridIndex is invalid.")

		actorUnitsMap[gridIndex.x][gridIndex.y] = Actor.createWithModelAndViewName("warReplay.ModelUnitForReplay", unitData, "common.ViewUnit")
	end

	local loadedActorUnits = {}
	for unitID, unitData in pairs(unitMapData.unitsLoaded or {}) do
		loadedActorUnits[unitID] = Actor.createWithModelAndViewName("warReplay.ModelUnitForReplay", unitData, "common.ViewUnit")
	end

	return actorUnitsMap, mapSize, unitMapData.availableUnitID, loadedActorUnits
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelUnitMapForReplay:ctor(unitMapData, warFieldFileName)
	if (unitMapData) then
		self.m_ActorUnitsMap, self.m_MapSize, self.m_AvailableUnitID, self.m_LoadedActorUnits = createActorUnitsMapWithUnitMapData(unitMapData, warFieldFileName)
	else
		self.m_ActorUnitsMap, self.m_MapSize, self.m_AvailableUnitID, self.m_LoadedActorUnits = createActorUnitsMapWithWarFieldFileName(warFieldFileName)
	end

	if (self.m_View) then
		self:initView()
	end

	return self
end

function ModelUnitMapForReplay:initView()
	local view = self.m_View
	assert(view, "ModelUnitMapForReplay:initView() there's no view attached to the owner actor of the model.")

	local mapSize = self:getMapSize()
	view:setMapSize(mapSize)
		:removeAllViewUnits()

	local actorUnitsMap = self.m_ActorUnitsMap
	for y = mapSize.height, 1, -1 do
		for x = mapSize.width, 1, -1 do
			local actorUnit = actorUnitsMap[x][y]
			if (actorUnit) then
				view:addViewUnit(actorUnit:getView(), actorUnit:getModel())
			end
		end
	end

	for unitID, actorUnit in pairs(self.m_LoadedActorUnits) do
		view:addViewUnit(actorUnit:getView(), actorUnit:getModel())
	end

	return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelUnitMapForReplay:toSerializableTable()
	local unitsOnMap = {}
	self:forEachModelUnitOnMap(function(modelUnit)
		unitsOnMap[modelUnit:getUnitId()] = modelUnit:toSerializableTable()
	end)

	local unitsLoaded = {}
	self:forEachModelUnitLoaded(function(modelUnit)
		unitsLoaded[modelUnit:getUnitId()] = modelUnit:toSerializableTable()
	end)

	return {
		availableUnitID = self.m_AvailableUnitID,
		unitsOnMap	  = unitsOnMap,
		unitsLoaded	 = unitsLoaded,
	}
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelUnitMapForReplay:onStartRunning(modelWarReplay)
	local func = function(modelUnit)
		modelUnit:onStartRunning(modelWarReplay)
	end
	self:forEachModelUnitOnMap( func)
		:forEachModelUnitLoaded(func)

	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelUnitMapForReplay:getMapSize()
	return self.m_MapSize
end

function ModelUnitMapForReplay:getAvailableUnitId()
	return self.m_AvailableUnitID
end

function ModelUnitMapForReplay:setAvailableUnitId(unitID)
	assert((unitID >= 0) and (math.floor(unitID) == unitID), "ModelUnitMapForReplay:setAvailableUnitId() invalid unitID: " .. (unitID or ""))
	self.m_AvailableUnitID = unitID

	return self
end

function ModelUnitMapForReplay:getFocusModelUnit(gridIndex, launchUnitID)
	return (launchUnitID)								 and
		(self:getLoadedModelUnitWithUnitId(launchUnitID)) or
		(self:getModelUnit(gridIndex))
end

function ModelUnitMapForReplay:getModelUnit(gridIndex)
	local actorUnit = getActorUnit(self, gridIndex)
	return (actorUnit) and (actorUnit:getModel()) or (nil)
end

function ModelUnitMapForReplay:getLoadedModelUnitWithUnitId(unitID)
	local actorUnit = getActorUnitLoaded(self, unitID)
	return (actorUnit) and (actorUnit:getModel()) or (nil)
end

function ModelUnitMapForReplay:getLoadedModelUnitsWithLoader(loaderModelUnit, isRecursive)
	if (not loaderModelUnit.getLoadUnitIdList) then
		return nil
	else
		local list = {}
		for _, unitID in ipairs(loaderModelUnit:getLoadUnitIdList()) do
			list[#list + 1] = self:getLoadedModelUnitWithUnitId(unitID)
		end
		assert(#list == loaderModelUnit:getCurrentLoadCount())

		if (isRecursive) then
			for _, loader in ipairs(list) do
				local subList = self:getLoadedModelUnitsWithLoader(loader, true)
				if (subList) then
					for _, subItem in ipairs(subList) do
						list[#list + 1] = subItem
					end
				end
			end
		end

		return list
	end
end

function ModelUnitMapForReplay:swapActorUnit(gridIndex1, gridIndex2)
	if (GridIndexFunctions.isEqual(gridIndex1, gridIndex2)) then
		return self
	end

	local x1, y1 = gridIndex1.x, gridIndex1.y
	local x2, y2 = gridIndex2.x, gridIndex2.y
	local map	= self.m_ActorUnitsMap
	map[x1][y1], map[x2][y2] = map[x2][y2], map[x1][y1]

	return self
end

function ModelUnitMapForReplay:setActorUnitLoaded(gridIndex)
	local loaded = self.m_LoadedActorUnits
	local map	= self.m_ActorUnitsMap
	local x, y   = gridIndex.x, gridIndex.y
	local unitID = map[x][y]:getModel():getUnitId()
	assert(loaded[unitID] == nil, "ModelUnitMapForReplay:setActorUnitLoaded() the focus unit has been loaded already.")

	loaded[unitID], map[x][y] = map[x][y], loaded[unitID]

	return self
end

function ModelUnitMapForReplay:setActorUnitUnloaded(unitID, gridIndex)
	local loaded = self.m_LoadedActorUnits
	local map	= self.m_ActorUnitsMap
	local x, y   = gridIndex.x, gridIndex.y
	assert(loaded[unitID], "ModelUnitMapForReplay-setActorUnitUnloaded() the focus unit is not loaded.")
	assert(map[x][y] == nil, "ModelUnitMapForReplay-setActorUnitUnloaded() another unit is occupying the destination.")

	loaded[unitID], map[x][y] = map[x][y], loaded[unitID]

	return self
end

function ModelUnitMapForReplay:addActorUnitOnMap(actorUnit)
	local modelUnit = actorUnit:getModel()
	local gridIndex = modelUnit:getGridIndex()
	local x, y	  = gridIndex.x, gridIndex.y
	assert(not self.m_ActorUnitsMap[x][y], "ModelUnitMapForReplay:addActorUnitOnMap() there's another unit on the grid: " .. x .. " " .. y)
	self.m_ActorUnitsMap[x][y] = actorUnit

	if (self.m_View) then
		self.m_View:addViewUnit(actorUnit:getView(), modelUnit)
	end

	return self
end

function ModelUnitMapForReplay:removeActorUnitOnMap(gridIndex)
	local x, y = gridIndex.x, gridIndex.y
	assert(self.m_ActorUnitsMap[x][y], "ModelUnitMapForReplay:removeActorUnitOnMap() there's no unit on the grid: " .. x .. " " .. y)
	self.m_ActorUnitsMap[x][y] = nil

	return self
end

function ModelUnitMapForReplay:addActorUnitLoaded(actorUnit)
	local modelUnit = actorUnit:getModel()
	local unitID	= modelUnit:getUnitId()
	assert(self.m_LoadedActorUnits[unitID] == nil, "ModelUnitMapForReplay:addActorUnitLoaded() the unit id is loaded already: " .. unitID)
	self.m_LoadedActorUnits[unitID] = actorUnit

	if (self.m_View) then
		self.m_View:addViewUnit(actorUnit:getView(), modelUnit)
	end

	return self
end

function ModelUnitMapForReplay:removeActorUnitLoaded(unitID)
	local loadedModelUnit = self:getLoadedModelUnitWithUnitId(unitID)
	assert(loadedModelUnit, "ModelUnitMapForReplay:removeActorUnitLoaded() the unit that the unitID refers to is not loaded: " .. (unitID or ""))
	self.m_LoadedActorUnits[unitID] = nil

	return self
end

function ModelUnitMapForReplay:forEachModelUnitOnMap(func)
	local mapSize = self:getMapSize()
	for x = 1, mapSize.width do
		for y = 1, mapSize.height do
			local actorUnit = self.m_ActorUnitsMap[x][y]
			if (actorUnit) then
				func(actorUnit:getModel())
			end
		end
	end

	return self
end

function ModelUnitMapForReplay:forEachModelUnitLoaded(func)
	for _, actorUnit in pairs(self.m_LoadedActorUnits) do
		func(actorUnit:getModel())
	end

	return self
end

return ModelUnitMapForReplay
