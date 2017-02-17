
local ModelWarConfigurator = class("ModelWarConfigurator")

local Actor                     = requireFW("src.global.actors.Actor")
local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")

local string           = string
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_EXIT_WAR      = ActionCodeFunctions.getActionCode("ActionExitWar")
local ACTION_CODE_JOIN_WAR      = ActionCodeFunctions.getActionCode("ActionJoinWar")
local ACTION_CODE_NEW_WAR       = ActionCodeFunctions.getActionCode("ActionNewWar")
local ACTION_CODE_RUN_SCENE_WAR = ActionCodeFunctions.getActionCode("ActionRunSceneWar")
local ENERGY_GAIN_MODIFIERS     = {0, 50, 100, 150, 200, 300, 500}
local INCOME_MODIFIERS          = {50, 100, 150, 200, 300, 500}
local INTERVALS_UNTIL_BOOT      = {60 * 15, 3600 * 24, 3600 * 24 * 3, 3600 * 24 * 7} -- 15 minutes, 1 day, 3 days, 7 days
local STARTING_ENERGIES         = {0, 10000, 20000, 30000, 40000, 50000}

local function initSelectorWeather(modelWarConfigurator)
    -- TODO: enable the selector.
    modelWarConfigurator:getModelOptionSelectorWithName("Weather"):setButtonsEnabled(false)
        :setOptions({
            {data = 1, text = getLocalizedText(40, "Clear"),},
        })
end

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generatePlayerColorText(playerIndex)
    if     (playerIndex == 1) then return string.format("1 (%s)", getLocalizedText(34, "Red"))
    elseif (playerIndex == 2) then return string.format("2 (%s)", getLocalizedText(34, "Blue"))
    elseif (playerIndex == 3) then return string.format("3 (%s)", getLocalizedText(34, "Yellow"))
    elseif (playerIndex == 4) then return string.format("4 (%s)", getLocalizedText(34, "Black"))
    else                           error("ModelWarConfigurator-generatePlayerColorText() invalid playerIndex: " .. (playerIndex or ""))
    end
end

local function generateOverviewText(self)
    return string.format("%s:\n\n%s:%s%s\n%s:%s%s\n%s:%s%s\n%s:%s%s\n\n%s:%s%s\n%s:%s%s\n\n%s:%s%s\n\n%s:%s%s\n%s:%s%s\n%s:%s%s\n%s:%s%s",
        getLocalizedText(14, "Overview"),
        getLocalizedText(14, "WarFieldName"),       "         ",     WarFieldManager.getWarFieldName(self.m_WarConfiguration.warFieldFileName),
        getLocalizedText(14, "PlayerIndex"),        "         ",     generatePlayerColorText(self.m_PlayerIndex),
        getLocalizedText(14, "FogOfWar"),           "         ",     getLocalizedText(14, (self.m_IsFogOfWarByDefault) and ("Yes") or ("No")),
        getLocalizedText(14, "IncomeModifier"),     "         ",     "" .. self.m_IncomeModifier .. "%",
        getLocalizedText(14, "RankMatch"),          "             ", getLocalizedText(14, (self.m_IsRankMatch)         and ("Yes") or ("No")),
        getLocalizedText(14, "MaxDiffScore"),       "         ",     (self.m_MaxDiffScore) and ("" .. self.m_MaxDiffScore) or getLocalizedText(14, "NoLimit"),
        getLocalizedText(14, "IntervalUntilBoot"),  "         ",     AuxiliaryFunctions.formatTimeInterval(self.m_IntervalUntilBoot),
        getLocalizedText(14, "StartingEnergy"),     "         ",     "" .. self.m_StartingEnergy,
        getLocalizedText(14, "EnergyGainModifier"), "         ",     "" .. self.m_EnergyGainModifier .. "%",
        getLocalizedText(14, "EnablePassiveSkill"), "     ",         getLocalizedText(14, (self.m_IsPassiveSkillEnabled) and ("Yes") or ("No")),
        getLocalizedText(14, "EnableActiveSkill"),  "     ",         getLocalizedText(14, (self.m_IsActiveSkillEnabled)  and ("Yes") or ("No"))
    )
end

