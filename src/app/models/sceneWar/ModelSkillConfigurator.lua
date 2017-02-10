
local ModelSkillConfigurator = class("ModelSkillConfigurator")

local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDataAccessors        = requireFW("src.app.utilities.SkillDataAccessors")
local SkillDescriptionFunctions = requireFW("src.app.utilities.SkillDescriptionFunctions")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")
local Actor                     = requireFW("src.global.actors.Actor")

local string, table    = string, table
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_ACTIVATE_SKILL = ActionCodeFunctions.getActionCode("ActionActivateSkill")

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

local function generateActiveSkillDetailText(skillID)
    local textList = {
        string.format("%s: %s\n%s / %s / %s",
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

local function generateActiveSkillConfirmationText(skillID, skillLevel)
    local skillData      = SkillDataAccessors.getSkillData(skillID)
    local modifierUnit   = skillData.modifierUnit
    local levelData      = skillData.levels[skillLevel]
    local modifierActive = levelData.modifierActive
    return string.format("%s\n%s %s%d\n%s: %d   %s: %s",
        getLocalizedText(22, "ConfirmationActiveSkill"),
        getLocalizedText(5, skillID), getLocalizedText(22, "Level"), skillLevel,
        getLocalizedText(22, "EnergyCost"), levelData.pointsActive, getLocalizedText(22, "Modifier"), (modifierActive) and ("" .. modifierActive .. modifierUnit) or ("--" .. modifierUnit)
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
local function sendActionActivateSkill(warID, actionID, skillID, skillLevel)
    WebSocketManager.sendAction({
        actionCode    = ACTION_CODE_ACTIVATE_SKILL,
        warID         = warID,
        actionID      = actionID,
        skillID       = skillID,
        skillLevel    = skillLevel,
        isActiveSkill = true,
    })
end

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local setStateActivateSkill
local setStateChooseActiveSkillLevel
local setStateMain

local function generateItemsForStateMain(self)
    local modelSceneWar     = self.m_ModelSceneWar
    local playerIndexInTurn = SingletonGetters.getModelTurnManager(modelSceneWar):getPlayerIndex()
    if ((SingletonGetters.isTotalReplay(modelSceneWar))                               or
        (playerIndexInTurn ~= SingletonGetters.getPlayerIndexLoggedIn(modelSceneWar)) or
        (self.m_IsWaitingForServerResponse))                                          then
        return {
            self.m_ItemPlaceHolder,
        }
    else
        return {
            self.m_ItemActivateSkill,
        }
    end
end

local function generateItemsForStateChooseActiveSkillLevel(self, skillID)
    local modelSceneWar         = self.m_ModelSceneWar
    local warID                 = SingletonGetters.getWarId(modelSceneWar)
    local actionID              = SingletonGetters.getActionId(modelSceneWar) + 1
    local modelConfirmBox       = SingletonGetters.getModelConfirmBox(modelSceneWar)
    local modelWarCommandMenu   = SingletonGetters.getModelWarCommandMenu(modelSceneWar)
    local modelMessageIndicator = SingletonGetters.getModelMessageIndicator(modelSceneWar)
    local eventDispatcher       = SingletonGetters.getScriptEventDispatcher(modelSceneWar)
    local _, modelPlayer        = SingletonGetters.getModelPlayerManager(modelSceneWar):getPlayerIndexLoggedIn()
    local energy                = modelPlayer:getEnergy()
    local skillData             = SkillDataAccessors.getSkillData(skillID)

    local items            = {}
    local hasAvailableItem = false
    for level = skillData.minLevelActive, skillData.maxLevelActive do
        local isAvailable = skillData.levels[level].pointsActive <= energy
        hasAvailableItem  = hasAvailableItem or isAvailable

        items[#items + 1] = {
            name        = getLocalizedText(22, "Level") .. level,
            isAvailable = isAvailable,
            callback    = function()
                modelConfirmBox:setConfirmText(generateActiveSkillConfirmationText(skillID, level))
                    :setOnConfirmYes(function()
                        sendActionActivateSkill(warID, actionID, skillID, level, true)
                        modelMessageIndicator:showPersistentMessage(getLocalizedText(80, "TransferingData"))
                        eventDispatcher:dispatchEvent({
                            name    = "EvtIsWaitingForServerResponse",
                            waiting = true,
                        })
                        modelWarCommandMenu:setEnabled(false)
                        modelConfirmBox:setEnabled(false)
                    end)
                    :setEnabled(true)
            end,
        }
    end

    return items, hasAvailableItem
end

local function generateItemsForStateActivateSkill(self)
    local items = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsActive")) do
        local subItems, hasAvailableSubItem = generateItemsForStateChooseActiveSkillLevel(self, skillID)
        items[#items + 1] = {
            name        = getLocalizedText(5, skillID),
            isAvailable = hasAvailableSubItem,
            callback    = function()
                setStateChooseActiveSkillLevel(self, skillID, subItems)
            end,
        }
    end

    return items
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
setStateActivateSkill = function(self)
    self.m_State = "stateActivateSkill"
    self.m_View:setMenuItems(generateItemsForStateActivateSkill(self))
        :setMenuTitleText(getLocalizedText(22, "ActivateSkill"))
        :setOverviewText(self.m_TextActiveSkillOverview)
end

setStateChooseActiveSkillLevel = function(self, skillID, menuItemsForStateChooseActiveSkillLevel)
    self.m_State = "stateChooseActiveSkillLevel"
    self.m_View:setMenuItems(menuItemsForStateChooseActiveSkillLevel)
        :setOverviewText(generateActiveSkillDetailText(skillID))
end

setStateMain = function(self)
    self.m_State = "stateMain"
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "SkillInfo"))
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

local function initTextActiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsActive")) do
        textList[#textList + 1] = generateActiveSkillDetailText(skillID)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForActiveSkill")

    self.m_TextActiveSkillOverview = table.concat(textList, "\n\n")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfigurator:ctor()
    initItemActivateSkill(      self)
    initItemPlaceHolder(        self)
    initTextActiveSkillOverview(self)

    return self
end

function ModelSkillConfigurator:setCallbackOnButtonBackTouched(callback)
    self.m_OnButtonBackTouched = callback

    return self
end

function ModelSkillConfigurator:onStartRunning(modelSceneWar)
    self.m_ModelSceneWar = modelSceneWar
    SingletonGetters.getScriptEventDispatcher(modelSceneWar)
        :addEventListener("EvtIsWaitingForServerResponse", self)

    return self
end

function ModelSkillConfigurator:onEvent(event)
    local eventName = event.name
    if (eventName == "EvtIsWaitingForServerResponse") then onEvtIsWaitingForServerResponse(self, event)
    end

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
