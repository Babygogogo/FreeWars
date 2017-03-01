
--[[--------------------------------------------------------------------------------
-- ModelWarFieldForOnline是战局场景中除了UI元素以外的其他元素的集合。
--
-- 主要职责和使用场景举例：
--   ModelWarFieldForOnline自身功能不多，更多的是扮演了各个子actor的容器的角色。
--
-- 其他：
--   - ModelWarFieldForOnline目前包括以下子actor：
--     - TileMap
--     - UnitMap
--     - MapCursor（server不含）
--     - ActionPlanner（server不含）
--     - GridEffect（server不含）
--]]--------------------------------------------------------------------------------

local ModelWarFieldForOnline = requireFW("src.global.functions.class")("ModelWarFieldForOnline")

local SingletonGetters = requireFW("src.app.utilities.SingletonGetters")
local Actor            = requireFW("src.global.actors.Actor")

local IS_SERVER = requireFW("src.app.utilities.GameConstantFunctions").isServer()

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
    local modelTileMap  = Actor.createModel("warOnline.ModelTileMapForOnline", tileMapData, self.m_WarFieldFileName)
    self.m_ActorTileMap = (IS_SERVER)                                                                  and
        (Actor.createWithModelAndViewInstance(modelTileMap))                                           or
        (Actor.createWithModelAndViewInstance(modelTileMap, Actor.createView("common.ViewTileMap")))
end

local function initActorUnitMap(self, unitMapData)
    local modelUnitMap  = Actor.createModel("warOnline.ModelUnitMapForOnline", unitMapData, self.m_WarFieldFileName)
    self.m_ActorUnitMap = (IS_SERVER)                                                                  and
        (Actor.createWithModelAndViewInstance(modelUnitMap))                                           or
        (Actor.createWithModelAndViewInstance(modelUnitMap, Actor.createView("common.ViewUnitMap")))
end

local function initActorActionPlanner(self)
    self.m_ActorActionPlanner = Actor.createWithModelAndViewName("warOnline.ModelActionPlannerForOnline", nil, "common.ViewActionPlanner")
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
function ModelWarFieldForOnline:ctor(warFieldData)
    self.m_WarFieldFileName = warFieldData.warFieldFileName
    initActorFogMap( self, warFieldData.fogMap)
    initActorTileMap(self, warFieldData.tileMap)
    initActorUnitMap(self, warFieldData.unitMap)

    if (not IS_SERVER) then
        initActorActionPlanner(self)
        initActorMapCursor(    self, {mapSize = self:getModelTileMap():getMapSize()})
        initActorGridEffect(   self)
    end

    return self
end

function ModelWarFieldForOnline:initView()
    assert(self.m_View, "ModelWarFieldForOnline:initView() no view is attached to the owner actor of the model.")
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
function ModelWarFieldForOnline:toSerializableTable()
    return {
        warFieldFileName = self.m_WarFieldFileName,
        fogMap           = self:getModelFogMap() :toSerializableTable(),
        tileMap          = self:getModelTileMap():toSerializableTable(),
        unitMap          = self:getModelUnitMap():toSerializableTable(),
    }
end

function ModelWarFieldForOnline:toSerializableTableForPlayerIndex(playerIndex)
    return {
        warFieldFileName = self.m_WarFieldFileName,
        fogMap           = self:getModelFogMap() :toSerializableTableForPlayerIndex(playerIndex),
        tileMap          = self:getModelTileMap():toSerializableTableForPlayerIndex(playerIndex),
        unitMap          = self:getModelUnitMap():toSerializableTableForPlayerIndex(playerIndex),
    }
end

function ModelWarFieldForOnline:toSerializableReplayData()
    return {warFieldFileName = self.m_WarFieldFileName}
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelWarFieldForOnline:onStartRunning(modelSceneWar)
    self:getModelTileMap():onStartRunning(modelSceneWar)
    self:getModelUnitMap():onStartRunning(modelSceneWar)
    self:getModelFogMap() :onStartRunning(modelSceneWar)

    if (not IS_SERVER) then
        self.m_ActorActionPlanner:getModel():onStartRunning(modelSceneWar)
        self.m_ActorGridEffect   :getModel():onStartRunning(modelSceneWar)
        self.m_ActorMapCursor    :getModel():onStartRunning(modelSceneWar)

        self:getModelTileMap():updateOnModelFogMapStartedRunning()
    end

    SingletonGetters.getScriptEventDispatcher(modelSceneWar)
        :addEventListener("EvtDragField",            self)
        :addEventListener("EvtZoomFieldWithScroll",  self)
        :addEventListener("EvtZoomFieldWithTouches", self)

    return self
end

function ModelWarFieldForOnline:onEvent(event)
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
function ModelWarFieldForOnline:getWarFieldFileName()
    return self.m_WarFieldFileName
end

function ModelWarFieldForOnline:getModelActionPlanner()
    return self.m_ActorActionPlanner:getModel()
end

function ModelWarFieldForOnline:getModelFogMap()
    return self.m_ActorFogMap:getModel()
end

function ModelWarFieldForOnline:getModelUnitMap()
    return self.m_ActorUnitMap:getModel()
end

function ModelWarFieldForOnline:getModelTileMap()
    return self.m_ActorTileMap:getModel()
end

function ModelWarFieldForOnline:getModelMapCursor()
    return self.m_ActorMapCursor:getModel()
end

function ModelWarFieldForOnline:getModelGridEffect()
    return self.m_ActorGridEffect:getModel()
end

return ModelWarFieldForOnline