local function getPlayerIndexForWarConfiguration(warConfiguration)
    local account = WebSocketManager.getLoggedInAccountAndPassword()
    for playerIndex, player in pairs(warConfiguration.players) do
        if (player.account == account) then
            return playerIndex
        end
    end

    error("ModelWarConfigurator-getPlayerIndexForWarConfiguration() failed to find the playerIndex.")
end

local function createItemsForStateMain(self)
    local mode = self.m_Mode
    if (mode == "modeCreate") then
        return {
            self.m_ItemPlayerIndex,
            self.m_ItemFogOfWar,
            self.m_ItemIncomeModifier,
            self.m_ItemRankMatch,
            self.m_ItemMaxDiffScore,
            self.m_ItemIntervalUntilBoot,
            self.m_ItemStartingEnergy,
            self.m_ItemEnergyModifier,
            self.m_ItemEnablePassiveSkill,
            self.m_ItemEnableActiveSkill,
        }

    elseif (mode == "modeJoin") then
        local items = {}
        if (#self.m_ItemsForStatePlayerIndex > 1) then
            items[#items + 1] = self.m_ItemPlayerIndex
        end
        if (#items == 0) then
            items[#items + 1] = self.m_ItemPlaceHolder
        end

        return items

    elseif (mode == "modeContinue") then
        return {self.m_ItemPlaceHolder}

    elseif (mode == "modeExit") then
        return {self.m_ItemPlaceHolder}

    else
        error("ModelWarConfigurator-createItemsForStateMain() the mode of the configurator is invalid: " .. (mode or ""))
    end
end

local setStateMain

local function createItemsForStatePlayerIndex(self)
    local warConfiguration = self.m_WarConfiguration
    local players          = warConfiguration.players
    local items            = {}

    for playerIndex = 1, WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName) do
        if ((not players) or (not players[playerIndex])) then
            items[#items + 1] = {
                playerIndex = playerIndex,
                name        = generatePlayerColorText(playerIndex),
                callback    = function()
                    self.m_PlayerIndex = playerIndex

                    setStateMain(self, true)
                end,
            }
        end
    end

    assert(#items > 0)
    return items
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------
local function sendActionExitWar(warID)
    WebSocketManager.sendAction({
        actionCode = ACTION_CODE_EXIT_WAR,
        warID      = warID,
    })
end

local function sendActionJoinWar(self)
    WebSocketManager.sendAction({
        actionCode  = ACTION_CODE_JOIN_WAR,
        playerIndex = self.m_PlayerIndex,
        warID       = self.m_WarConfiguration.warID,
        warPassword = "", -- TODO: self.m_WarPassword,
    })
end

local function sendActionNewWar(self)
    WebSocketManager.sendAction({
        actionCode            = ACTION_CODE_NEW_WAR,
        defaultWeatherCode    = 1, --TODO: add an option for the weather.
        energyGainModifier    = self.m_EnergyGainModifier,
        incomeModifier        = self.m_IncomeModifier,
        intervalUntilBoot     = self.m_IntervalUntilBoot,
        isActiveSkillEnabled  = self.m_IsActiveSkillEnabled,
        isPassiveSkillEnabled = self.m_IsPassiveSkillEnabled,
        isFogOfWarByDefault   = self.m_IsFogOfWarByDefault,
        isRankMatch           = self.m_IsRankMatch,
        maxDiffScore          = self.m_MaxDiffScore,
        playerIndex           = self.m_PlayerIndex,
        startingEnergy        = self.m_StartingEnergy,
        warPassword           = "", -- TODO: self.m_WarPassword,
        warFieldFileName      = self.m_WarConfiguration.warFieldFileName,
    })
end

local function sendActionRunSceneWar(warID)
    WebSocketManager.sendAction({
        actionCode = ACTION_CODE_RUN_SCENE_WAR,
        warID      = warID,
    })
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateEnableActiveSkill(self)
    self.m_State = "stateEnableActiveSkill"
    self.m_View:setMenuTitleText(getLocalizedText(14, "EnableActiveSkill"))
        :setItems(self.m_ItemsForStateEnableActiveSkill)
end

local function setStateEnablePassiveSkill(self)
    self.m_State = "stateEnablePassiveSkill"
    self.m_View:setMenuTitleText(getLocalizedText(14, "EnablePassiveSkill"))
        :setItems(self.m_ItemsForStateEnablePassiveSkill)
end

local function setStateEnergyGainModifier(self)
    self.m_State = "stateEnergyModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Energy Gain Modifier"))
        :setItems(self.m_ItemsForStateEnergyGainModifier)
end

local function setStateFogOfWar(self)
    self.m_State = "stateFogOfWar"
    self.m_View:setMenuTitleText(getLocalizedText(34, "FogOfWar"))
        :setItems(self.m_ItemsForStateFogOfWar)
end

local function setStateIncomeModifier(self)
    self.m_State = "stateIncomeModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Income Modifier"))
        :setItems(self.m_ItemsForStateIncomeModifier)
