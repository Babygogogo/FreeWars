
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
local ACTION_CODE_DECLARE_SKILL  = ActionCodeFunctions.getActionCode("ActionDeclareSkill")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generateSkillInfoText(self)
    local modelSceneWar = self.m_ModelSceneWar
    local stringList    = {string.format("%s: %d%%         %s: %s         %s: %s",
        getLocalizedText(14, "EnergyGainModifier"), modelSceneWar:getEnergyGainModifier(),
        getLocalizedText(14, "EnablePassiveSkill"), getLocalizedText(14, (modelSceneWar:isPassiveSkillEnabled()) and ("Yes") or ("No")),
        getLocalizedText(14, "EnableActiveSkill"),  getLocalizedText(14, (modelSceneWar:isActiveSkillEnabled())  and ("Yes") or ("No"))
    )}

    SingletonGetters.getModelPlayerManager(modelSceneWar):forEachModelPlayer(function(modelPlayer, playerIndex)
        stringList[#stringList + 1] = string.format("%s %d: %s    %s: %d    %s: %s\n%s",
            getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(),
            getLocalizedText(22, "CurrentEnergy"), modelPlayer:getEnergy(),
            getLocalizedText(22, "DeclareSkill"),  getLocalizedText(22, modelPlayer:isSkillDeclared() and "Yes" or "No"),
            SkillDescriptionFunctions.getBriefDescription(modelPlayer:getModelSkillConfiguration())
        )
    end)

    return table.concat(stringList, "\n--------------------\n")
end

local function generateSkillDetailText(skillID, isActiveSkill)
    local textList = {
        string.format("%s: %s\n%s / %s / %s",
            getLocalizedText(5, skillID), getLocalizedText(23, skillID),
            getLocalizedText(22, "Level"), getLocalizedText(22, "EnergyCost"), getLocalizedText(22, "Modifier")
        ),
    }

    local skillData         = SkillDataAccessors.getSkillData(skillID)
    local modifierUnit      = skillData.modifierUnit
    local pointsFieldName   = (isActiveSkill) and ("pointsActive")   or ("pointsPassive")
    local modifierFieldName = (isActiveSkill) and ("modifierActive") or ("modifierPassive")
    for level, levelData in ipairs(skillData.levels) do
        textList[#textList + 1] = string.format("%d        %d        %s",
            level, levelData[pointsFieldName], (levelData[modifierFieldName]) and ("" .. levelData[modifierFieldName] .. modifierUnit) or ("--" .. modifierUnit)
        )
    end

    return table.concat(textList, "\n")
end

