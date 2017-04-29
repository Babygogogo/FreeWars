
local ModelSkillConfiguratorForOnline = class("ModelSkillConfiguratorForOnline")

local ModelSkillGroupActive     = requireFW("src.app.models.common.ModelSkillGroupActive")
local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDescriptionFunctions = requireFW("src.app.utilities.SkillDescriptionFunctions")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")
local Actor                     = requireFW("src.global.actors.Actor")

local string, table    = string, table
local pairs            = pairs
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTIVE_SKILLS_COUNT                = ModelSkillGroupActive.getMaxSlotsCount()
local ACTION_CODE_ACTIVATE_SKILL         = ActionCodeFunctions.getActionCode("ActionActivateSkill")
local ACTION_CODE_RESEARCH_PASSIVE_SKILL = ActionCodeFunctions.getActionCode("ActionResearchPassiveSkill")
local ACTION_CODE_UPDATE_RESERVE_SKILLS  = ActionCodeFunctions.getActionCode("ActionUpdateReserveSkills")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function doesSkillExceedLimit(skillData, modelSkillConfiguration, skillID, skillLevel)
    local maxModifier = skillData.maxModifierPassive
    if (not maxModifier) then
        return false
    end

    local currentModifier = skillData.levels[skillLevel].modifierPassive
    for _, skill in pairs(modelSkillConfiguration:getModelSkillGroupPassive():getAllSkills()) do
        if (skill.id == skillID) then
            currentModifier = currentModifier + skill.modifier
        end
    end
    for _, skill in pairs(modelSkillConfiguration:getModelSkillGroupResearching():getAllSkills()) do
        if (skill.id == skillID) then
            currentModifier = currentModifier + skill.modifier
        end
    end
    return currentModifier > maxModifier
end

--------------------------------------------------------------------------------
-- The text generators.
--------------------------------------------------------------------------------
local function generateTextResearchConfirmation(self, skillID, skillLevel)
    local skillData      = self.m_ModelSkillDataManager:getSkillData(skillID)
    local modifierUnit   = skillData.modifierUnit
    local levelData      = skillData.levels[skillLevel]
    local modifier       = levelData.modifierPassive
    local energyCost     = levelData.pointsPassive

    return string.format("%s\n%s %s%d\n%s: %d   %s: %s",
        getLocalizedText(22, "ConfirmationResearchSkill"),
        getLocalizedText(5, skillID), getLocalizedText(22, "Level"), skillLevel,
        getLocalizedText(22, "EnergyCost"), energyCost, getLocalizedText(22, "Modifier"), (modifier) and ("" .. modifier .. modifierUnit) or ("--" .. modifierUnit)
    )
end

local function generateTextSkillInfo(self)
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

local function generateTextSkillDetail(self, skillID, isActiveSkill)
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

local function generateTextForStateUpdateReserveSkills(self)
    return string.format("%s\n%s\n%s",
        SkillDescriptionFunctions.getDescriptionForSkillGroupReserve(self.m_ModelWar, self.m_ModelSkillGroupReserve),
        "--------------------",
        getLocalizedText(35, "HelpForReserveSkills")
    )
end

local function generateTextForStateUpdateReserveSkillSlot(self)
    local textForSkill = (self.m_ReserveSkillID) and (string.format("-> %s", getLocalizedText(5, self.m_ReserveSkillID))) or ("")
    return string.format("%s: %s %d %s\n%s\n%s\n%s\n%s",
        getLocalizedText(3, "CurrentPosition"), getLocalizedText(3, "Skill"), self.m_ReserveSkillIndex, textForSkill,
        "--------------------",
        SkillDescriptionFunctions.getDescriptionForSkillGroupReserve(self.m_ModelWar, self.m_ModelSkillGroupReserve),
        "--------------------",
        getLocalizedText(35, "HelpForReserveSkills")
    )
end

