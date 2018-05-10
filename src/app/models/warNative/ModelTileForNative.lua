
local ModelTileForNative = requireFW("src.global.functions.class")("ModelTileForNative")

local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters	  = requireFW("src.app.utilities.SingletonGetters")
local VisibilityFunctions   = requireFW("src.app.utilities.VisibilityFunctions")
local ComponentManager	  = requireFW("src.global.components.ComponentManager")

local string					   = string
local getTiledIdWithTileOrUnitName = GameConstantFunctions.getTiledIdWithTileOrUnitName

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function initWithTiledID(self, objectID, baseID)
	self.m_InitialObjectID = self.m_InitialObjectID or objectID
	self.m_InitialBaseID   = self.m_InitialBaseID   or baseID

	self.m_ObjectID = objectID or self.m_ObjectID
	self.m_BaseID   = baseID   or self.m_BaseID
	assert(self.m_ObjectID and self.m_BaseID, "ModelTileForNative-initWithTiledID() failed to init self.m_ObjectID and/or self.m_BaseID.")

	local template = GameConstantFunctions.getTemplateModelTileWithObjectAndBaseId(self.m_ObjectID, self.m_BaseID)
	assert(template, "ModelTileForNative-initWithTiledID() failed to get the template model tile with param objectID and baseID.")

	if (self.m_Template ~= template) then
		self.m_Template = template

		ComponentManager.unbindAllComponents(self)
		for name, data in pairs(template) do
			if (string.byte(name) > string.byte("z")) or (string.byte(name) < string.byte("a")) then
				ComponentManager.bindComponent(self, name, {template = data, instantialData = data})
			end
		end
	end
end

local function loadInstantialData(self, param)
	for name, data in pairs(param) do
		if (string.byte(name) > string.byte("z")) or (string.byte(name) < string.byte("a")) then
			local component = ComponentManager.getComponent(self, name)
			if (component.loadInstantialData) then
				component:loadInstantialData(data)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelTileForNative:ctor(param)
	self.m_PositionIndex = param.positionIndex
	if ((param.objectID) or (param.baseID)) then
		initWithTiledID(self, param.objectID, param.baseID)
	end
	loadInstantialData(self, param)

	if (self.m_View) then
		self:initView()
	end

	return self
end

function ModelTileForNative:initView()
	local view = self.m_View
	assert(view, "ModelTileForNative:initView() no view is attached to the actor of the model.")

	self:setViewPositionWithGridIndex()
		:updateView()

	return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelTileForNative:toSerializableTable()
	local t			   = {}
	local componentsCount = 0
	for name, component in pairs(ComponentManager.getAllComponents(self)) do
		if ((name ~= "GridIndexable") and (component.toSerializableTable)) then
			local componentTable = component:toSerializableTable()
			if (componentTable) then
				t[name]		 = componentTable
				componentsCount = componentsCount + 1
			end
		end
	end

	local objectID, baseID = self:getObjectAndBaseId()
	if ((baseID == self.m_InitialBaseID) and (objectID == self.m_InitialObjectID) and (componentsCount == 0)) then
		return nil
	else
		t.positionIndex = self.m_PositionIndex
		t.baseID		= (baseID   ~= self.m_InitialBaseID)   and (baseID)   or (nil)
		t.objectID	  = (objectID ~= self.m_InitialObjectID) and (objectID) or (nil)

		return t
	end
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function ModelTileForNative:onStartRunning(modelWar)
	self.m_ModelWar = modelWar
	ComponentManager.callMethodForAllComponents(self, "onStartRunning", modelWar)

	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTileForNative:updateView()
	local modelWar = self.m_ModelWar
	if (not modelWar) then
		self.m_View:setViewObjectWithTiledId(self.m_ObjectID)
			:setViewBaseWithTiledId(self.m_BaseID)
	else
		local playerIndexForHuman = SingletonGetters.getModelPlayerManager(modelWar):getPlayerIndexForHuman()
		local isVisible		   = VisibilityFunctions.isTileVisibleToPlayerIndex(modelWar, self:getGridIndex(), playerIndexForHuman)
		local tileType			= self:getTileType()
		if ((isVisible) or (not self.getCurrentCapturePoint) or (tileType == "Headquarters")) then
			self.m_View:setViewObjectWithTiledId(self.m_ObjectID)
				:setViewBaseWithTiledId(self.m_BaseID)
				:setFogEnabled(not isVisible)
		else
			self.m_View:setViewObjectWithTiledId(getTiledIdWithTileOrUnitName(tileType, 0))
				:setViewBaseWithTiledId(self.m_BaseID)
				:setFogEnabled(true)
		end
	end

	return self
end

function ModelTileForNative:getPositionIndex()
	return self.m_PositionIndex
end

function ModelTileForNative:getTiledId()
	return (self.m_ObjectID > 0) and (self.m_ObjectID) or (self.m_BaseID)
end

function ModelTileForNative:getObjectAndBaseId()
	return self.m_ObjectID, self.m_BaseID
end

function ModelTileForNative:getPlayerIndex()
	return GameConstantFunctions.getPlayerIndexWithTiledId(self:getTiledId())
end

function ModelTileForNative:getTileType()
	return GameConstantFunctions.getTileTypeWithObjectAndBaseId(self:getObjectAndBaseId())
end

function ModelTileForNative:getTeamIndex()
	local playerIndex = self:getPlayerIndex()
	if (playerIndex == 0) then
		return nil
	else
		return SingletonGetters.getModelPlayerManager(self.m_ModelWar):getModelPlayer(playerIndex):getTeamIndex()
	end
end

function ModelTileForNative:getTileTypeFullName()
	return LocalizationFunctions.getLocalizedText(116, self:getTileType())
end

function ModelTileForNative:getDescription()
	return LocalizationFunctions.getLocalizedText(117, self:getTileType())
end

function ModelTileForNative:updateWithObjectAndBaseId(objectID, baseID)
	local gridIndex		  = self:getGridIndex()
	baseID				   = baseID or self.m_BaseID

	initWithTiledID(self, objectID, baseID)
	loadInstantialData(self, {GridIndexable = {x = gridIndex.x, y = gridIndex.y}})
	self:onStartRunning(self.m_ModelWar)

	return self
end

function ModelTileForNative:destroyModelTileObject()
	assert(self.m_ObjectID > 0, "ModelTileForNative:destroyModelTileObject() there's no tile object.")
	self:updateWithObjectAndBaseId(0, self.m_BaseID)

	return self
end

function ModelTileForNative:destroyViewTileObject()
	if (self.m_View) then
		self.m_View:setViewObjectWithTiledId(0)
	end
end

function ModelTileForNative:updateWithPlayerIndex(playerIndex)
	assert(self:getPlayerIndex() ~= playerIndex, "ModelTileForNative:updateWithPlayerIndex() the param playerIndex is the same as the one of self.")

	local tileName = self:getTileType()
	if (tileName ~= "Headquarters") then
		self.m_ObjectID = getTiledIdWithTileOrUnitName(tileName, playerIndex)
	else
		local gridIndex		   = self:getGridIndex()
		local currentCapturePoint = self:getCurrentCapturePoint()

		initWithTiledID(self, getTiledIdWithTileOrUnitName("City", playerIndex), self.m_BaseID)
		loadInstantialData(self, {
			GridIndexable = {x = gridIndex.x, y = gridIndex.y},
			Capturable	= {currentCapturePoint = currentCapturePoint},
		})
		self:onStartRunning(self.m_ModelWar)
	end

	return self
end

return ModelTileForNative
