
local ModelMainMenu = class("ModelMainMenu")

local AudioManager          = requireFW("src.app.utilities.AudioManager")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")
local Actor                 = requireFW("src.global.actors.Actor")

local getLocalizedText = LocalizationFunctions.getLocalizedText

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function showMenuItems(self, ...)
    local view = self.m_View
    assert(view, "ModelMainMenu-showMenuItems() no view is attached to the owner actor of the model.")

    view:removeAllItems()
    for _, item in ipairs({...}) do
        view:createAndPushBackItem(item)
    end
end

--------------------------------------------------------------------------------
-- The composition actors.
--------------------------------------------------------------------------------
local function getActorContinueWarSelectorForNative(self)
    if (not self.m_ActorContinueWarSelectorForNative) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelContinueWarSelectorForNative", nil, "sceneMain.ViewContinueWarSelectorForNative")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorContinueWarSelectorForNative = actor
        self.m_View:setViewContinueWarSelectorForNative(actor:getView())
    end

    return self.m_ActorContinueWarSelectorForNative
end

local function getActorContinueWarSelector(self)
    if (not self.m_ActorContinueWarSelector) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelContinueWarSelector", nil, "sceneMain.ViewContinueWarSelector")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorContinueWarSelector = actor
        self.m_View:setViewContinueWarSelector(actor:getView())
    end

    return self.m_ActorContinueWarSelector
end

local function getActorExitWarSelector(self)
    if (not self.m_ActorExitWarSelector) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelExitWarSelector", nil, "sceneMain.ViewExitWarSelector")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorExitWarSelector = actor
        self.m_View:setViewExitWarSelector(actor:getView())
    end

    return self.m_ActorExitWarSelector
end

local function getActorJoinWarSelector(self)
    if (not self.m_ActorJoinWarSelector) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelJoinWarSelector", nil, "sceneMain.ViewJoinWarSelector")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorJoinWarSelector = actor
        self.m_View:setViewJoinWarSelector(actor:getView())
    end

    return self.m_ActorJoinWarSelector
end

local function getActorNewWarSelectorForNative(self)
    if (not self.m_ActorNewWarSelectorForNative) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelNewWarSelectorForNative", nil, "sceneMain.ViewNewWarSelectorForNative")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorNewWarSelectorForNative = actor
        self.m_View:setViewNewWarSelectorForNative(actor:getView())
    end

    return self.m_ActorNewWarSelectorForNative
end

local function getActorNewWarCreator(self)
    if (not self.m_ActorNewWarCreator) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelNewWarCreator", nil, "sceneMain.ViewNewWarCreator")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorNewWarCreator = actor
        self.m_View:setViewNewWarCreator(actor:getView())
    end

    return self.m_ActorNewWarCreator
end

local function getActorReplayManager(self)
    if (not self.m_ActorReplayManager) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelReplayManager", nil, "sceneMain.ViewReplayManager")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorReplayManager = actor
        self.m_View:setViewReplayManager(actor:getView())
    end

    return self.m_ActorReplayManager
end

local function getActorLoginPanel(self)
    if (not self.m_ActorLoginPanel) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelLoginPanel", nil, "sceneMain.ViewLoginPanel")
        actor:getModel():setModelMainMenu(self)
            :onStartRunning(self.m_ModelSceneMain)
            :setEnabled(false)

        self.m_ActorLoginPanel = actor
        self.m_View:setViewLoginPanel(actor:getView())
    end

    return self.m_ActorLoginPanel
end

local function getActorGameHelper(self)
    if (not self.m_ActorGameHelper) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelGameHelper", nil, "sceneMain.ViewGameHelper")
        actor:getModel():setModelSceneMain(self.m_ModelSceneMain)

        self.m_ActorGameHelper = actor
        self.m_View:setViewGameHelper(actor:getView())
    end

    return self.m_ActorGameHelper
end

local function getActorGameRecordViewer(self)
    if (not self.m_ActorGameRecordViewer) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelGameRecordViewer", nil, "sceneMain.ViewGameRecordViewer")
        actor:getModel():onStartRunning(self.m_ModelSceneMain)

        self.m_ActorGameRecordViewer = actor
        self.m_View:setViewGameRecordViewer(actor:getView())
    end

    return self.m_ActorGameRecordViewer
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateAuxiliaryCommands(self)
    self.m_State = "stateAuxiliaryCommands"

    self.m_View:setMenuTitleText(getLocalizedText(1, "AuxiliaryCommands"))
        :setButtonExitText(getLocalizedText(1, "Back"))
        :setItems({
            self.m_ItemSetMessageIndicator,
            self.m_ItemSetMusic,
        })
