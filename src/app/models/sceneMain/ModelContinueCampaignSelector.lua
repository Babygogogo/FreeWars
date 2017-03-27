
--[[--------------------------------------------------------------------------------
-- ModelContinueCampaignSelector是主场景中的“已参战、未结束的战局”的列表。
--
-- 主要职责和使用场景举例：
--   构造并显示上述战局列表
--
--]]--------------------------------------------------------------------------------

local ModelContinueCampaignSelector = class("ModelContinueCampaignSelector")

local ActionCodeFunctions   = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions    = requireFW("src.app.utilities.AuxiliaryFunctions")
local WebSocketManager      = requireFW("src.app.utilities.WebSocketManager")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
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
    local playersCount = WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName)
    local players      = warConfiguration.players
    local names        = {}

    for i = 1, playersCount do
        names[i] = string.format("%s (%s: %s)", players[i].account, getLocalizedText(14, "TeamIndex"), AuxiliaryFunctions.getTeamNameWithTeamIndex(players[i].teamIndex))
        if (i == warConfiguration.playerIndexInTurn) then
            names[i] = names[i] .. string.format("(%s: %s)", getLocalizedText(34, "BootCountdown"),
                AuxiliaryFunctions.formatTimeInterval(warConfiguration.intervalUntilBoot - currentTime + warConfiguration.enterTurnTime))
        end
    end

    return names, playersCount
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

local function getActorCampaignConfigurator(self)
    if (not self.m_ActorCampaignConfigurator) then
        local model = Actor.createModel("sceneMain.ModelCampaignConfigurator")
        local view  = Actor.createView( "sceneMain.ViewCampaignConfigurator")

        model:setModeContinue()
            :setEnabled(false)
            :setCallbackOnButtonBackTouched(function()
                model:setEnabled(false)
                getActorWarFieldPreviewer(self):getModel():setEnabled(false)

                self.m_View:setMenuVisible(true)
                    :setButtonNextVisible(false)
            end)

        self.m_ActorCampaignConfigurator = Actor.createWithModelAndViewInstance(model, view)
        self.m_View:setViewCampaignConfigurator(view)
    end

    return self.m_ActorCampaignConfigurator
end

local function createOngoingWarList(self, warConfigurations)
    local warList               = {}
    local playerAccountLoggedIn = WebSocketManager.getLoggedInAccountAndPassword()

    for warID, warConfiguration in pairs(warConfigurations) do
        local warFieldFileName  = warConfiguration.warFieldFileName
        local playerIndexInTurn = warConfiguration.playerIndexInTurn

        warList[#warList + 1] = {
            warID        = warID,
            warFieldName = WarFieldManager.getWarFieldName(warFieldFileName),
            isInTurn     = (warConfiguration.players[playerIndexInTurn].account == playerAccountLoggedIn),
            callback     = function()
                getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                    :setPlayerNicknames(getPlayerNicknames(warConfiguration, os.time()))
                    :setEnabled(true)
                self.m_View:setButtonNextVisible(true)

                self.m_OnButtonNextTouched = function()
                    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
                    getActorCampaignConfigurator(self):getModel():resetWithCampaignConfiguration(warConfiguration)
                        :setEnabled(true)

                    self.m_View:setMenuVisible(false)
                        :setButtonNextVisible(false)
                end
            end,
        }
    end

    table.sort(warList, function(item1, item2)
        return item1.warID < item2.warID
    end)

    return warList
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelContinueCampaignSelector:ctor(param)
    return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelContinueCampaignSelector:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain
    getActorCampaignConfigurator(self):getModel():onStartRunning(modelSceneMain)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelContinueCampaignSelector:setEnabled(enabled)
    self.m_IsEnabled = enabled

    if (enabled) then
        SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(8, "TransferingData"))
        WebSocketManager.sendAction({actionCode = ACTION_CODE_GET_ONGOING_WAR_CONFIGURATIONS})
    end

    if (self.m_View) then
        self.m_View:setVisible(enabled)
            :setMenuVisible(true)
            :removeAllItems()
            :setButtonNextVisible(false)
    end

    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    getActorCampaignConfigurator(self):getModel():setEnabled(false)

    return self
end

function ModelContinueCampaignSelector:isRetrievingOngoingWarConfigurations()
    return self.m_IsEnabled
end

function ModelContinueCampaignSelector:updateWithOngoingWarConfigurations(warConfigurations)
    if (self.m_IsEnabled) then
        local warList = createOngoingWarList(self, warConfigurations)
        if (#warList == 0) then
            SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(8, "NoContinuableWar"))
        else
            self.m_View:showWarList(warList)
        end
    end

    return self
end

function ModelContinueCampaignSelector:isRetrievingOngoingWarData()
    return self.m_IsEnabled
end

function ModelContinueCampaignSelector:updateWithOngoingWarData(warData)
    local actorSceneWar = Actor.createWithModelAndViewName("warOnline.ModelWarOnline", warData, "common.ViewSceneWar")
    ActorManager.setAndRunRootActor(actorSceneWar, "FADE", 1)
end

function ModelContinueCampaignSelector:onButtonBackTouched()
    self:setEnabled(false)
    SingletonGetters.getModelMainMenu(self.m_ModelSceneMain):setMenuEnabled(true)

    return self
end

function ModelContinueCampaignSelector:onButtonNextTouched()
    self.m_OnButtonNextTouched()

    return self
end

return ModelContinueCampaignSelector
