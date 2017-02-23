
local ModelMoneyEnergyInfo = class("ModelMoneyEnergyInfo")

local SingletonGetters = requireFW("src.app.utilities.SingletonGetters")

local string = string

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generateInfoText(self)
    local modelWarReplay = self.m_ModelWarReplay
    local modelPlayer    = SingletonGetters.getModelPlayerManager(modelWarReplay):getModelPlayer(self.m_PlayerIndex)
    return string.format("%s: %s\n%s: %s\n%s: %d",
        getLocalizedText(25, "Player"),  modelPlayer:getNickname(),
        getLocalizedText(25, "Fund"),    modelPlayer:getFund(),
        getLocalizedText(25, "Energy"),  modelPlayer:getEnergy()
    ))
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtChatManagerUpdated(self, event)
    local menu = self.m_ModelWarCommandMenu
    self.m_View:setVisible((not menu:isEnabled()) and (not menu:isHiddenWithHideUI()))
end

local function onEvtPlayerIndexUpdated(self, event)
    local playerIndex = event.playerIndex
    self.m_PlayerIndex = playerIndex

    self.m_View:setInfoText(generateInfoText(self))
        :updateWithPlayerIndex(playerIndex)
end

local function onEvtModelPlayerUpdated(self, event)
    if ((self.m_PlayerIndex == event.playerIndex) and (self.m_View)) then
        self.m_View:setInfoText(generateInfoText(self))
    end
end

local function onEvtWarCommandMenuUpdated(self, event)
    local menu = self.m_ModelWarCommandMenu
    self.m_View:setVisible((not menu:isEnabled()) and (not menu:isHiddenWithHideUI()))
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelMoneyEnergyInfo:ctor(param)
    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelMoneyEnergyInfo:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay      = modelWarReplay
    self.m_ModelWarCommandMenu = SingletonGetters.getModelWarCommandMenu(modelWarReplay)

    SingletonGetters.getScriptEventDispatcher(modelWarReplay)
        :addEventListener("EvtChatManagerUpdated",    self)
        :addEventListener("EvtModelPlayerUpdated",    self)
        :addEventListener("EvtPlayerIndexUpdated",    self)
        :addEventListener("EvtWarCommandMenuUpdated", self)

    local playerIndex  = SingletonGetters.getModelTurnManager(modelWarReplay):getPlayerIndex()
    self.m_PlayerIndex = playerIndex

    self.m_View:setInfoText(generateInfoText(self))
        :updateWithPlayerIndex(playerIndex)

    return self
end

function ModelMoneyEnergyInfo:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtChatManagerUpdated")    then onEvtChatManagerUpdated(   self, event)
    elseif (eventName == "EvtModelPlayerUpdated")    then onEvtModelPlayerUpdated(   self, event)
    elseif (eventName == "EvtPlayerIndexUpdated")    then onEvtPlayerIndexUpdated(   self, event)
    elseif (eventName == "EvtWarCommandMenuUpdated") then onEvtWarCommandMenuUpdated(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelMoneyEnergyInfo:onPlayerTouch()
    local modelWarReplay = self.m_ModelWarReplay
    if (modelWarReplay:isAutoReplay()) then
        modelWarReplay:setAutoReplay(false)
        SingletonGetters.getModelReplayController(modelWarReplay):setButtonPlayVisible(true)
    end
    SingletonGetters.getModelWarCommandMenu(modelWarReplay):setEnabled(true)

    return self
end

function ModelMoneyEnergyInfo:adjustPositionOnTouch(touch)
    if (self.m_View) then
        self.m_View:adjustPositionOnTouch(touch)
    end

    return self
end

return ModelMoneyEnergyInfo
