
local ModelSkillConfigurator = class("ModelSkillConfigurator")

local Actor                     = requireFW("src.global.actors.Actor")
local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDescriptionFunctions = requireFW("src.app.utilities.SkillDescriptionFunctions")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")

local string, table    = string, table
local getLocalizedText = LocalizationFunctions.getLocalizedText

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generateSkillInfoText(self)
    local stringList = {}
    SingletonGetters.getModelPlayerManager(self.m_ModelSceneWar):forEachModelPlayer(function(modelPlayer, playerIndex)
        stringList[#stringList + 1] = string.format("%s %d: %s\n%s",
            getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(),
            SkillDescriptionFunctions.getBriefDescription(modelPlayer:getModelSkillConfiguration())
        )
    end)

    return table.concat(stringList, "\n--------------------\n")
end

local function generateItemsForStateMain(self)
    return {self.m_ItemPlaceHolder}
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateMain(self)
    self.m_State = "stateMain"
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "ConfigSkill"))
        :setOverviewText(generateSkillInfoText(self))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemPlaceHolder(self)
    self.m_ItemPlaceHolder = {
        name     = "(" .. getLocalizedText(22, "NoAvailableOption") .. ")",
        callback = function()
        end,
    }
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfigurator:ctor()
    initItemPlaceHolder(self)

    return self
end

function ModelSkillConfigurator:setCallbackOnButtonBackTouched(callback)
    self.m_OnButtonBackTouched = callback

    return self
end

function ModelSkillConfigurator:onStartRunning(modelSceneWar)
    self.m_ModelSceneWar = modelSceneWar

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillConfigurator:isEnabled()
    return self.m_IsEnabled
end

function ModelSkillConfigurator:setEnabled(enabled)
    self.m_IsEnabled = enabled
    if (enabled) then
        setStateMain(self)
    end

    if (self.m_View) then
        self.m_View:setVisible(enabled)
    end

    return self
end

function ModelSkillConfigurator:onButtonBackTouched()
    if (self.m_State ~= "stateMain") then
        setStateMain(self)
    elseif (self.m_OnButtonBackTouched) then
        self.m_OnButtonBackTouched()
    end

    return self
end

return ModelSkillConfigurator
