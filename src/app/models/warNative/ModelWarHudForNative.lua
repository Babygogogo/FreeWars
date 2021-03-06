
local ModelWarHudForNative = class("ModelWarHudForNative")

local Actor = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The composition actors.
--------------------------------------------------------------------------------
local function initActorWarCommandMenu(self)
    self.m_ActorWarCommandMenu = Actor.createWithModelAndViewName("warNative.ModelWarCommandMenuForNative", nil, "common.ViewWarCommandMenu")
end

local function initActorMoneyEnergyInfo(self)
    self.m_ActorMoneyEnergyInfo = Actor.createWithModelAndViewName("common.ModelMoneyEnergyInfo", nil, "common.ViewMoneyEnergyInfo")
end

local function initActorActionMenu(self)
    self.m_ActorActionMenu = Actor.createWithModelAndViewName("warOnline.ModelActionMenu", nil, "warOnline.ViewActionMenu")
end

local function initActorUnitDetail(self)
    self.m_ActorUnitDetail = Actor.createWithModelAndViewName("common.ModelUnitDetail", nil, "common.ViewUnitDetail")
end

local function initActorUnitInfo(self)
    local actor = Actor.createWithModelAndViewName("common.ModelUnitInfo", nil, "common.ViewUnitInfo")
    actor:getModel():setModelUnitDetail(self.m_ActorUnitDetail:getModel())

    self.m_ActorUnitInfo = actor
end

local function initActorTileDetail(self)
    self.m_ActorTileDetail = Actor.createWithModelAndViewName("common.ModelTileDetail", nil, "common.ViewTileDetail")
end

local function initActorTileInfo(self)
    local actor = Actor.createWithModelAndViewName("common.ModelTileInfo", nil, "common.ViewTileInfo")
    actor:getModel():setModelTileDetail(self.m_ActorTileDetail:getModel())

    self.m_ActorTileInfo = actor
end

local function initActorBattleInfo(self)
    self.m_ActorBattleInfo = Actor.createWithModelAndViewName("warOnline.ModelBattleInfo", nil, "warOnline.ViewBattleInfo")
end

--------------------------------------------------------------------------------
-- The contructor and initializers.
--------------------------------------------------------------------------------
function ModelWarHudForNative:ctor()
    initActorWarCommandMenu( self)
    initActorMoneyEnergyInfo(self)
    initActorActionMenu(     self)
    initActorUnitDetail(     self)
    initActorUnitInfo(       self)
    initActorTileDetail(     self)
    initActorTileInfo(       self)
    initActorBattleInfo(     self)

    return self
end

function ModelWarHudForNative:initView()
    local view = self.m_View
    assert(view, "ModelWarHudForNative:initView() no view is attached to the actor of the model.")

    view:setViewActionMenu(     self.m_ActorActionMenu:     getView())
        :setViewBattleInfo(     self.m_ActorBattleInfo:     getView())
        :setViewMoneyEnergyInfo(self.m_ActorMoneyEnergyInfo:getView())
        :setViewTileDetail(     self.m_ActorTileDetail:     getView())
        :setViewTileInfo(       self.m_ActorTileInfo:       getView())
        :setViewUnitDetail(     self.m_ActorUnitDetail:     getView())
        :setViewUnitInfo(       self.m_ActorUnitInfo:       getView())
        :setViewWarCommandMenu( self.m_ActorWarCommandMenu: getView())

    return self
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function ModelWarHudForNative:onStartRunning(modelWar)
    self.m_ActorActionMenu     :getModel():onStartRunning(modelWar)
    self.m_ActorBattleInfo     :getModel():onStartRunning(modelWar)
    self.m_ActorMoneyEnergyInfo:getModel():onStartRunning(modelWar)
    self.m_ActorTileInfo       :getModel():onStartRunning(modelWar)
    self.m_ActorUnitInfo       :getModel():onStartRunning(modelWar)
    self.m_ActorWarCommandMenu :getModel():onStartRunning(modelWar)
    self.m_ActorTileDetail     :getModel():onStartRunning(modelWar)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarHudForNative:getModelWarCommandMenu()
    return self.m_ActorWarCommandMenu:getModel()
end

return ModelWarHudForNative