end

local function setStateIntervalUntilBoot(self)
    self.m_State = "stateIntervalUntilBoot"
    self.m_View:setMenuTitleText(getLocalizedText(14, "IntervalUntilBoot"))
        :setItems(self.m_ItemsForStateIntervalUntilBoot)
end

setStateMain = function(self, shouldUpdateOverview)
    self.m_State = "stateMain"
    self.m_View:setMenuTitleText(self.m_MenuTitleTextForMode)
        :setItems(createItemsForStateMain(self))

    if (shouldUpdateOverview) then
        self.m_View:setOverviewText(generateOverviewText(self))
    end
end

local function setStateMaxDiffScore(self)
    self.m_State = "stateMaxDiffScore"
    self.m_View:setMenuTitleText(getLocalizedText(34, "MaxDiffScore"))
        :setItems(self.m_ItemsForStateMaxDiffScore)
end

local function setStatePlayerIndex(self)
    self.m_State = "statePlayerIndex"
    self.m_View:setMenuTitleText(getLocalizedText(34, "PlayerIndex"))
        :setItems(self.m_ItemsForStatePlayerIndex)
end

local function setStateRankMatch(self)
    self.m_State = "stateRankMatch"
    self.m_View:setMenuTitleText(getLocalizedText(34, "RankMatch"))
        :setItems(self.m_ItemsForStateRankMatch)
end

local function setStateStartingEnergy(self)
    self.m_State = "stateStartingEnergy"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Starting Energy"))
        :setItems(self.m_ItemsForStateStartingEnergy)
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemEnableActiveSkill(self)
    self.m_ItemEnableActiveSkill = {
        name     = getLocalizedText(14, "EnableActiveSkill"),
        callback = function()
            setStateEnableActiveSkill(self)
        end,
    }
end

local function initItemEnablePassiveSkill(self)
    self.m_ItemEnablePassiveSkill = {
        name     = getLocalizedText(14, "EnablePassiveSkill"),
        callback = function()
            setStateEnablePassiveSkill(self)
        end,
    }
end

local function initItemEnergyGainModifier(self)
    self.m_ItemEnergyModifier = {
        name     = getLocalizedText(14, "Energy Gain Modifier"),
        callback = function()
            setStateEnergyGainModifier(self)
        end,
    }
end

local function initItemFogOfWar(self)
    self.m_ItemFogOfWar = {
        name     = getLocalizedText(34, "FogOfWar"),
        callback = function()
            setStateFogOfWar(self)
        end,
    }
end

local function initItemIncomeModifier(self)
    self.m_ItemIncomeModifier = {
        name     = getLocalizedText(14, "Income Modifier"),
        callback = function()
            setStateIncomeModifier(self)
        end,
    }
end

local function initItemIntervalUntilBoot(self)
    self.m_ItemIntervalUntilBoot = {
        name     = getLocalizedText(14, "IntervalUntilBoot"),
        callback = function()
            setStateIntervalUntilBoot(self)
        end,
    }
end

local function initItemMaxDiffScore(self)
    self.m_ItemMaxDiffScore = {
        name     = getLocalizedText(34, "MaxDiffScore"),
        callback = function()
            setStateMaxDiffScore(self)
        end,
    }
end

local function initItemPlayerIndex(self)
    self.m_ItemPlayerIndex = {
        name     = getLocalizedText(34, "PlayerIndex"),
        callback = function()
            setStatePlayerIndex(self)
        end,
    }
