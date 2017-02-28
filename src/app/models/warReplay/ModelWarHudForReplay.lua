
local ModelWarHudForReplay = class("ModelWarHudForReplay")

local Actor = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The composition actors.
--------------------------------------------------------------------------------
local function initActorMoneyEnergyInfo(self)
    self.m_ActorMoneyEnergyInfo = Actor.createWithModelAndViewName("common.ModelMoneyEnergyInfo", nil, "common.ViewMoneyEnergyInfo")
end

local function initActorReplayController(self)
    self.m_ActorReplayController = Actor.createWithModelAndViewName("warReplay.ModelReplayController", nil, "warReplay.ViewReplayController")
end

local function initActorTileDetail(self)
    self.m_ActorTileDetail = Actor.createWithModelAndViewName("common.ModelTileDetail", nil, "common.ViewTileDetail")
end

local function initActorTileInfo(self)
    local actor = Actor.createWithModelAndViewName("common.ModelTileInfo", nil, "common.ViewTileInfo")
    actor:getModel():setModelTileDetail(self.m_ActorTileDetail:getModel())

    self.m_ActorTileInfo = actor
end

local function initActorUnitDetail(self)
    self.m_ActorUnitDetail = Actor.createWithModelAndViewName("common.ModelUnitDetail", nil, "common.ViewUnitDetail")
end

local function initActorUnitInfo(self)
    local actor = Actor.createWithModelAndViewName("warReplay.ModelUnitInfoForReplay", nil, "common.ViewUnitInfo")
    actor:getModel():setModelUnitDetail(self.m_ActorUnitDetail:getModel())

    self.m_ActorUnitInfo = actor
end

local function initActorWarCommandMenu(self)
    self.m_ActorWarCommandMenu = Actor.createWithModelAndViewName("warReplay.ModelWarCommandMenuForReplay", nil, "common.ViewWarCommandMenu")
end

--------------------------------------------------------------------------------
-- The contructor and initializers.
--------------------------------------------------------------------------------
function ModelWarHudForReplay:ctor()
    initActorMoneyEnergyInfo( self)
    initActorReplayController(self)
    initActorTileDetail(      self)
    initActorTileInfo(        self)
    initActorUnitDetail(      self)
    initActorUnitInfo(        self)
    initActorWarCommandMenu(  self)

    return self
end

function ModelWarHudForReplay:initView()
    local view = self.m_View
    assert(view, "ModelWarHudForReplay:initView() no view is attached to the actor of the model.")

    view:setViewMoneyEnergyInfo( self.m_ActorMoneyEnergyInfo :getView())
        :setViewReplayController(self.m_ActorReplayController:getView())
        :setViewTileDetail(      self.m_ActorTileDetail      :getView())
        :setViewTileInfo(        self.m_ActorTileInfo        :getView())
        :setViewUnitDetail(      self.m_ActorUnitDetail      :getView())
        :setViewUnitInfo(        self.m_ActorUnitInfo        :getView())
        :setViewWarCommandMenu(  self.m_ActorWarCommandMenu  :getView())

    return self
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function ModelWarHudForReplay:onStartRunning(modelWarReplay)
    self.m_ActorMoneyEnergyInfo :getModel():onStartRunning(modelWarReplay)
    self.m_ActorReplayController:getModel():onStartRunning(modelWarReplay)
    self.m_ActorTileInfo        :getModel():onStartRunning(modelWarReplay)
    self.m_ActorUnitInfo        :getModel():onStartRunning(modelWarReplay)
    self.m_ActorWarCommandMenu  :getModel():onStartRunning(modelWarReplay)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarHudForReplay:getModelReplayController()
    return self.m_ActorReplayController:getModel()
end

function ModelWarHudForReplay:getModelWarCommandMenu()
    return self.m_ActorWarCommandMenu:getModel()
end

return ModelWarHudForReplay