local function generateActivateSkillConfirmationText(skillID, skillLevel, isActiveSkill)
    local skillData      = SkillDataAccessors.getSkillData(skillID)
    local modifierUnit   = skillData.modifierUnit
    local levelData      = skillData.levels[skillLevel]
    local modifier       = (isActiveSkill) and (levelData.modifierActive) or (levelData.modifierPassive)
    local energyCost     = (isActiveSkill) and (levelData.pointsActive)   or (levelData.pointsPassive)

    return string.format("%s\n%s %s%d\n%s: %d   %s: %s",
        (isActiveSkill) and (getLocalizedText(22, "ConfirmationActiveSkill")) or (getLocalizedText(22, "ConfirmationResearchSkill")),
        getLocalizedText(5, skillID), getLocalizedText(22, "Level"), skillLevel,
        getLocalizedText(22, "EnergyCost"), energyCost, getLocalizedText(22, "Modifier"), (modifier) and ("" .. modifier .. modifierUnit) or ("--" .. modifierUnit)
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
local function sendActionActivateSkill(warID, actionID, skillID, skillLevel, isActiveSkill)
    WebSocketManager.sendAction({
        actionCode    = ACTION_CODE_ACTIVATE_SKILL,
        warID         = warID,
        actionID      = actionID,
        skillID       = skillID,
        skillLevel    = skillLevel,
        isActiveSkill = isActiveSkill,
    })
end

local function sendActionDeclareSkill(warID, actionID)
    WebSocketManager.sendAction({
        actionCode  = ACTION_CODE_DECLARE_SKILL,
        warID       = warID,
        actionID    = actionID,
    })
end

local function cleanupAfterSendAction(modelSceneWar)
    SingletonGetters.getModelMessageIndicator(modelSceneWar):showPersistentMessage(getLocalizedText(80, "TransferingData"))
    SingletonGetters.getScriptEventDispatcher(modelSceneWar):dispatchEvent({
        name    = "EvtIsWaitingForServerResponse",
        waiting = true,
    })
    SingletonGetters.getModelWarCommandMenu(modelSceneWar):setEnabled(false)
end

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local setStateActivateActiveSkill
local setStateChooseActiveSkillLevel
local setStateChoosePassiveSkillLevel
local setStateMain
local setStateResearchPassiveSkill

local function generateItemsSkillLevels(self, skillID, isActiveSkill)
    local modelSceneWar   = self.m_ModelSceneWar
    local warID           = SingletonGetters.getWarId(modelSceneWar)
    local actionID        = SingletonGetters.getActionId(modelSceneWar) + 1
    local modelConfirmBox = SingletonGetters.getModelConfirmBox(modelSceneWar)
    local _, modelPlayer  = SingletonGetters.getModelPlayerManager(modelSceneWar):getPlayerIndexLoggedIn()
    local energy          = modelPlayer:getEnergy()
    local skillData       = SkillDataAccessors.getSkillData(skillID)
    local minLevel        = (isActiveSkill) and (skillData.minLevelActive) or (skillData.minLevelPassive)
    local maxLevel        = (isActiveSkill) and (skillData.maxLevelActive) or (skillData.maxLevelPassive)
    local pointsFieldName = (isActiveSkill) and ("pointsActive")           or ("pointsPassive")

    local items            = {}
    local hasAvailableItem = false
    for level = minLevel, maxLevel do
        local isAvailable = skillData.levels[level][pointsFieldName] <= energy
        hasAvailableItem  = hasAvailableItem or isAvailable

        items[#items + 1] = {
            name        = getLocalizedText(22, "Level") .. level,
            isAvailable = isAvailable,
            callback    = function()
                modelConfirmBox:setConfirmText(generateActivateSkillConfirmationText(skillID, level, isActiveSkill))
                    :setOnConfirmYes(function()
                        sendActionActivateSkill(warID, actionID, skillID, level, isActiveSkill)
                        cleanupAfterSendAction(modelSceneWar)
                        modelConfirmBox:setEnabled(false)
                    end)
                    :setEnabled(true)
            end,
        }
    end

    return items, hasAvailableItem
end

local function generateItemsForStateMain(self)
    local modelSceneWar     = self.m_ModelSceneWar
    local playerIndexInTurn = SingletonGetters.getModelTurnManager(modelSceneWar):getPlayerIndex()
    if ((SingletonGetters.isTotalReplay(modelSceneWar))                               or
        (playerIndexInTurn ~= SingletonGetters.getPlayerIndexLoggedIn(modelSceneWar)) or
        (self.m_IsWaitingForServerResponse))                                          then
        return {self.m_ItemPlaceHolder}
    else
        local modelPlayer = SingletonGetters.getModelPlayerManager(modelSceneWar):getModelPlayer(playerIndexInTurn)
        local items       = {}
        if (modelSceneWar:isPassiveSkillEnabled()) then
            items[#items + 1] = self.m_ItemResearchPassiveSkill
        end
        if ((modelSceneWar:isActiveSkillEnabled()) and (not modelPlayer:isSkillDeclared()) and (modelPlayer:getEnergy() >= 3000)) then
            items[#items + 1] = self.m_ItemDeclareSkill
        end
        if (modelPlayer:canActivateSkill()) then
            items[#items + 1] = self.m_ItemActivateActiveSkill
        end
        if (#items == 0) then
            items[#items + 1] = self.m_ItemPlaceHolder
        end

        return items
    end
end

local function generateItemsForStateActivateSkill(self)
    local items = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsActive")) do
        local subItems, hasAvailableSubItem = generateItemsSkillLevels(self, skillID, true)
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

local function generateItemsForStateResearchPassiveSkill(self)
    local items = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsPassive")) do
        local subItems, hasAvailableSubItem = generateItemsSkillLevels(self, skillID, false)
        items[#items + 1] = {
            name        = getLocalizedText(5, skillID),
            isAvailable = hasAvailableSubItem,
            callback    = function()
                setStateChoosePassiveSkillLevel(self, skillID, subItems)
            end,
        }
    end

    return items
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
setStateActivateActiveSkill = function(self)
    self.m_State = "stateActivateActiveSkill"

    local _, modelPlayer = SingletonGetters.getModelPlayerManager(self.m_ModelSceneWar):getPlayerIndexLoggedIn()
    self.m_View:setMenuItems(generateItemsForStateActivateSkill(self))
        :setMenuTitleText(getLocalizedText(22, "ActivateSkill"))
        :setOverviewText(string.format("%s: %d\n\n%s", getLocalizedText(22, "CurrentEnergy"), modelPlayer:getEnergy(), self.m_TextActiveSkillOverview))
end

setStateChooseActiveSkillLevel = function(self, skillID, menuItemsForStateChooseActiveSkillLevel)
    self.m_State = "stateChooseActiveSkillLevel"
    self.m_View:setMenuItems(menuItemsForStateChooseActiveSkillLevel)
        :setOverviewText(generateSkillDetailText(skillID, true))
end

setStateChoosePassiveSkillLevel = function(self, skillID, menuItems)
    self.m_State = "stateChoosePassiveSkillLevel"
    self.m_View:setMenuItems(menuItems)
        :setOverviewText(generateSkillDetailText(skillID, false))
end

setStateMain = function(self)
    self.m_State = "stateMain"
    self.m_View:setMenuItems(generateItemsForStateMain(self))
        :setMenuTitleText(getLocalizedText(22, "SkillInfo"))
        :setOverviewText(generateSkillInfoText(self))
end

setStateResearchPassiveSkill = function(self)
    self.m_State = "stateResearchPassiveSkill"
    self.m_View:setMenuItems(generateItemsForStateResearchPassiveSkill(self))
        :setMenuTitleText(getLocalizedText(22, "ResearchPassiveSkill"))
        :setOverviewText(self.m_TextPassiveSkillOverview)
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemActivateActiveSkill(self)
    self.m_ItemActivateActiveSkill = {
        name     = getLocalizedText(22, "ActivateSkill"),
        callback = function()
            setStateActivateActiveSkill(self)
        end,
    }
end

local function initItemDeclareSkill(self)
    self.m_ItemDeclareSkill = {
        name     = getLocalizedText(22, "DeclareSkill"),
        callback = function()
            local modelSceneWar   = self.m_ModelSceneWar
            local modelConfirmBox = SingletonGetters.getModelConfirmBox(modelSceneWar)
            modelConfirmBox:setConfirmText(getLocalizedText(22, "ConfirmationDeclareSkill"))
                :setOnConfirmYes(function()
                    sendActionDeclareSkill(SingletonGetters.getWarId(modelSceneWar), SingletonGetters.getActionId(modelSceneWar) + 1)
                    cleanupAfterSendAction(modelSceneWar)
                    modelConfirmBox:setEnabled(false)
                end)
                :setEnabled(true)
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

local function initItemResearchPassiveSkill(self)
    self.m_ItemResearchPassiveSkill = {
        name     = getLocalizedText(22, "ResearchPassiveSkill"),
        callback = function()
            setStateResearchPassiveSkill(self)
        end,
    }
end

local function initTextActiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsActive")) do
        textList[#textList + 1] = generateSkillDetailText(skillID, true)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForActiveSkill")

    self.m_TextActiveSkillOverview = table.concat(textList, "\n\n")
end

local function initTextPassiveSkillOverview(self)
    local textList = {}
    for _, skillID in ipairs(SkillDataAccessors.getSkillCategory("SkillsPassive")) do
        textList[#textList + 1] = generateSkillDetailText(skillID, false)
    end

    textList[#textList + 1] = getLocalizedText(22, "HelpForPassiveSkill")

    self.m_TextPassiveSkillOverview = table.concat(textList, "\n\n")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfigurator:ctor()
    initItemActivateActiveSkill( self)
    initItemDeclareSkill(        self)
    initItemPlaceHolder(         self)
    initItemResearchPassiveSkill(self)
    initTextActiveSkillOverview( self)
    initTextPassiveSkillOverview(self)

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
    if     (state == "stateMain")                    then self.m_OnButtonBackTouched()
    elseif (state == "stateActivateActiveSkill")     then setStateMain(self)
    elseif (state == "stateChooseActiveSkillLevel")  then setStateActivateActiveSkill(self)
    elseif (state == "stateChoosePassiveSkillLevel") then setStateResearchPassiveSkill(self)
    elseif (state == "stateResearchPassiveSkill")    then setStateMain(self)
    else                                                  error("ModelSkillConfigurator:onButtonBackTouched() invalid state: " .. (state or ""))
    end

    return self
end

return ModelSkillConfigurator
