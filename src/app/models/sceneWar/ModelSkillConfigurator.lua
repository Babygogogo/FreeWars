
local ModelSkillConfigurator = class("ModelSkillConfigurator")

local Actor                     = requireFW("src.global.actors.Actor")
local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDataAccessors        = requireFW("src.app.utilities.SkillDataAccessors")
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

local function generateActiveSkillText(skillID)
    local textList = {
        string.format("%s: %s\n\n%s / %s / %s",
            getLocalizedText(5, skillID), getLocalizedText(23, skillID),
            getLocalizedText(22, "Level"), getLocalizedText(22, "EnergyCost"), getLocalizedText(22, "Modifier")
        ),
    }

    local skillData    = SkillDataAccessors.getSkillData(skillID)
    local modifierUnit = skillData.modifierUnit
    for level, levelData in ipairs(skillData.levels) do
        textList[#textList + 1] = string.format("%d        %d        %s",
            level, levelData.pointsActive, (levelData.modifierActive) and ("" .. levelData.modifierActive .. modifierUnit) or ("--" .. modifierUnit)
        )
    end

    return table.concat(textList, "\n")
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local function generateItemsForStateMain(self)
    return {
        self.m_ItemActivateSkill,
    }
end

local function generateItemsForStateChooseActiveSkillLevel(self)
    local items     = {}
    local skillData = SkillDataAccessors.getSkillData(self.m_SkillID)
    for level = skillData.minLevelActive, skillData.maxLevelActive do
        items[#items + 1] = {
            name     = getLocalizedText(22, "Level") .. level,
            callback = function()
            end,
        }
    end

    return items
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateActivateSkill(self)
    self.m_State = "stateActivateSkill"
    self.m_View:setMenuItems(self.m_ItemsForStateActivateSkill)
        :setMenuTitleText(getLocalizedText(22, "ActivateSkill"))
        :setOverviewText(getLocalizedText(22, "HelpForActiveSkill"))
end

local function setStateChooseActiveSkillLevel(self, skillID)
    self.m_State   = "stateChooseActiveSkillLevel"
    self.m_SkillID = skillID
    self.m_View:setMenuItems(generateItemsForStateChooseActiveSkillLevel(self))
        :setOverviewText(generateActiveSkillText(skillID))
end

local function setStateMain(self)
    self.m_State = "stateMain"
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "ConfigSkill"))
        :setOverviewText(generateSkillInfoText(self))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemActivateSkill(self)
    self.m_ItemActivateSkill = {
        name     = getLocalizedText(22, "ActivateSkill"),
        callback = function()
            setStateActivateSkill(self)
        end,
    }
end

local function initItemPlaceHolder(self)
    self.m_ItemPlaceHolder = {
        name     = "(" .. getLocalizedText(22, "NoAvailableOption") .. ")",
        callback = function()
        end,
    }
end

local function initItemsForStateActivateSkill(self)
    local items = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsActive")) do
        items[#items + 1] = {
            name     = getLocalizedText(5, skillID),
            callback = function()
                setStateChooseActiveSkillLevel(self, skillID)
            end,
        }
    end

    self.m_ItemsForStateActivateSkill = items
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfigurator:ctor()
    initItemActivateSkill(         self)
    initItemPlaceHolder(           self)
    initItemsForStateActivateSkill(self)

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
    local state = self.m_State
    if (state == "stateMain") then
        self.m_OnButtonBackTouched()
    elseif (state == "stateActivateSkill") then
        setStateMain(self)
    elseif (state == "stateChooseActiveSkillLevel") then
        setStateActivateSkill(self)
    else
        error("ModelSkillConfigurator:onButtonBackTouched() invalid state: " .. (state or ""))
    end

    return self
end

return ModelSkillConfigurator
