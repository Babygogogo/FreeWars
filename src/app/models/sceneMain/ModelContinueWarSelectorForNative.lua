
local ModelContinueWarSelectorForNative = class("ModelContinueWarSelectorForNative")

local ActionCodeFunctions   = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions    = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local NativeWarManager      = requireFW("src.app.utilities.NativeWarManager")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")
local WarFieldManager       = requireFW("src.app.utilities.WarFieldManager")
local Actor                 = requireFW("src.global.actors.Actor")
local ActorManager          = requireFW("src.global.actors.ActorManager")

local os, string       = os, string
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_GET_ONGOING_WAR_CONFIGURATIONS = ActionCodeFunctions.getActionCode("ActionGetOngoingWarConfigurations")
local ACTION_CODE_RUN_SCENE_WAR                  = ActionCodeFunctions.getActionCode("ActionRunSceneWar")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getPlayerNicknames(warConfiguration, currentTime)
    local players = warConfiguration.players
    local names   = {}
    for i = 1, WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName) do
        names[i] = string.format("%s (%s: %s)", players[i].account, getLocalizedText(14, "TeamIndex"), AuxiliaryFunctions.getTeamNameWithTeamIndex(players[i].teamIndex))
    end

    return names
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function getActorWarFieldPreviewer(self)
    if (not self.m_ActorWarFieldPreviewer) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelWarFieldPreviewer", nil, "sceneMain.ViewWarFieldPreviewer")

        self.m_ActorWarFieldPreviewer = actor
        self.m_View:setViewWarFieldPreviewer(actor:getView())
    end

    return self.m_ActorWarFieldPreviewer
end

local function getActorWarConfiguratorForNative(self)
    if (not self.m_ActorWarConfiguratorForNative) then
        local model = Actor.createModel("sceneMain.ModelWarConfiguratorForNative")
        local view  = Actor.createView( "sceneMain.ViewWarConfiguratorForNative")

        model:setModeContinue()
            :setEnabled(false)
            :setCallbackOnButtonBackTouched(function()
                model:setEnabled(false)
                getActorWarFieldPreviewer(self):getModel():setEnabled(false)

                self.m_View:setMenuVisible(true)
                    :setButtonNextVisible(false)
            end)

        self.m_ActorWarConfiguratorForNative = Actor.createWithModelAndViewInstance(model, view)
        self.m_View:setViewWarConfiguratorForNative(view)
    end

    return self.m_ActorWarConfiguratorForNative
end

local function createWarList(self, warConfigurations)
    local warList = {}
    for _, warConfiguration in pairs(warConfigurations) do
        local warFieldFileName  = warConfiguration.warFieldFileName
        warList[#warList + 1] = {
            saveIndex    = warConfiguration.saveIndex,
            warFieldName = WarFieldManager.getWarFieldName(warFieldFileName),
            callback     = function()
                getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                    :setPlayerNicknames(getPlayerNicknames(warConfiguration))
                    :setEnabled(true)
                self.m_View:setButtonNextVisible(true)

                self.m_OnButtonNextTouched = function()
                    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
                    getActorWarConfiguratorForNative(self):getModel():resetWithWarConfiguration(warConfiguration)
                        :setEnabled(true)

                    self.m_View:setMenuVisible(false)
                        :setButtonNextVisible(false)
                end
            end,
        }
    end

    return warList
end

local function resetMenuItems(self)
    self.m_View:removeAllItems()

    local warConfigurations = NativeWarManager.getAllWarConfigurations()
    local warList           = createWarList(self, warConfigurations)
    if (#warList == 0) then
        SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(8, "NoContinuableWar"))
    else
        self.m_View:showWarList(warList)
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelContinueWarSelectorForNative:ctor(param)
    return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelContinueWarSelectorForNative:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain
    getActorWarConfiguratorForNative(self):getModel():onStartRunning(modelSceneMain)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelContinueWarSelectorForNative:setEnabled(enabled)
    self.m_IsEnabled = enabled

    if (self.m_View) then
        self.m_View:setVisible(enabled)
            :setMenuVisible(true)
            :setButtonNextVisible(false)

        if (enabled) then
            resetMenuItems(self)
        end
    end

    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    getActorWarConfiguratorForNative(self):getModel():setEnabled(false)

    return self
end

function ModelContinueWarSelectorForNative:updateWithOngoingWarConfigurations(warConfigurations)
    if (self.m_IsEnabled) then
        local warList = createWarList(self, warConfigurations)
        if (#warList == 0) then
            SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(8, "NoContinuableWar"))
        else
            self.m_View:showWarList(warList)
        end
    end

    return self
end

function ModelContinueWarSelectorForNative:onButtonBackTouched()
    self:setEnabled(false)
    SingletonGetters.getModelMainMenu(self.m_ModelSceneMain):setMenuEnabled(true)

    return self
end

function ModelContinueWarSelectorForNative:onButtonNextTouched()
    self.m_OnButtonNextTouched()

    return self
end

return ModelContinueWarSelectorForNative
