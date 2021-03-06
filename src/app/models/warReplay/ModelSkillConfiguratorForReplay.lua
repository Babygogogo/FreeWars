
local ModelSkillConfiguratorForReplay = class("ModelSkillConfiguratorForReplay")

local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDescriptionFunctions = requireFW("src.app.utilities.SkillDescriptionFunctions")

local string, table    = string, table
local getLocalizedText = LocalizationFunctions.getLocalizedText

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generateSkillInfoText(self)
    local modelWar   = self.m_ModelWar
    local stringList = {string.format("%s: %d%%    %s: %s    %s: %s",
        getLocalizedText(14, "EnergyGainModifier"),     modelWar:getEnergyGainModifier(),
        getLocalizedText(14, "EnablePassiveSkill"),     getLocalizedText(14, (modelWar:isPassiveSkillEnabled())      and ("Yes") or ("No")),
        getLocalizedText(14, "EnableActiveSkill"),      getLocalizedText(14, (modelWar:isActiveSkillEnabled())       and ("Yes") or ("No"))
    )}

    SingletonGetters.getModelPlayerManager(modelWar):forEachModelPlayer(function(modelPlayer, playerIndex)
        if (not modelPlayer:isAlive()) then
            stringList[#stringList + 1] = string.format("%s %d: %s (%s)", getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(), getLocalizedText(65, "Lost"))
        else
            stringList[#stringList + 1] = string.format("%s %d: %s    %s: %d\n%s",
                getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(),
                getLocalizedText(22, "CurrentEnergy"), modelPlayer:getEnergy(),
                SkillDescriptionFunctions.getBriefDescription(modelWar, modelPlayer:getModelSkillConfiguration())
            )
        end
    end)

    return table.concat(stringList, "\n--------------------\n")
end

local function generateSkillDetailText(self, skillID, isActiveSkill)
    local skillData    = self.m_ModelSkillDataManager:getSkillData(skillID)
    local modifierUnit = skillData.modifierUnit
    local textList     = {string.format("%s: %s", getLocalizedText(5, skillID), getLocalizedText(23, skillID))}
    if (skillData.maxModifierPassive) then
        textList[#textList + 1] = string.format("%s: %d%s", getLocalizedText(22, "MaxModifierPassive"), skillData.maxModifierPassive, modifierUnit)
    end
    textList[#textList + 1] = string.format("%s / %s / %s", getLocalizedText(22, "Level"), getLocalizedText(22, "EnergyCost"), getLocalizedText(22, "Modifier"))

    local pointsFieldName   = (isActiveSkill) and ("pointsActive")   or ("pointsPassive")
    local modifierFieldName = (isActiveSkill) and ("modifierActive") or ("modifierPassive")
    local minLevel          = (isActiveSkill) and (skillData.minLevelActive) or (skillData.minLevelPassive)
    local maxLevel          = (isActiveSkill) and (skillData.maxLevelActive) or (skillData.maxLevelPassive)
    for level = minLevel, maxLevel do
        local levelData = skillData.levels[level]
        textList[#textList + 1] = string.format("%d        %d        %s",
            level, levelData[pointsFieldName], (levelData[modifierFieldName]) and ("" .. levelData[modifierFieldName] .. modifierUnit) or ("--" .. modifierUnit)
        )
    end

    return table.concat(textList, "\n")
end

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local function generateItemsForStateMain(self)
    return {
        self.m_ItemSkillInfo,
        self.m_ItemCostListPassiveSkill,
        self.m_ItemCostListActiveSkill,
    }
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateMain(self)
    self.m_State = "stateMain"
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "SkillInfo"))
        :setOverviewText(generateSkillInfoText(self))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemCostListActiveSkill(self)
    self.m_ItemCostListActiveSkill = {
        name     = getLocalizedText(22, "EffectListActiveSkill"),
        callback = function()
            self.m_View:setOverviewText(self.m_TextActiveSkillOverview)
        end,
    }
end

local function initItemCostListPassiveSkill(self)
    self.m_ItemCostListPassiveSkill = {
        name     = getLocalizedText(22, "EffectListPassiveSkill"),
        callback = function()
            self.m_View:setOverviewText(self.m_TextPassiveSkillOverview)
        end,
    }
end

local function initItemSkillInfo(self)
    self.m_ItemSkillInfo = {
        name     = getLocalizedText(22, "SkillInfo"),
        callback = function()
            self.m_View:setOverviewText(generateSkillInfoText(self))
        end
    }
end

local function initTextActiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsActive")) do
        textList[#textList + 1] = generateSkillDetailText(self, skillID, true)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForActiveSkill")

    self.m_TextActiveSkillOverview = table.concat(textList, "\n\n")
end

local function initTextPassiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsPassive")) do
        textList[#textList + 1] = generateSkillDetailText(self, skillID, false)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForPassiveSkill")

    self.m_TextPassiveSkillOverview = table.concat(textList, "\n\n")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfiguratorForReplay:ctor()
    initItemCostListActiveSkill( self)
    initItemCostListPassiveSkill(self)
    initItemSkillInfo(           self)

    return self
end

function ModelSkillConfiguratorForReplay:setCallbackOnButtonBackTouched(callback)
    self.m_OnButtonBackTouched = callback

    return self
end

function ModelSkillConfiguratorForReplay:onStartRunning(modelWar)
    self.m_ModelWar              = modelWar
    self.m_ModelSkillDataManager = modelWar:getModelSkillDataManager()

    initTextActiveSkillOverview( self)
    initTextPassiveSkillOverview(self)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillConfiguratorForReplay:isEnabled()
    return self.m_IsEnabled
end

function ModelSkillConfiguratorForReplay:setEnabled(enabled)
    self.m_IsEnabled = enabled
    if (enabled) then
        setStateMain(self)
    end

    if (self.m_View) then
        self.m_View:setVisible(enabled)
    end

    return self
end

function ModelSkillConfiguratorForReplay:onButtonBackTouched()
    local state = self.m_State
    if     (state == "stateMain") then self.m_OnButtonBackTouched()
    else                               error("ModelSkillConfiguratorForReplay:onButtonBackTouched() invalid state: " .. (state or ""))
    end

    return self
end

return ModelSkillConfiguratorForReplay