end

local function initItemPlaceHolder(self)
    self.m_ItemPlaceHolder = {
        name     = "(" .. getLocalizedText(14, "NoAvailableOption") .. ")",
        callback = function()
        end,
    }
end

local function initItemRankMatch(self)
    self.m_ItemRankMatch = {
        name     = getLocalizedText(34, "RankMatch"),
        callback = function()
            setStateRankMatch(self)
        end,
    }
end

local function initItemStartingEnergy(self)
    self.m_ItemStartingEnergy = {
        name     = getLocalizedText(14, "Starting Energy"),
        callback = function()
            setStateStartingEnergy(self)
        end,
    }
end

local function initItemsForStateEnableActiveSkill(self)
    self.m_ItemsForStateEnableActiveSkill = {
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsActiveSkillEnabled = true
                setStateMain(self, true)
            end,
        },
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsActiveSkillEnabled = false
                setStateMain(self, true)
            end,
        }
    }
end

local function initItemsForStateEnablePassiveSkill(self)
    self.m_ItemsForStateEnablePassiveSkill = {
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsPassiveSkillEnabled = true
                setStateMain(self, true)
            end,
        },
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsPassiveSkillEnabled = false
                setStateMain(self, true)
            end,
        }
    }
end

local function initItemsForStateEnergyGainModifier(self)
    local items = {}
    for _, modifier in ipairs(ENERGY_GAIN_MODIFIERS) do
        items[#items + 1] = {
            name     = (modifier ~= 100) and (string.format("%d%%", modifier)) or (string.format("%d%%(%s)", modifier, getLocalizedText(14, "Default"))),
            callback = function()
                self.m_EnergyGainModifier = modifier
                setStateMain(self, true)
            end,
        }
    end

    self.m_ItemsForStateEnergyGainModifier = items
end

local function initItemsForStateFogOfWar(self)
    self.m_ItemsForStateFogOfWar = {
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsFogOfWarByDefault = false

                setStateMain(self, true)
            end,
        },
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsFogOfWarByDefault = true

                setStateMain(self, true)
            end,
        },
    }
end

local function initItemsForStateIncomeModifier(self)
    local items = {}
    for _, modifier in ipairs(INCOME_MODIFIERS) do
        items[#items + 1] = {
            name     = (modifier ~= 100) and (string.format("%d%%", modifier)) or (string.format("%d%%(%s)", modifier, getLocalizedText(14, "Default"))),
            callback = function()
                self.m_IncomeModifier = modifier
                setStateMain(self, true)
            end,
        }
    end

    self.m_ItemsForStateIncomeModifier = items
end

local function initItemsForStateIntervalUntilBoot(self)
    local items = {}
    for _, interval in ipairs(INTERVALS_UNTIL_BOOT) do
        items[#items + 1] = {
            name     = AuxiliaryFunctions.formatTimeInterval(interval),
            callback = function()
                self.m_IntervalUntilBoot = interval

                setStateMain(self, true)
            end
        }
    end

    self.m_ItemsForStateIntervalUntilBoot = items
end

local function initItemsForStateMaxDiffScore(self)
    local items = {}
    for maxDiffScore = 50, 200, 50 do
        items[#items + 1] = {
            name     = "" .. maxDiffScore,
            callback = function()
                self.m_MaxDiffScore = maxDiffScore

                setStateMain(self, true)
            end,
        }
    end
    items[#items + 1] = {
        name     = getLocalizedText(14, "NoLimit"),
        callback = function()
            self.m_MaxDiffScore = nil

            setStateMain(self, true)
        end,
    }

    self.m_ItemsForStateMaxDiffScore = items
end

local function initItemsForStateRankMatch(self)
    self.m_ItemsForStateRankMatch = {
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsRankMatch = false

                setStateMain(self, true)
            end,
        },
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsRankMatch = true

                setStateMain(self, true)
            end,
        },
    }
end