end

local function setStateMain(self)
    self.m_State = "stateMain"
    self.m_View:setMenuTitleText(getLocalizedText(1, "MainMenu"))
        :setButtonExitText(getLocalizedText(1, "Exit"))

    if (self.m_IsPlayerLoggedIn) then
        self.m_View:setItems({
            self.m_ItemSinglePlayerGame,
            self.m_ItemMultiPlayersGame,
            self.m_ItemManageReplay,
            self.m_ItemViewGameRecord,
            self.m_ItemLogin,
            self.m_ItemAuxiliaryCommands,
            self.m_ItemHelp,
        })
    else
        self.m_View:setItems({
            self.m_ItemSinglePlayerGame,
            self.m_ItemLogin,
            self.m_ItemManageReplay,
            self.m_ItemAuxiliaryCommands,
            self.m_ItemHelp,
        })
    end
end

local function setStateMultiPlayersGame(self)
    self.m_State = "stateMultiPlayersGame"

    self.m_View:setMenuTitleText(getLocalizedText(1, "MultiPlayersGame"))
        :setButtonExitText(getLocalizedText(1, "Back"))
        :setItems({
            self.m_ItemNewWar,
            self.m_ItemContinue,
            self.m_ItemJoinWar,
            self.m_ItemExitWar,
        })
end

local function setStateSinglePlayerGame(self)
    self.m_State = "stateSinglePlayerGame"
    self.m_View:setMenuTitleText(getLocalizedText(1, "SinglePlayerGame"))
        :setButtonExitText(getLocalizedText(1, "Back"))
        :setItems({
            self.m_ItemSingleCampaign,
            self.m_ItemSingleFreeGame,
            self.m_ItemSingleLoadGame,
        })
end

--------------------------------------------------------------------------------
-- The composition menu items.
--------------------------------------------------------------------------------
local function initItemAuxiliaryCommands(self)
    self.m_ItemAuxiliaryCommands = {
        name     = getLocalizedText(1, "AuxiliaryCommands"),
        callback = function()
            setStateAuxiliaryCommands(self)
        end,
    }
end

local function initItemSingleCampaign(self)
    self.m_ItemSingleCampaign = {
        name     = getLocalizedText(1, "Campaign"),
        callback = function()
            self:setMenuEnabled(false)
            self:getModelNewWarSelectorForNative()
                :setModeCampaign()
                :setEnabled(true)
        end
    }
end

local function initItemSinglePlayerGame(self)
    self.m_ItemSinglePlayerGame = {
        name     = getLocalizedText(1, "SinglePlayerGame"),
        callback = function()
            setStateSinglePlayerGame(self)
        end,
    }
end

