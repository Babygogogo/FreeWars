
local ModelTileInfoForReplay = class("ModelTileInfoForReplay")

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters   = requireFW("src.app.utilities.SingletonGetters")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function updateWithModelTileMap(self)
    local menu = self.m_ModelWarCommandMenu
    if ((menu:isEnabled()) or (menu:isHiddenWithHideUI())) then
        self.m_View:setVisible(false)
    else
        local modelTile = SingletonGetters.getModelTileMap(self.m_ModelSceneWar):getModelTile(self.m_CursorGridIndex)
        self.m_View:updateWithModelTile(modelTile)
            :setVisible(true)
    end
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtModelTileMapUpdated(self, event)
    updateWithModelTileMap(self)
end

local function onEvtMapCursorMoved(self, event)
    self.m_CursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    updateWithModelTileMap(self)
end

local function onEvtGridSelected(self, event)
    self.m_CursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    updateWithModelTileMap(self)
end

local function onEvtWarCommandMenuUpdated(self, event)
    updateWithModelTileMap(self)
end

local function onEvtPlayerIndexUpdated(self, event)
    self.m_View:updateWithPlayerIndex(event.playerIndex)
end

--------------------------------------------------------------------------------
-- The contructor and initializers.
--------------------------------------------------------------------------------
function ModelTileInfoForReplay:ctor(param)
    self.m_CursorGridIndex = {x = 1, y = 1}

    return self
end

function ModelTileInfoForReplay:setModelTileDetail(model)
    assert(self.m_ModelTileDetail == nil, "ModelTileInfoForReplay:setModelTileDetail() the model has been set.")
    self.m_ModelTileDetail = model

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelTileInfoForReplay:onStartRunning(modelSceneWar)
    self.m_ModelSceneWar       = modelSceneWar
    self.m_ModelWarCommandMenu = SingletonGetters.getModelWarCommandMenu(modelSceneWar)

    SingletonGetters.getScriptEventDispatcher(modelSceneWar)
        :addEventListener("EvtGridSelected",          self)
        :addEventListener("EvtMapCursorMoved",        self)
        :addEventListener("EvtModelTileMapUpdated",   self)
        :addEventListener("EvtPlayerIndexUpdated",    self)
        :addEventListener("EvtWarCommandMenuUpdated", self)

    if (self.m_View) then
        self.m_View:updateWithPlayerIndex(SingletonGetters.getModelTurnManager(modelSceneWar):getPlayerIndex())
    end

    updateWithModelTileMap(self)

    return self
end

function ModelTileInfoForReplay:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtGridSelected")          then onEvtGridSelected(         self, event)
    elseif (eventName == "EvtMapCursorMoved")        then onEvtMapCursorMoved(       self, event)
    elseif (eventName == "EvtModelTileMapUpdated")   then onEvtModelTileMapUpdated(  self, event)
    elseif (eventName == "EvtPlayerIndexUpdated")    then onEvtPlayerIndexUpdated(   self, event)
    elseif (eventName == "EvtWarCommandMenuUpdated") then onEvtWarCommandMenuUpdated(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTileInfoForReplay:onPlayerTouch()
    if (self.m_ModelTileDetail) then
        local modelTile = SingletonGetters.getModelTileMap(self.m_ModelSceneWar):getModelTile(self.m_CursorGridIndex)
        self.m_ModelTileDetail:updateWithModelTile(modelTile)
            :setEnabled(true)
    end

    return self
end

return ModelTileInfoForReplay
