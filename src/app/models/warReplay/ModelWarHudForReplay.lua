
local ModelWarHudForReplay = class("ModelWarHudForReplay")

local Actor = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The composition actors.
--------------------------------------------------------------------------------
local function initActorWarCommandMenu(self)
    self.m_ActorWarCommandMenu = Actor.createWithModelAndViewName("sceneWar.ModelWarCommandMenu", nil, "sceneWar.ViewWarCommandMenu")
end

local function initActorMoneyEnergyInfo(self)
    self.m_ActorMoneyEnergyInfo = Actor.createWithModelAndViewName("sceneWar.ModelMoneyEnergyInfo", nil, "sceneWar.ViewMoneyEnergyInfo")
end

local function initActorActionMenu(self)
    self.m_ActorActionMenu = Actor.createWithModelAndViewName("sceneWar.ModelActionMenu", nil, "sceneWar.ViewActionMenu")
end

local function initActorUnitDetail(self)
    self.m_ActorUnitDetail = Actor.createWithModelAndViewName("sceneWar.ModelUnitDetail", nil, "sceneWar.ViewUnitDetail")
end

local function initActorUnitInfo(self)
    local actor = Actor.createWithModelAndViewName("sceneWar.ModelUnitInfo", nil, "sceneWar.ViewUnitInfo")
    actor:getModel():setModelUnitDetail(self.m_ActorUnitDetail:getModel())

    self.m_ActorUnitInfo = actor
end

local function initActorTileDetail(self)
    self.m_ActorTileDetail = Actor.createWithModelAndViewName("sceneWar.ModelTileDetail", nil, "sceneWar.ViewTileDetail")
end

local function initActorTileInfo(self)
    local actor = Actor.createWithModelAndViewName("sceneWar.ModelTileInfo", nil, "sceneWar.ViewTileInfo")
    actor:getModel():setModelTileDetail(self.m_ActorTileDetail:getModel())

    self.m_ActorTileInfo = actor
end

local function initActorBattleInfo(self)
    self.m_ActorBattleInfo = Actor.createWithModelAndViewName("sceneWar.ModelBattleInfo", nil, "sceneWar.ViewBattleInfo")
end

local function initActorReplayController(self)
    self.m_ActorReplayController = Actor.createWithModelAndViewName("sceneWar.ModelReplayController", nil, "sceneWar.ViewReplayController")
end

--------------------------------------------------------------------------------
-- The contructor and initializers.
--------------------------------------------------------------------------------
function ModelWarHudForReplay:ctor()
    initActorActionMenu(      self)
    initActorBattleInfo(      self)
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

    view:setViewActionMenu(      self.m_ActorActionMenu      :getView())
        :setViewBattleInfo(      self.m_ActorBattleInfo      :getView())
        :setViewMoneyEnergyInfo( self.m_ActorMoneyEnergyInfo :getView())
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
    self.m_ActorActionMenu      :getModel():onStartRunning(modelWarReplay)
    self.m_ActorBattleInfo      :getModel():onStartRunning(modelWarReplay)
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