local function initItemMultiContinue(self)
    local item = {
        name     = getLocalizedText(1, "Continue"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelContinueWarSelector():setEnabled(true)
        end,
    }

    self.m_ItemContinue = item
end

local function initItemMultiExitWar(self)
    self.m_ItemExitWar = {
        name     = getLocalizedText(1, "ExitWar"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelExitWarSelector():setEnabled(true)
        end,
    }
end

local function initItemHelp(self)
    local item = {
        name     = getLocalizedText(1, "Help"),
        callback = function()
            self:setMenuEnabled(false)
            getActorGameHelper(self):getModel():setEnabled(true)
        end,
    }

    self.m_ItemHelp = item
end

local function initItemMultiJoinWar(self)
    local item = {
        name     = getLocalizedText(1, "JoinWar"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelJoinWarSelector():setEnabled(true)
        end,
    }

    self.m_ItemJoinWar = item
end

local function initItemLogin(self)
    local item = {
        name     = getLocalizedText(1, "Login"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelLoginPanel():setEnabled(true)
        end,
    }

    self.m_ItemLogin = item
end

local function initItemManageReplay(self)
    local item = {
        name     = getLocalizedText(1, "ManageReplay"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelReplayManager():setEnabled(true)
        end,
    }

    self.m_ItemManageReplay = item
end

local function initItemMultiPlayersGame(self)
    self.m_ItemMultiPlayersGame = {
        name     = getLocalizedText(1, "MultiPlayersGame"),
        callback = function()
            setStateMultiPlayersGame(self)
        end,
    }
end

local function initItemMultiNewWar(self)
    local item = {
        name     = getLocalizedText(1, "NewGame"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelNewWarCreator():setEnabled(true)
        end,
    }

    self.m_ItemNewWar = item
end

local function initItemSetMessageIndicator(self)
    local item = {
        name     = getLocalizedText(1, "SetMessageIndicator"),
        callback = function()
            local indicator = SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain)
            indicator:setEnabled(not indicator:isEnabled())
        end,
    }

    self.m_ItemSetMessageIndicator = item
end

local function initItemSetMusic(self)
    local item = {
        name = getLocalizedText(1, "SetMusic"),
        callback = function()
            local isEnabled = not AudioManager.isEnabled()
            AudioManager.setEnabled(isEnabled)
            if (isEnabled) then
                AudioManager.playMainMusic()
            end
        end,
    }

    self.m_ItemSetMusic = item
end

local function initItemSingleLoadGame(self)
    self.m_ItemSingleLoadGame = {
        name     = getLocalizedText(1, "Load Game"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelContinueWarSelectorForNative():setEnabled(true)
        end
    }
end

local function initItemSingleFreeGame(self)
    self.m_ItemSingleFreeGame = {
        name     = getLocalizedText(1, "Free Game"),
        callback = function()
            self:setMenuEnabled(false)
            self:getModelNewWarSelectorForNative()
                :setModeFreeGame()
                :setEnabled(true)
        end,
    }
end

local function initItemViewGameRecord(self)
    self.m_ItemViewGameRecord = {
        name     = getLocalizedText(1, "ViewGameRecord"),
        callback = function()
            self:setMenuEnabled(false)
                :getModelGameRecordViewer():setEnabled(true)
        end,
    }
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelMainMenu:ctor(param)
    initItemAuxiliaryCommands(  self)
    initItemHelp(               self)
    initItemLogin(              self)
    initItemManageReplay(       self)
    initItemMultiContinue(      self)
    initItemMultiExitWar(       self)
    initItemMultiJoinWar(       self)
    initItemMultiNewWar(        self)
    initItemMultiPlayersGame(   self)
    initItemSetMessageIndicator(self)
    initItemSetMusic(           self)
    initItemSingleCampaign(     self)
    initItemSingleLoadGame(     self)
    initItemSingleFreeGame(     self)
    initItemSinglePlayerGame(   self)
    initItemViewGameRecord(     self)

    return self
end

function ModelMainMenu:initView()
    local view = self.m_View
    assert(view, "ModelMainMenu:initView() no view is attached to the actor of the model.")

    self:updateWithIsPlayerLoggedIn(false)

    return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelMainMenu:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelMainMenu:setEnabled(enabled)
    if (self.m_View) then
        self.m_View:setVisible(enabled)
    end

    return self
end

function ModelMainMenu:setMenuEnabled(enabled)
    if (self.m_View) then
        self.m_View:setMenuVisible(enabled)
    end

    return self
end

function ModelMainMenu:updateWithIsPlayerLoggedIn(isPlayerLoggedIn)
    self.m_IsPlayerLoggedIn = isPlayerLoggedIn
    setStateMain(self)

    return self
end

function ModelMainMenu:onButtonExitTouched()
    local state = self.m_State
    if (state == "stateAuxiliaryCommands") then
        setStateMain(self)
    elseif (state == "stateMain") then
        SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain):setConfirmText(getLocalizedText(66, "ExitGame"))
            :setOnConfirmYes(function()
                cc.Director:getInstance():endToLua()
            end)
            :setEnabled(true)
    elseif (state == "stateMultiPlayersGame") then
        setStateMain(self)
    elseif (state == "stateSinglePlayerGame") then
        setStateMain(self)
    else
        assert("ModelMainMenu:onButtonExitTouched() invalid state: " .. (state or ""))
    end

    return self
end

function ModelMainMenu:getModelContinueWarSelectorForNative()
    return getActorContinueWarSelectorForNative(self):getModel()
end

function ModelMainMenu:getModelContinueWarSelector()
    return getActorContinueWarSelector(self):getModel()
end

function ModelMainMenu:getModelExitWarSelector()
    return getActorExitWarSelector(self):getModel()
end

function ModelMainMenu:getModelGameRecordViewer()
    return getActorGameRecordViewer(self):getModel()
end

function ModelMainMenu:getModelJoinWarSelector()
    return getActorJoinWarSelector(self):getModel()
end

function ModelMainMenu:getModelLoginPanel()
    return getActorLoginPanel(self):getModel()
end

function ModelMainMenu:getModelNewWarSelectorForNative()
    return getActorNewWarSelectorForNative(self):getModel()
end

function ModelMainMenu:getModelNewWarCreator()
    return getActorNewWarCreator(self):getModel()
end

function ModelMainMenu:getModelReplayManager()
    return getActorReplayManager(self):getModel()
end

return ModelMainMenu
