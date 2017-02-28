
local ModelWarFieldForReplay = requireFW("src.global.functions.class")("ModelWarFieldForReplay")

local SingletonGetters = requireFW("src.app.utilities.SingletonGetters")
local Actor            = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtDragField(self, event)
    self.m_View:setPositionOnDrag(event.previousPosition, event.currentPosition)
end

local function onEvtZoomFieldWithScroll(self, event)
    local scrollEvent = event.scrollEvent
    self.m_View:setZoomWithScroll(cc.Director:getInstance():convertToGL(scrollEvent:getLocation()), scrollEvent:getScrollY())
end

local function onEvtZoomFieldWithTouches(self, event)
    self.m_View:setZoomWithTouches(event.touches)
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initActorActionPlanner(self)
    if (not self.m_ActorActionPlanner) then
        self.m_ActorActionPlanner = Actor.createWithModelAndViewName("warReplay.ModelActionPlannerForReplay", nil, "common.ViewActionPlanner")
    end
end

local function initActorFogMap(self, fogMapData)
    if (not self.m_ActorFogMap) then
        local modelFogMap = Actor.createModel("common.ModelFogMap", fogMapData, self.m_WarFieldFileName)
        self.m_ActorFogMap = Actor.createWithModelAndViewInstance(modelFogMap, Actor.createView("warReplay.ViewFogMapForReplay"))
    else
        self.m_ActorFogMap:getModel():ctor(fogMapData, self.m_WarFieldFileName)
    end
end

local function initActorGridEffect(self)
    if (not self.m_ActorGridEffect) then
        self.m_ActorGridEffect = Actor.createWithModelAndViewName("common.ModelGridEffect", nil, "common.ViewGridEffect")
    end
end

local function initActorMapCursor(self)
    if (not self.m_ActorMapCursor) then
        self.m_ActorMapCursor = Actor.createWithModelAndViewName("common.ModelMapCursor", nil, "common.ViewMapCursor")
    end
end

local function initActorTileMap(self, tileMapData)
    if (not self.m_ActorTileMap) then
        local modelTileMap  = Actor.createModel("warReplay.ModelTileMapForReplay", tileMapData, self.m_WarFieldFileName)
        self.m_ActorTileMap = Actor.createWithModelAndViewInstance(modelTileMap, Actor.createView("common.ViewTileMap"))
    else
        self.m_ActorTileMap:getModel():ctor(tileMapData, self.m_WarFieldFileName)
    end
end

local function initActorUnitMap(self, unitMapData)
    if (not self.m_ActorUnitMap) then
        local modelUnitMap  = Actor.createModel("warReplay.ModelUnitMapForReplay", unitMapData, self.m_WarFieldFileName)
        self.m_ActorUnitMap = Actor.createWithModelAndViewInstance(modelUnitMap, Actor.createView("common.ViewUnitMap"))
    else
        self.m_ActorUnitMap:getModel():ctor(unitMapData, self.m_WarFieldFileName)
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarFieldForReplay:ctor(warFieldData)
    self.m_WarFieldFileName = warFieldData.warFieldFileName

    initActorActionPlanner(self)
    initActorFogMap(       self, warFieldData.fogMap)
    initActorGridEffect(   self)
    initActorMapCursor(    self)
    initActorTileMap(      self, warFieldData.tileMap)
    initActorUnitMap(      self, warFieldData.unitMap)

    return self
end

function ModelWarFieldForReplay:initView()
    assert(self.m_View, "ModelWarFieldForReplay:initView() no view is attached to the owner actor of the model.")
    self.m_View:setViewActionPlanner(self.m_ActorActionPlanner:getView())
        :setViewFogMap(    self.m_ActorFogMap                 :getView())
        :setViewTileMap(   self.m_ActorTileMap                :getView())
        :setViewUnitMap(   self.m_ActorUnitMap                :getView())
        :setViewMapCursor( self.m_ActorMapCursor              :getView())
        :setViewGridEffect(self.m_ActorGridEffect             :getView())

        :setContentSizeWithMapSize(self:getModelTileMap():getMapSize())

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarFieldForReplay:toSerializableTable()
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
function ModelWarFieldForReplay:onStartRunning(modelWarReplay)
    self:getModelTileMap()      :onStartRunning(modelWarReplay)
    self:getModelUnitMap()      :onStartRunning(modelWarReplay)
    self:getModelFogMap()       :onStartRunning(modelWarReplay)
    self:getModelActionPlanner():onStartRunning(modelWarReplay)
    self:getModelGridEffect()   :onStartRunning(modelWarReplay)
    self:getModelMapCursor()    :onStartRunning(modelWarReplay)

    SingletonGetters.getScriptEventDispatcher(modelWarReplay)
        :addEventListener("EvtDragField",            self)
        :addEventListener("EvtZoomFieldWithScroll",  self)
        :addEventListener("EvtZoomFieldWithTouches", self)

    return self
end

function ModelWarFieldForReplay:onEvent(event)
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
function ModelWarFieldForReplay:getWarFieldFileName()
    return self.m_WarFieldFileName
end

function ModelWarFieldForReplay:getModelActionPlanner()
    return self.m_ActorActionPlanner:getModel()
end

function ModelWarFieldForReplay:getModelFogMap()
    return self.m_ActorFogMap:getModel()
end

function ModelWarFieldForReplay:getModelUnitMap()
    return self.m_ActorUnitMap:getModel()
end

function ModelWarFieldForReplay:getModelTileMap()
    return self.m_ActorTileMap:getModel()
end

function ModelWarFieldForReplay:getModelMapCursor()
    return self.m_ActorMapCursor:getModel()
end

function ModelWarFieldForReplay:getModelGridEffect()
    return self.m_ActorGridEffect:getModel()
end

return ModelWarFieldForReplay
