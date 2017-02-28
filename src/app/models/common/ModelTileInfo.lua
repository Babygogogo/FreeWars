
--[[--------------------------------------------------------------------------------
-- ModelTileInfo是战局场景里的tile的简要属性框（即场景下方的小框）。
--
-- 主要职责和使用场景举例：
--   - 构造和显示tile的简要属性框。
--   - 自身被点击时，呼出tile的详细属性页面。
--
-- 其他：
--  - 本类所显示的是光标所指向的tile的信息（通过event获知光标指向的是哪个tile）
--]]--------------------------------------------------------------------------------

local ModelTileInfo = class("ModelTileInfo")

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters   = requireFW("src.app.utilities.SingletonGetters")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function updateWithModelTileMap(self)
    if ((self.m_ModelWarCommandMenu:isEnabled())                               or
        (self.m_ModelWarCommandMenu:isHiddenWithHideUI())                      or
        ((self.m_ModelChatManager) and (self.m_ModelChatManager:isEnabled()))) then
        self.m_View:setVisible(false)
    else
        self.m_View:updateWithModelTile(self.m_ModelTileMap:getModelTile(self.m_CursorGridIndex))
            :setVisible(true)
    end
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtChatManagerUpdated(self, event)
    updateWithModelTileMap(self)
end

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
function ModelTileInfo:ctor(param)
    self.m_CursorGridIndex = {x = 1, y = 1}

    return self
end

function ModelTileInfo:setModelTileDetail(model)
    assert(self.m_ModelTileDetail == nil, "ModelTileInfo:setModelTileDetail() the model has been set.")
    self.m_ModelTileDetail = model

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelTileInfo:onStartRunning(modelWar)
    self.m_ModelTileMap        = SingletonGetters.getModelTileMap(       modelWar)
    self.m_ModelWarCommandMenu = SingletonGetters.getModelWarCommandMenu(modelWar)
    if (not SingletonGetters.isWarReplay(modelWar)) then
        self.m_ModelChatManager = SingletonGetters.getModelChatManager(modelWar)
    end

    SingletonGetters.getScriptEventDispatcher(modelWar)
        :addEventListener("EvtChatManagerUpdated",    self)
        :addEventListener("EvtGridSelected",          self)
        :addEventListener("EvtMapCursorMoved",        self)
        :addEventListener("EvtModelTileMapUpdated",   self)
        :addEventListener("EvtPlayerIndexUpdated",    self)
        :addEventListener("EvtWarCommandMenuUpdated", self)

    updateWithModelTileMap(self)
    self.m_View:updateWithPlayerIndex(SingletonGetters.getModelTurnManager(modelWar):getPlayerIndex())

    return self
end

function ModelTileInfo:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtChatManagerUpdated")    then onEvtChatManagerUpdated(   self, event)
    elseif (eventName == "EvtGridSelected")          then onEvtGridSelected(         self, event)
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
function ModelTileInfo:onPlayerTouch()
    if (self.m_ModelTileDetail) then
        self.m_ModelTileDetail:updateWithModelTile(self.m_ModelTileMap:getModelTile(self.m_CursorGridIndex))
            :setEnabled(true)
    end

    return self
end

return ModelTileInfo