--------------------------------------------------------------------------------
-- The callback functions on events.
--------------------------------------------------------------------------------
local function onEvtIsWaitingForServerResponse(self, event)
    self.m_IsWaitingForServerResponse = event.waiting
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------
local function sendActionActivateSkill(self)
    local modelWar = self.m_ModelWar
    WebSocketManager.sendAction({
        actionCode = ACTION_CODE_ACTIVATE_SKILL,
        warID      = SingletonGetters.getWarId(modelWar),
        actionID   = SingletonGetters.getActionId(modelWar) + 1,
    })
end

local function sendActionResearchPassiveSkill(warID, actionID, skillID, skillLevel)
    WebSocketManager.sendAction({
        actionCode    = ACTION_CODE_RESEARCH_PASSIVE_SKILL,
        warID         = warID,
        actionID      = actionID,
        skillID       = skillID,
        skillLevel    = skillLevel,
    })
end

local function sendActionUpdateReserveSkills(self)
    local modelWar = self.m_ModelWar
    WebSocketManager.sendAction({
        actionCode    = ACTION_CODE_UPDATE_RESERVE_SKILLS,
        warID         = SingletonGetters.getWarId(modelWar),
        actionID      = SingletonGetters.getActionId(modelWar) + 1,
        reserveSkills = self.m_ModelSkillGroupReserve:toSerializableTable(),
    })
end

local function cleanupAfterSendAction(modelWar)
    SingletonGetters.getModelMessageIndicator(modelWar):showPersistentMessage(getLocalizedText(80, "TransferingData"))
    SingletonGetters.getScriptEventDispatcher(modelWar):dispatchEvent({
        name    = "EvtIsWaitingForServerResponse",
        waiting = true,
    })
    SingletonGetters.getModelWarCommandMenu(modelWar):setEnabled(false)
end

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local setStateChooseResearchSkillLevel
local setStateChooseReserveSkillLevel
local setStateMain
local setStateResearchPassiveSkill
local setStateUpdateReserveSkills
local setStateUpdateReserveSkillSlot

local function generateItemsPassiveSkillLevels(self, skillID)
    local modelWar         = self.m_ModelWar
    local warID            = SingletonGetters.getWarId(modelWar)
    local actionID         = SingletonGetters.getActionId(modelWar) + 1
    local modelConfirmBox  = SingletonGetters.getModelConfirmBox(modelWar)
    local modelPlayer      = self.m_ModelPlayerLoggedIn
    local energy           = modelPlayer:getEnergy()
    local skillData        = self.m_ModelSkillDataManager:getSkillData(skillID)
    local items            = {}
    local hasAvailableItem = false
    for level = skillData.minLevelPassive, skillData.maxLevelPassive do
        local isAvailable = skillData.levels[level].pointsPassive <= energy
        if ((isAvailable) and (doesSkillExceedLimit(skillData, modelPlayer:getModelSkillConfiguration(), skillID, level))) then
            isAvailable = false
        end
        hasAvailableItem  = hasAvailableItem or isAvailable

        items[#items + 1] = {
            name        = getLocalizedText(22, "Level") .. level,
            isAvailable = isAvailable,
            callback    = function()
                modelConfirmBox:setConfirmText(generateTextResearchConfirmation(self, skillID, level))
                    :setOnConfirmYes(function()
                        sendActionResearchPassiveSkill(warID, actionID, skillID, level)
                        cleanupAfterSendAction(modelWar)
                        modelConfirmBox:setEnabled(false)
                    end)
                    :setEnabled(true)
            end,
        }
    end

    return items, hasAvailableItem
end

local function generateItemsForStateChooseReserveSkillLevel(self, skillID)
    local modelWar               = self.m_ModelWar
    local skillData              = self.m_ModelSkillDataManager:getSkillData(skillID)
    local modelSkillGroupReserve = self.m_ModelSkillGroupReserve
    local slotIndex              = self.m_ReserveSkillIndex
    local items                  = {}
    for level = skillData.minLevelActive, skillData.maxLevelActive do
        items[#items + 1] = {
            name     = getLocalizedText(22, "Level") .. level,
            callback = function()
                modelSkillGroupReserve:setSkill(slotIndex, skillID, level)
                self.m_View:setOverviewText(generateTextForStateUpdateReserveSkillSlot(self))
            end,
        }
    end

    return items
