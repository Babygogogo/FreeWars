
local ModelWarFieldForNative = requireFW("src.global.functions.class")("ModelWarFieldForNative")

local SingletonGetters    = requireFW("src.app.utilities.SingletonGetters")
local VisibilityFunctions = requireFW("src.app.utilities.VisibilityFunctions")
local Actor               = requireFW("src.global.actors.Actor")

local isUnitVisible = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtDragField(self, event)
    if (self.m_View) then
        self.m_View:setPositionOnDrag(event.previousPosition, event.currentPosition)
    end
end

local function onEvtZoomFieldWithScroll(self, event)
    if (self.m_View) then
        local scrollEvent = event.scrollEvent
        self.m_View:setZoomWithScroll(cc.Director:getInstance():convertToGL(scrollEvent:getLocation()), scrollEvent:getScrollY())
    end
end

local function onEvtZoomFieldWithTouches(self, event)
    if (self.m_View) then
        self.m_View:setZoomWithTouches(event.touches)
    end
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initActorFogMap(self, fogMapData)
    self.m_ActorFogMap = Actor.createWithModelAndViewInstance(Actor.createModel("common.ModelFogMap", fogMapData, self.m_WarFieldFileName))
end

local function initActorTileMap(self, tileMapData)
    local modelTileMap  = Actor.createModel("warNative.ModelTileMapForNative", tileMapData, self.m_WarFieldFileName)
    self.m_ActorTileMap = Actor.createWithModelAndViewInstance(modelTileMap, Actor.createView("common.ViewTileMap"))
end

local function initActorUnitMap(self, unitMapData)
    local modelUnitMap  = Actor.createModel("warOnline.ModelUnitMapForOnline", unitMapData, self.m_WarFieldFileName)
    self.m_ActorUnitMap = Actor.createWithModelAndViewInstance(modelUnitMap, Actor.createView("common.ViewUnitMap"))
end

local function initActorActionPlanner(self)
    self.m_ActorActionPlanner = Actor.createWithModelAndViewName("warNative.ModelActionPlannerForNative", nil, "common.ViewActionPlanner")
end

local function initActorMapCursor(self, param)
    self.m_ActorMapCursor = Actor.createWithModelAndViewName("common.ModelMapCursor", param, "common.ViewMapCursor")
end

local function initActorGridEffect(self)
    self.m_ActorGridEffect = Actor.createWithModelAndViewName("common.ModelGridEffect", nil, "common.ViewGridEffect")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarFieldForNative:ctor(warFieldData)
    self.m_WarFieldFileName = warFieldData.warFieldFileName
    initActorFogMap(       self, warFieldData.fogMap)
    initActorTileMap(      self, warFieldData.tileMap)
    initActorUnitMap(      self, warFieldData.unitMap)
    initActorActionPlanner(self)
    initActorGridEffect(   self)
    initActorMapCursor(    self)

    return self
end

function ModelWarFieldForNative:initView()
    assert(self.m_View, "ModelWarFieldForNative:initView() no view is attached to the owner actor of the model.")
    self.m_View:setViewTileMap(self.m_ActorTileMap      :getView())
        :setViewUnitMap(       self.m_ActorUnitMap      :getView())
        :setViewActionPlanner( self.m_ActorActionPlanner:getView())
        :setViewMapCursor(     self.m_ActorMapCursor    :getView())
        :setViewGridEffect(    self.m_ActorGridEffect   :getView())

        :setContentSizeWithMapSize(self:getModelTileMap():getMapSize())

    local viewFogMap = self.m_ActorFogMap:getView()
    if (viewFogMap) then
        self.m_View:setViewFogMap(viewFogMap)
    end

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarFieldForNative:toSerializableTable()
    return {
        warFieldFileName = self.m_WarFieldFileName,
        fogMap           = self:getModelFogMap() :toSerializableTable(),
        tileMap          = self:getModelTileMap():toSerializableTable(),
        unitMap          = self:getModelUnitMap():toSerializableTable(),
    }
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelWarFieldForNative:onStartRunning(modelWar)
    self:getModelTileMap()      :onStartRunning(modelWar)
    self:getModelUnitMap()      :onStartRunning(modelWar)
    self:getModelFogMap()       :onStartRunning(modelWar)
    self:getModelActionPlanner():onStartRunning(modelWar)
    self:getModelGridEffect()   :onStartRunning(modelWar)
    self:getModelMapCursor()    :onStartRunning(modelWar)

    self:getModelTileMap():updateOnModelFogMapStartedRunning()
    local playerIndex = SingletonGetters.getModelPlayerManager(modelWar):getPlayerIndexForHuman()
    self:getModelUnitMap():forEachModelUnitOnMap(function(modelUnit)
        modelUnit:setViewVisible(isUnitVisible(modelWar, modelUnit:getGridIndex(), modelUnit:getUnitType(), (modelUnit.isDiving) and (modelUnit:isDiving()), modelUnit:getPlayerIndex(), playerIndex))
    end)

    SingletonGetters.getScriptEventDispatcher(modelWar)
        :addEventListener("EvtDragField",            self)
        :addEventListener("EvtZoomFieldWithScroll",  self)
        :addEventListener("EvtZoomFieldWithTouches", self)

    return self
end

function ModelWarFieldForNative:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtDragField")            then onEvtDragField(           self, event)
    elseif (eventName == "EvtZoomFieldWithScroll")  then onEvtZoomFieldWithScroll( self, event)
    elseif (eventName == "EvtZoomFieldWithTouches") then onEvtZoomFieldWithTouches(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarFieldForNative:getWarFieldFileName()
    return self.m_WarFieldFileName
end

function ModelWarFieldForNative:getModelActionPlanner()
    return self.m_ActorActionPlanner:getModel()
end

function ModelWarFieldForNative:getModelFogMap()
    return self.m_ActorFogMap:getModel()
end

function ModelWarFieldForNative:getModelUnitMap()
    return self.m_ActorUnitMap:getModel()
end

function ModelWarFieldForNative:getModelTileMap()
    return self.m_ActorTileMap:getModel()
end

function ModelWarFieldForNative:getModelMapCursor()
    return self.m_ActorMapCursor:getModel()
end

function ModelWarFieldForNative:getModelGridEffect()
    return self.m_ActorGridEffect:getModel()
end

return ModelWarFieldForNative