local function initItemsForStateStartingEnergy(self)
    local items = {}
    for _, energy in ipairs(STARTING_ENERGIES) do
        items[#items + 1] = {
            name     = (energy ~= 0) and ("" .. energy) or (string.format("%d(%s)", energy, getLocalizedText(14, "Default"))),
            callback = function()
                self.m_StartingEnergy = energy
                setStateMain(self, true)
            end
        }
    end

    self.m_ItemsForStateStartingEnergy = items
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarConfigurator:ctor()
    initItemEnableActiveSkill( self)
    initItemEnablePassiveSkill(self)
    initItemEnergyGainModifier(self)
    initItemFogOfWar(          self)
    initItemIncomeModifier(    self)
    initItemIntervalUntilBoot( self)
    initItemMaxDiffScore(      self)
    initItemPlayerIndex(       self)
    initItemPlaceHolder(       self)
    initItemRankMatch(         self)
    initItemStartingEnergy(    self)

    initItemsForStateEnableActiveSkill( self)
    initItemsForStateEnablePassiveSkill(self)
    initItemsForStateEnergyGainModifier(self)
    initItemsForStateFogOfWar(          self)
    initItemsForStateIncomeModifier(    self)
    initItemsForStateIntervalUntilBoot( self)
    initItemsForStateMaxDiffScore(      self)
    initItemsForStateRankMatch(         self)
    initItemsForStateStartingEnergy(    self)

    return self
end

function ModelWarConfigurator:setCallbackOnButtonBackTouched(callback)
    self.m_OnButtonBackTouched = callback

    return self
end

function ModelWarConfigurator:setModeCreateWar()
    self.m_Mode                           = "modeCreate"
    self.m_MenuTitleTextForMode           = getLocalizedText(14, "CreateWar")
    self.m_CallbackOnButtonConfirmTouched = function()
        local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain)
        modelConfirmBox:setConfirmText(getLocalizedText(8, "NewWarConfirmation"))
            :setOnConfirmYes(function()
                local password = "" -- TODO: self.m_WarPassword
                if ((#password ~= 0) and (#password ~= 4)) then
                    SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "InvalidWarPassword"))
                else
                    SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "RetrievingCreateWarResult"))
                    sendActionNewWar(self)
                    self.m_View:disableButtonConfirmForSecs(5)
                end
                modelConfirmBox:setEnabled(false)
            end)
            :setEnabled(true)
    end

    return self
end

function ModelWarConfigurator:setModeJoinWar()
    self.m_Mode                           = "modeJoin"
    self.m_MenuTitleTextForMode           = getLocalizedText(14, "JoinWar")
    self.m_CallbackOnButtonConfirmTouched = function()
        local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain)
        modelConfirmBox:setConfirmText(getLocalizedText(8, "JoinWarConfirmation"))
            :setOnConfirmYes(function()
                local password = "" -- TODO: self.m_WarPassword
                if ((#password ~= 0) and (#password ~= 4)) then
                    SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "InvalidWarPassword"))
                else
                    SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "RetrievingJoinWarResult"))
                    sendActionJoinWar(self)
                    self.m_View:disableButtonConfirmForSecs(5)
                end
                modelConfirmBox:setEnabled(false)
            end)
            :setEnabled(true)
    end

    return self
end

function ModelWarConfigurator:setModeContinueWar()
    self.m_Mode                           = "modeContinue"
    self.m_MenuTitleTextForMode           = getLocalizedText(14, "ContinueWar")
    self.m_CallbackOnButtonConfirmTouched = function()
        SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "RetrievingWarData"))
        sendActionRunSceneWar(self.m_WarConfiguration.warID)
        self.m_View:disableButtonConfirmForSecs(5)
    end

    return self
end

function ModelWarConfigurator:setModeExitWar()
    self.m_Mode                           = "modeExit"
    self.m_MenuTitleTextForMode           = getLocalizedText(14, "ExitWar")
    self.m_CallbackOnButtonConfirmTouched = function()
        local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain)
        modelConfirmBox:setConfirmText(getLocalizedText(8, "ExitWarConfirmation"))
            :setOnConfirmYes(function()
                SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "RetrievingExitWarResult"))
                sendActionExitWar(self.m_WarConfiguration.warID)
                self.m_View:disableButtonConfirmForSecs(5)
                modelConfirmBox:setEnabled(false)
            end)
            :setEnabled(true)
    end

    return self