end

local function generateItemsForStateMain(self)
    local modelWar          = self.m_ModelWar
    local playerIndexInTurn = SingletonGetters.getModelTurnManager(modelWar):getPlayerIndex()
    if ((playerIndexInTurn ~= self.m_PlayerIndexLoggedIn) or (self.m_IsWaitingForServerResponse)) then
        return {
            self.m_ItemSkillInfo,
            self.m_ItemCostListPassiveSkill,
            self.m_ItemCostListActiveSkill,
        }
    else
        local items = {}
        if (modelWar:isPassiveSkillEnabled()) then
            items[#items + 1] = self.m_ItemResearchPassiveSkill
        end
        if (modelWar:isActiveSkillEnabled()) then
            items[#items + 1] = self.m_ItemUpdateReserveSkills
        end

        local modelPlayer           = self.m_ModelPlayerLoggedIn
        local modelSkillGroupActive = modelPlayer:getModelSkillConfiguration():getModelSkillGroupActive()
        if ((modelWar:isActiveSkillEnabled())                                        and
            (not modelPlayer:isActivatingSkill())                                    and
            (not modelSkillGroupActive:isEmpty())                                    and
            (modelPlayer:getEnergy() >= modelSkillGroupActive:getTotalEnergyCost())) then
            items[#items + 1] = self.m_ItemActivateActiveSkill
        end

        items[#items + 1] = self.m_ItemSkillInfo
        items[#items + 1] = self.m_ItemCostListPassiveSkill
        items[#items + 1] = self.m_ItemCostListActiveSkill

        return items
    end
end

local function generateItemsForStateResearchPassiveSkill(self)
    local items = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsPassive")) do
        local subItems, hasAvailableSubItem = generateItemsPassiveSkillLevels(self, skillID)
        items[#items + 1] = {
            name        = getLocalizedText(5, skillID),
            isAvailable = hasAvailableSubItem,
            callback    = function()
                setStateChooseResearchSkillLevel(self, skillID, subItems)
            end,
        }
    end

    return items
end

local function generateItemsForStateUpdateReserveSkillSlot(self)
    local items = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsActive")) do
        items[#items + 1] = {
            name     = getLocalizedText(5, skillID),
            callback = function()
                setStateChooseReserveSkillLevel(self, skillID)
            end,
        }
    end

    items[#items + 1] = {
        name     = getLocalizedText(3, "Clear"),
        callback = function()
            self.m_ModelSkillGroupReserve:removeSkill(self.m_ReserveSkillIndex)
            self.m_View:setOverviewText(generateTextForStateUpdateReserveSkillSlot(self))
        end,
    }

    return items
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
setStateChooseResearchSkillLevel = function(self, skillID, menuItems)
    self.m_State = "stateChooseResearchSkillLevel"
    self.m_View:setMenuItems(menuItems)
        :setOverviewText(generateTextSkillDetail(self, skillID, false))
end

setStateChooseReserveSkillLevel = function(self, skillID)
    self.m_State          = "stateChooseReserveSkillLevel"
    self.m_ReserveSkillID = skillID
    self.m_View:setMenuItems(generateItemsForStateChooseReserveSkillLevel(self, skillID))
        :setOverviewText(generateTextForStateUpdateReserveSkillSlot(self))
end

setStateMain = function(self)
    self.m_State = "stateMain"
    self.m_ModelSkillGroupReserve:ctor()
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "SkillInfo"))
        :setOverviewText(generateTextSkillInfo(self))
end

setStateResearchPassiveSkill = function(self)
    self.m_State = "stateResearchPassiveSkill"
    self.m_View:setMenuItems(generateItemsForStateResearchPassiveSkill(self))
        :setMenuTitleText(getLocalizedText(22, "ResearchPassiveSkill"))
        :setOverviewText(self.m_TextPassiveSkillOverview)
end

setStateUpdateReserveSkills = function(self)
    self.m_State = "stateUpdateReserveSkills"
    self.m_View:setMenuItems(self.m_ItemsForStateUpdateReserveSkills)
        :setMenuTitleText(getLocalizedText(22, "UpdateReserve"))
        :setOverviewText(generateTextForStateUpdateReserveSkills(self))
end

setStateUpdateReserveSkillSlot = function(self, index)
    self.m_State             = "stateUpdateReserveSkillSlot"
    self.m_ReserveSkillIndex = index
    self.m_ReserveSkillID    = nil
    self.m_View:setMenuItems(generateItemsForStateUpdateReserveSkillSlot(self))
        :setOverviewText(generateTextForStateUpdateReserveSkillSlot(self))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemActivateActiveSkill(self)
    self.m_ItemActivateActiveSkill = {
        name     = getLocalizedText(22, "ActivateSkill"),
        callback = function()
            local modelWar        = self.m_ModelWar
            local modelPlayer     = self.m_ModelPlayerLoggedIn
            local modelConfirmBox = SingletonGetters.getModelConfirmBox(modelWar)
            modelConfirmBox:setConfirmText(string.format("%s: %d      %s: %d\n%s",
                    getLocalizedText(3, "CurrentEnergy"),       modelPlayer:getEnergy(),
                    getLocalizedText(3, "EnergyCost"),          modelPlayer:getModelSkillConfiguration():getModelSkillGroupActive():getTotalEnergyCost(),
                    getLocalizedText(3, "ConfirmActivateSkill")
                ))
                :setOnConfirmYes(function()
                    sendActionActivateSkill(self)
                    cleanupAfterSendAction(modelWar)
                    modelConfirmBox:setEnabled(false)
                end)
                :setEnabled(true)
        end,
    }
end

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

local function initItemResearchPassiveSkill(self)
    self.m_ItemResearchPassiveSkill = {
        name     = getLocalizedText(22, "ResearchPassiveSkill"),
        callback = function()
            setStateResearchPassiveSkill(self)
        end,
    }
end

local function initItemSkillInfo(self)
    self.m_ItemSkillInfo = {
        name     = getLocalizedText(22, "SkillInfo"),
        callback = function()
            self.m_View:setOverviewText(generateTextSkillInfo(self))
        end
    }
end

local function initItemUpdateReserveSkills(self)
    self.m_ItemUpdateReserveSkills = {
        name     = getLocalizedText(22, "UpdateReserveSkill"),
        callback = function()
            setStateUpdateReserveSkills(self)
        end,
    }
end

local function initItemsForStateUpdateReserveSkills(self)
    local items = {}
    for i = 1, ACTIVE_SKILLS_COUNT do
        items[#items + 1] = {
            name     = string.format("%s %d", getLocalizedText(3, "Skill"), i),
            callback = function()
                setStateUpdateReserveSkillSlot(self, i)
            end
        }
    end

    local modelSkillGroupReserve = self.m_ModelSkillGroupReserve
    items[#items + 1] = {
        name     = getLocalizedText(3, "Clear"),
        callback = function()
            modelSkillGroupReserve:clearAllSkills()
            self.m_View:setOverviewText(generateTextForStateUpdateReserveSkills(self))
        end,
    }

    local modelWar = self.m_ModelWar
    items[#items + 1] = {
        name     = getLocalizedText(1, "Confirm"),
        callback = function()
            if (modelSkillGroupReserve:isEmpty()) then
                SingletonGetters.getModelMessageIndicator(modelWar):showMessage(getLocalizedText(3, "NoReserveSkills"))
            elseif (modelSkillGroupReserve:hasSameSkill()) then
                SingletonGetters.getModelMessageIndicator(modelWar):showMessage(getLocalizedText(3, "DuplicatedReserveSkills"))
            else
                local modelConfirmBox = SingletonGetters.getModelConfirmBox(modelWar)
                modelConfirmBox:setConfirmText(getLocalizedText(3, "ConfirmReserveSkills"))
                    :setOnConfirmYes(function()
                        sendActionUpdateReserveSkills(self)
                        cleanupAfterSendAction(modelWar)
                        modelConfirmBox:setEnabled(false)
                    end)
                    :setEnabled(true)
            end
        end,
    }

    self.m_ItemsForStateUpdateReserveSkills = items
end

local function initTextActiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsActive")) do
        textList[#textList + 1] = generateTextSkillDetail(self, skillID, true)
    end

    textList[#textList + 1] = getLocalizedText(35, "HelpForReserveSkills")

    self.m_TextActiveSkillOverview = table.concat(textList, "\n\n")
end

local function initTextPassiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(self.m_ModelSkillDataManager:getSkillCategory("SkillsPassive")) do
        textList[#textList + 1] = generateTextSkillDetail(self, skillID, false)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForPassiveSkill")

    self.m_TextPassiveSkillOverview = table.concat(textList, "\n\n")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfiguratorForOnline:ctor()
    self.m_ModelSkillGroupReserve = ModelSkillGroupActive:ctor()

    initItemActivateActiveSkill( self)
    initItemCostListActiveSkill( self)
    initItemCostListPassiveSkill(self)
    initItemResearchPassiveSkill(self)
    initItemSkillInfo(           self)
    initItemUpdateReserveSkills( self)

    return self
end

function ModelSkillConfiguratorForOnline:setCallbackOnButtonBackTouched(callback)
    self.m_OnButtonBackTouched = callback

    return self
end

function ModelSkillConfiguratorForOnline:onStartRunning(modelWar)
    self.m_ModelWar                                        = modelWar
    self.m_ModelSkillDataManager                           = modelWar:getModelSkillDataManager()
    self.m_PlayerIndexLoggedIn, self.m_ModelPlayerLoggedIn = SingletonGetters.getPlayerIndexLoggedIn(modelWar)
    self.m_ModelSkillGroupReserve:onStartRunning(modelWar)

    initItemsForStateUpdateReserveSkills(self)
    initTextActiveSkillOverview( self)
    initTextPassiveSkillOverview(self)

    SingletonGetters.getScriptEventDispatcher(modelWar)
        :addEventListener("EvtIsWaitingForServerResponse", self)

    return self
end

function ModelSkillConfiguratorForOnline:onEvent(event)
    local eventName = event.name
    if (eventName == "EvtIsWaitingForServerResponse") then onEvtIsWaitingForServerResponse(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillConfiguratorForOnline:isEnabled()
    return self.m_IsEnabled
end

function ModelSkillConfiguratorForOnline:setEnabled(enabled)
    self.m_IsEnabled = enabled
    if (enabled) then
        setStateMain(self)
    end

    if (self.m_View) then
        self.m_View:setVisible(enabled)
    end

    return self
end

function ModelSkillConfiguratorForOnline:onButtonBackTouched()
    local state = self.m_State
    if     (state == "stateMain")                     then self.m_OnButtonBackTouched()
    elseif (state == "stateActivateActiveSkill")      then setStateMain(                  self)
    elseif (state == "stateChooseResearchSkillLevel") then setStateResearchPassiveSkill(  self)
    elseif (state == "stateChooseReserveSkillLevel")  then setStateUpdateReserveSkillSlot(self, self.m_ReserveSkillIndex)
    elseif (state == "stateResearchPassiveSkill")     then setStateMain(                  self)
    elseif (state == "stateUpdateReserveSkillSlot")   then setStateUpdateReserveSkills(   self)
    elseif (state == "stateUpdateReserveSkills")      then
        local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelWar)
        modelConfirmBox:setConfirmText(getLocalizedText(3, "ConfirmGiveUpSettings"))
            :setOnConfirmYes(function()
                setStateMain(self)
                modelConfirmBox:setEnabled(false)
            end)
            :setEnabled(true)
    else
        error("ModelSkillConfiguratorForOnline:onButtonBackTouched() invalid state: " .. (state or ""))
    end

    return self
end

return ModelSkillConfiguratorForOnline
