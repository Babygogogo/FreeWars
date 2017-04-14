
local ModelNewCampaignSelector = class("ModelNewCampaignSelector")

local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")
local WarFieldManager       = requireFW("src.app.utilities.WarFieldManager")
local Actor                 = requireFW("src.global.actors.Actor")

local getLocalizedText = LocalizationFunctions.getLocalizedText
local ipairs           = ipairs

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
        local model = Actor.createModel("sceneMain.ModelWarConfiguratorForNative")
        local view  = Actor.createView( "sceneMain.ViewWarConfiguratorForNative")

        model:setEnabled(false)
            :setCallbackOnButtonBackTouched(function()
                model:setEnabled(false)
                getActorWarFieldPreviewer(self):getModel():setEnabled(false)

                self.m_View:setMenuVisible(true)
                    :setButtonNextVisible(false)
            end)

        self.m_ActorCampaignConfigurator = Actor.createWithModelAndViewInstance(model, view)
        self.m_View:setViewWarConfiguratorForNative(view)
    end

    return self.m_ActorCampaignConfigurator
end

local function createWarFieldList(self, listName)
    local list = {}
    for _, warFieldFileName in ipairs(WarFieldManager.getWarFieldFilenameList(listName)) do
        list[#list + 1] = {
            name     = WarFieldManager.getWarFieldName(warFieldFileName),
            callback = function()
                self.m_WarFieldFileName = warFieldFileName
                getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                    :setEnabled(true)

                self.m_View:setButtonNextVisible(true)
            end,
        }
    end

    return list
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelNewCampaignSelector:ctor(param)
    return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelNewCampaignSelector:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain
    getActorCampaignConfigurator(self):getModel():onStartRunning(modelSceneMain)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelNewCampaignSelector:setModeCampaign()
    getActorCampaignConfigurator(self):getModel():setModeCreateCampaign()

    if (self.m_View) then
        self.m_View:setMenuTitleText(getLocalizedText(1, "Campaign"))
            :removeAllItems()
            :showListWarField(createWarFieldList(self, "Campaign"))
    end

    return self
end

function ModelNewCampaignSelector:setModeFreeGame()
    getActorCampaignConfigurator(self):getModel():setModeCreateFreeGame()

    if (self.m_View) then
        self.m_View:setMenuTitleText(getLocalizedText(1, "Free Game"))
            :removeAllItems()
            :showListWarField(createWarFieldList(self, "SinglePlayerGame"))
    end

    return self
end

function ModelNewCampaignSelector:isEnabled()
    return self.m_IsEnabled
end

function ModelNewCampaignSelector:setEnabled(enabled)
    self.m_IsEnabled = enabled
    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    getActorCampaignConfigurator(self):getModel():setEnabled(false)

    if (self.m_View) then
        self.m_View:setVisible(enabled)
            :setButtonNextVisible(false)
            :setMenuVisible(true)
    end

    return self
end

function ModelNewCampaignSelector:onButtonBackTouched()
    self:setEnabled(false)
    SingletonGetters.getModelMainMenu(self.m_ModelSceneMain):setMenuEnabled(true)

    return self
end

function ModelNewCampaignSelector:onButtonNextTouched()
    getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    getActorCampaignConfigurator(self):getModel():resetWithWarConfiguration({warFieldFileName = self.m_WarFieldFileName})
        :setEnabled(true)

    self.m_View:setMenuVisible(false)
        :setButtonNextVisible(false)

    return self
end

return ModelNewCampaignSelector