end

function ModelWarConfigurator:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarConfigurator:resetWithWarConfiguration(warConfiguration)
    self.m_WarConfiguration = warConfiguration
    local mode = self.m_Mode
    if (mode == "modeCreate") then
        self.m_EnergyGainModifier       = 100
        self.m_IncomeModifier           = 100
        self.m_IntervalUntilBoot        = 3600 * 24 * 3
        self.m_IsActiveSkillEnabled     = true
        self.m_IsFogOfWarByDefault      = false
        self.m_IsPassiveSkillEnabled    = true
        self.m_IsRankMatch              = false
        self.m_ItemsForStatePlayerIndex = createItemsForStatePlayerIndex(self)
        self.m_MaxDiffScore             = 100
        self.m_PlayerIndex              = 1
        self.m_StartingEnergy           = 0

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmCreateWar"))

    elseif (mode == "modeJoin") then
        self.m_EnergyGainModifier       = warConfiguration.energyGainModifier
        self.m_IncomeModifier           = warConfiguration.incomeModifier        or 100
        self.m_IntervalUntilBoot        = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled     = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault      = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled    = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch              = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex = createItemsForStatePlayerIndex(self)
        self.m_MaxDiffScore             = warConfiguration.maxDiffScore
        self.m_PlayerIndex              = self.m_ItemsForStatePlayerIndex[1].playerIndex
        self.m_StartingEnergy           = warConfiguration.startingEnergy

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmJoinWar"))

    elseif (mode == "modeContinue") then
        self.m_EnergyGainModifier       = warConfiguration.energyGainModifier
        self.m_IncomeModifier           = warConfiguration.incomeModifier        or 100
        self.m_IntervalUntilBoot        = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled     = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault      = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled    = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch              = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex = nil
        self.m_MaxDiffScore             = warConfiguration.maxDiffScore
        self.m_PlayerIndex              = getPlayerIndexForWarConfiguration(warConfiguration)
        self.m_StartingEnergy           = warConfiguration.startingEnergy

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmContinueWar"))

    elseif (mode == "modeExit") then
        self.m_EnergyGainModifier       = warConfiguration.energyGainModifier
        self.m_IncomeModifier           = warConfiguration.incomeModifier        or 100
        self.m_IntervalUntilBoot        = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled     = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault      = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled    = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch              = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex = nil
        self.m_MaxDiffScore             = warConfiguration.maxDiffScore
        self.m_PlayerIndex              = getPlayerIndexForWarConfiguration(warConfiguration)
        self.m_StartingEnergy           = warConfiguration.startingEnergy

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmExitWar"))

    else
        error("ModelWarConfigurator:resetWithWarConfiguration() the mode of the configurator is invalid: " .. (mode or ""))
    end

    setStateMain(self, true)

    return self
end

function ModelWarConfigurator:isEnabled()
    return self.m_IsEnabled
end

function ModelWarConfigurator:setEnabled(enabled)
    self.m_IsEnabled = enabled

    if (self.m_View) then
        self.m_View:setVisible(enabled)
    end

    return self
end

function ModelWarConfigurator:getPassword()
    --return self.m_View:getEditBoxPassword():getText()
end

function ModelWarConfigurator:setPassword(password)
    if (self.m_View) then
        self.m_View:getEditBoxPassword():setText(password)
    end

    return self
end

function ModelWarConfigurator:setPasswordEnabled(enabled)
    if (self.m_View) then
        self.m_View:getEditBoxPassword():setVisible(enabled)
    end

    return self
end

function ModelWarConfigurator:getWarId()
    return self.m_WarConfiguration.warID
end

function ModelWarConfigurator:onButtonBackTouched()
    if (self.m_State ~= "stateMain") then
        setStateMain(self)
    elseif (self.m_OnButtonBackTouched) then
        self.m_OnButtonBackTouched()
    end

    return self
end

function ModelWarConfigurator:onButtonConfirmTouched()
    if (self.m_CallbackOnButtonConfirmTouched) then
        self.m_CallbackOnButtonConfirmTouched()
    end

    return self
end

return ModelWarConfigurator
