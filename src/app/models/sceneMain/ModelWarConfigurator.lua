
local ModelWarConfigurator = class("ModelWarConfigurator")

local Actor                     = requireFW("src.global.actors.Actor")
local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")

local string           = string
local pairs            = pairs
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_EXIT_WAR      = ActionCodeFunctions.getActionCode("ActionExitWar")
local ACTION_CODE_JOIN_WAR      = ActionCodeFunctions.getActionCode("ActionJoinWar")
local ACTION_CODE_NEW_WAR       = ActionCodeFunctions.getActionCode("ActionNewWar")
local ACTION_CODE_RUN_SCENE_WAR = ActionCodeFunctions.getActionCode("ActionRunSceneWar")
local ENERGY_GAIN_MODIFIERS     = {0, 50, 100, 150, 200, 300, 500}
local INCOME_MODIFIERS          = {0, 50, 100, 150, 200, 300, 500}
local INTERVALS_UNTIL_BOOT      = {60 * 15, 3600 * 24, 3600 * 24 * 3, 3600 * 24 * 7} -- 15 minutes, 1 day, 3 days, 7 days
local STARTING_ENERGIES         = {0, 10000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 90000, 100000}
local STARTING_FUNDS            = {0, 5000, 10000, 20000, 30000, 40000, 50000, 100000, 150000, 200000, 300000, 400000, 500000}

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

local function getPlayerIndexForWarConfiguration(warConfiguration)
    local account = WebSocketManager.getLoggedInAccountAndPassword()
    for playerIndex, player in pairs(warConfiguration.players) do
        if (player.account == account) then
            return playerIndex
        end
    end

    error("ModelWarConfigurator-getPlayerIndexForWarConfiguration() failed to find the playerIndex.")
end

local function getTeamIndexForWarConfiguration(warConfiguration)
    local account = WebSocketManager.getLoggedInAccountAndPassword()
    for _, playerData in pairs(warConfiguration.players) do
        if (playerData.account == account) then
            return playerData.teamIndex
        end
    end

    error("ModelWarConfigurator-getTeamIndexForWarConfiguration() failed to find the teamIndex.")
end

local function getFirstUnusedTeamIndex(warConfiguration)
    local playersData = warConfiguration.players
    if (not playersData) then
        return 1
    else
        for teamIndex = 1, WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName) do
            local isUsed = false
            for _, playerData in pairs(playersData) do
                if (playerData.teamIndex == teamIndex) then
                    isUsed = true
                    break
                end
            end

            if (not isUsed) then
                return teamIndex
            end
        end

        error("ModelWarConfigurator-getFirstUnusedTeamIndex() failed to find the team index.")
    end
end

--------------------------------------------------------------------------------
-- The overview text generators.
--------------------------------------------------------------------------------
local function generateTextForStartingFund(startingFund)
    if (startingFund == 0) then
        return nil
    else
        return string.format("%s:         %d", getLocalizedText(14, "StartingFund"), startingFund)
    end
end

local function generateTextForIncomeModifier(incomeModifier)
    if (incomeModifier == 100) then
        return nil
    else
        return string.format("%s:         %d%%", getLocalizedText(14, "IncomeModifier"), incomeModifier)
    end
end

local function generateTextForStartingEnergy(startingEnergy)
    if (startingEnergy == 0) then
        return nil
    else
        return string.format("%s:         %d", getLocalizedText(14, "StartingEnergy"), startingEnergy)
    end
end

local function generateTextForEnergyModifier(energyGainModifier)
    if (energyGainModifier == 100) then
        return nil
    else
        return string.format("%s:         %d%%", getLocalizedText(14, "EnergyGainModifier"), energyGainModifier)
    end
end

local function generateTextForEnablePassiveSkill(isPassiveSkillEnabled)
    if (isPassiveSkillEnabled) then
        return nil
    else
        return string.format("%s:     %s", getLocalizedText(14, "EnablePassiveSkill"), getLocalizedText(14, (isPassiveSkillEnabled) and ("Yes") or ("No")))
    end
end

local function generateTextForEnableActiveSkill(isActiveSkillEnabled)
    if (isActiveSkillEnabled) then
        return nil
    else
        return string.format("%s:     %s", getLocalizedText(14, "EnableActiveSkill"), getLocalizedText(14, (isActiveSkillEnabled) and ("Yes") or ("No")))
    end
end

local function generateTextForMoveRangeModifier(moveRangeModifier)
    if (moveRangeModifier == 0) then
        return nil
    else
        return string.format("%s:     %d", getLocalizedText(14, "MoveRangeModifier"), moveRangeModifier)
    end
end

local function generateTextForAttackModifier(attackModifier)
    if (attackModifier == 0) then
        return nil
    else
        return string.format("%s:     %d%%", getLocalizedText(14, "AttackModifier"), attackModifier)
    end
end

local function generateTextForVisionModifier(visionModifier)
    if (visionModifier == 0) then
        return nil
    else
        return string.format("%s:         %d", getLocalizedText(14, "VisionModifier"), visionModifier)
    end
end

local function generateTextForAdvancedSettings(self)
    local textList = {getLocalizedText(14, "Advanced Settings") .. ":"}
    textList[#textList + 1] = generateTextForStartingFund(      self.m_StartingFund)
    textList[#textList + 1] = generateTextForIncomeModifier(    self.m_IncomeModifier)
    textList[#textList + 1] = generateTextForStartingEnergy(    self.m_StartingEnergy)
    textList[#textList + 1] = generateTextForEnergyModifier(    self.m_EnergyGainModifier)
    textList[#textList + 1] = generateTextForEnablePassiveSkill(self.m_IsPassiveSkillEnabled)
    textList[#textList + 1] = generateTextForEnableActiveSkill( self.m_IsActiveSkillEnabled)
    textList[#textList + 1] = generateTextForMoveRangeModifier( self.m_MoveRangeModifier)
    textList[#textList + 1] = generateTextForAttackModifier(    self.m_AttackModifier)
    textList[#textList + 1] = generateTextForVisionModifier(    self.m_VisionModifier)

    if (#textList == 1) then
        textList[#textList + 1] = getLocalizedText(14, "None")
    end
    return table.concat(textList, "\n")
end

local function generateOverviewText(self)
    return string.format("%s:\n\n%s:%s%s\n%s:%s%s (%s: %s)\n%s:%s%s\n\n%s:%s%s\n%s:%s%s\n\n%s:%s%s\n\n%s",
        getLocalizedText(14, "Overview"),
        getLocalizedText(14, "WarFieldName"),      "         ",     WarFieldManager.getWarFieldName(self.m_WarConfiguration.warFieldFileName),
        getLocalizedText(14, "PlayerIndex"),       "         ",     generatePlayerColorText(self.m_PlayerIndex),
        getLocalizedText(14, "TeamIndex"),                          AuxiliaryFunctions.getTeamNameWithTeamIndex(self.m_TeamIndex),
        getLocalizedText(14, "FogOfWar"),          "         ",     getLocalizedText(14, (self.m_IsFogOfWarByDefault) and ("Yes") or ("No")),
        getLocalizedText(14, "RankMatch"),         "             ", getLocalizedText(14, (self.m_IsRankMatch)         and ("Yes") or ("No")),
        getLocalizedText(14, "MaxDiffScore"),      "         ",     (self.m_MaxDiffScore) and ("" .. self.m_MaxDiffScore) or getLocalizedText(14, "NoLimit"),
        getLocalizedText(14, "IntervalUntilBoot"), "         ",     AuxiliaryFunctions.formatTimeInterval(self.m_IntervalUntilBoot),
        generateTextForAdvancedSettings(self)
    )
end

--------------------------------------------------------------------------------
-- The dynamic item generators.
--------------------------------------------------------------------------------
local function createItemsForStateMain(self)
    local mode = self.m_Mode
    if (mode == "modeCreate") then
        return {
            self.m_ItemPlayerIndex,
            self.m_ItemTeamIndex,
            self.m_ItemFogOfWar,
            self.m_ItemRankMatch,
            self.m_ItemIntervalUntilBoot,
            self.m_ItemAdvancedSettings,
        }

    elseif (mode == "modeJoin") then
        local items = {}
        if (#self.m_ItemsForStatePlayerIndex > 1) then
            items[#items + 1] = self.m_ItemPlayerIndex
        end
        if (#self.m_ItemsForStateTeamIndex > 1) then
            items[#items + 1] = self.m_ItemTeamIndex
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
                    setStateMain(self)
                end,
            }
        end
    end

    assert(#items > 0)
    return items
end

local function createItemsForStateTeamIndex(self)
    local warConfiguration   = self.m_WarConfiguration
    local playersCountJoined = 0
    local teamList           = {}
    local teamsCount         = 0

    for playerIndex, playerData in pairs(warConfiguration.players or {}) do
        playersCountJoined  = playersCountJoined + 1

        local teamIndex = playerData.teamIndex
        if (teamList[teamIndex]) then
            teamList[teamIndex] = teamList[teamIndex] + 1
        else
            teamList[teamIndex] = 1
            teamsCount          = teamsCount + 1
        end
    end

    local playersCountTotal = WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName)
    if ((playersCountJoined == playersCountTotal - 1) and (teamsCount == 1)) then
        local teamIndex = getFirstUnusedTeamIndex(warConfiguration)
        return {{
            teamIndex = teamIndex,
            name      = AuxiliaryFunctions.getTeamNameWithTeamIndex(teamIndex),
            callback  = function()
                self.m_TeamIndex = teamIndex
                setStateMain(self)
            end,
        }}
    else
        local items = {}
        for teamIndex = 1, playersCountTotal do
            items[#items + 1] = {
                teamIndex = teamIndex,
                name      = AuxiliaryFunctions.getTeamNameWithTeamIndex(teamIndex),
                callback  = function()
                    self.m_TeamIndex = teamIndex
                    setStateMain(self)
                end,
            }
        end

        return items
    end
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
        teamIndex   = self.m_TeamIndex,
        warID       = self.m_WarConfiguration.warID,
        warPassword = "", -- TODO: self.m_WarPassword,
    })
end

local function sendActionNewWar(self)
    WebSocketManager.sendAction({
        actionCode                = ACTION_CODE_NEW_WAR,
        defaultWeatherCode        = 1, --TODO: add an option for the weather.
        attackModifier            = self.m_AttackModifier,
        energyGainModifier        = self.m_EnergyGainModifier,
        incomeModifier            = self.m_IncomeModifier,
        intervalUntilBoot         = self.m_IntervalUntilBoot,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isRankMatch               = self.m_IsRankMatch,
        maxDiffScore              = self.m_MaxDiffScore,
        moveRangeModifier         = self.m_MoveRangeModifier,
        playerIndex               = self.m_PlayerIndex,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        teamIndex                 = self.m_TeamIndex,
        visionModifier            = self.m_VisionModifier,
        warPassword               = "", -- TODO: self.m_WarPassword,
        warFieldFileName          = self.m_WarConfiguration.warFieldFileName,
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
local function setStateAdvancedSettings(self)
    self.m_State = "stateAdvancedSettings"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Advanced Settings"))
        :setItems(self.m_ItemsForStateAdvancedSettings)
        :setOverviewText(generateOverviewText(self))
end

local function setStateAttackModifier(self)
    self.m_State = "stateAttackModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "AttackModifier"))
        :setItems(self.m_ItemsForStateAttackModifier)
        :setOverviewText(getLocalizedText(35, "HelpForAttackModifier"))
end

local function setStateEnableActiveSkill(self)
    self.m_State = "stateEnableActiveSkill"
    self.m_View:setMenuTitleText(getLocalizedText(14, "EnableActiveSkill"))
        :setItems(self.m_ItemsForStateEnableActiveSkill)
        :setOverviewText(getLocalizedText(35, "HelpForEnableActiveSkill"))
end

local function setStateEnablePassiveSkill(self)
    self.m_State = "stateEnablePassiveSkill"
    self.m_View:setMenuTitleText(getLocalizedText(14, "EnablePassiveSkill"))
        :setItems(self.m_ItemsForStateEnablePassiveSkill)
        :setOverviewText(getLocalizedText(35, "HelpForEnablePassiveSkill"))
end

local function setStateEnergyGainModifier(self)
    self.m_State = "stateEnergyModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Energy Gain Modifier"))
        :setItems(self.m_ItemsForStateEnergyGainModifier)
        :setOverviewText(getLocalizedText(35, "HelpForEnergyGainModifier"))
end

local function setStateFogOfWar(self)
    self.m_State = "stateFogOfWar"
    self.m_View:setMenuTitleText(getLocalizedText(34, "FogOfWar"))
        :setItems(self.m_ItemsForStateFogOfWar)
        :setOverviewText(getLocalizedText(35, "HelpForFogOfWar"))
end

local function setStateIncomeModifier(self)
    self.m_State = "stateIncomeModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Income Modifier"))
        :setItems(self.m_ItemsForStateIncomeModifier)
        :setOverviewText(getLocalizedText(35, "HelpForIncomeModifier"))
end

local function setStateIntervalUntilBoot(self)
    self.m_State = "stateIntervalUntilBoot"
    self.m_View:setMenuTitleText(getLocalizedText(14, "IntervalUntilBoot"))
        :setItems(self.m_ItemsForStateIntervalUntilBoot)
        :setOverviewText(getLocalizedText(35, "HelpForIntervalUntilBoot"))
end

setStateMain = function(self)
    self.m_State = "stateMain"
    self.m_View:setMenuTitleText(self.m_MenuTitleTextForMode)
        :setItems(createItemsForStateMain(self))
        :setOverviewText(generateOverviewText(self))
end

local function setStateMaxDiffScore(self)
    self.m_State = "stateMaxDiffScore"
    self.m_View:setMenuTitleText(getLocalizedText(34, "MaxDiffScore"))
        :setItems(self.m_ItemsForStateMaxDiffScore)
        :setOverviewText(getLocalizedText(35, "HelpForMaxDiffScore"))
end

local function setStateMoveRangeModifier(self)
    self.m_State = "stateMoveRangeModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "MoveRangeModifier"))
        :setItems(self.m_ItemsForStateMoveRangeModifier)
        :setOverviewText(getLocalizedText(35, "HelpForMoveRangeModifier"))
end

local function setStatePlayerIndex(self)
    self.m_State = "statePlayerIndex"
    self.m_View:setMenuTitleText(getLocalizedText(34, "PlayerIndex"))
        :setItems(self.m_ItemsForStatePlayerIndex)
        :setOverviewText(getLocalizedText(35, "HelpForPlayerIndex"))
end

local function setStateRankMatch(self)
    self.m_State = "stateRankMatch"
    self.m_View:setMenuTitleText(getLocalizedText(34, "RankMatch"))
        :setItems(self.m_ItemsForStateRankMatch)
        :setOverviewText(getLocalizedText(35, "HelpForRankMatch"))
end

local function setStateStartingEnergy(self)
    self.m_State = "stateStartingEnergy"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Starting Energy"))
        :setItems(self.m_ItemsForStateStartingEnergy)
        :setOverviewText(getLocalizedText(35, "HelpForStartingEnergy"))
end

local function setStateStartingFund(self)
    self.m_State = "stateStartingFund"
    self.m_View:setMenuTitleText(getLocalizedText(14, "Starting Fund"))
        :setItems(self.m_ItemsForStateStartingFund)
        :setOverviewText(getLocalizedText(35, "HelpForStartingFund"))
end

local function setStateTeamIndex(self)
    self.m_State = "stateTeamIndex"
    self.m_View:setMenuTitleText(getLocalizedText(14, "TeamIndex"))
        :setItems(self.m_ItemsForStateTeamIndex)
        :setOverviewText(getLocalizedText(35, "HelpForTeamIndex"))
end

local function setStateVisionModifier(self)
    self.m_State = "stateVisionModifier"
    self.m_View:setMenuTitleText(getLocalizedText(14, "VisionModifier"))
        :setItems(self.m_ItemsForStateVisionModifier)
        :setOverviewText(getLocalizedText(35, "HelpForVisionModifier"))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemAdvancedSettings(self)
    self.m_ItemAdvancedSettings = {
        name     = getLocalizedText(14, "Advanced Settings"),
        callback = function()
            setStateAdvancedSettings(self)
        end,
    }
end

local function initItemAttackModifier(self)
    self.m_ItemAttackModifier = {
        name     = getLocalizedText(14, "AttackModifier"),
        callback = function()
            setStateAttackModifier(self)
        end,
    }
end

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

local function initItemMoveRangeModifier(self)
    self.m_ItemMoveRangeModifier = {
        name     = getLocalizedText(14, "MoveRangeModifier"),
        callback = function()
            setStateMoveRangeModifier(self)
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

local function initItemStartingFund(self)
    self.m_ItemStartingFund = {
        name     = getLocalizedText(14, "Starting Fund"),
        callback = function()
            setStateStartingFund(self)
        end,
    }
end

local function initItemTeamIndex(self)
    self.m_ItemTeamIndex = {
        name     = getLocalizedText(14, "TeamIndex"),
        callback = function()
            setStateTeamIndex(self)
        end,
    }
end

local function initItemVisionModifier(self)
    self.m_ItemVisionModifier = {
        name     = getLocalizedText(14, "VisionModifier"),
        callback = function()
            setStateVisionModifier(self)
        end,
    }
end

local function initItemsForStateAdvancedSettings(self)
    self.m_ItemsForStateAdvancedSettings = {
        self.m_ItemMaxDiffScore,
        self.m_ItemStartingFund,
        self.m_ItemIncomeModifier,
        self.m_ItemStartingEnergy,
        self.m_ItemEnergyModifier,
        self.m_ItemEnablePassiveSkill,
        self.m_ItemEnableActiveSkill,
        self.m_ItemMoveRangeModifier,
        self.m_ItemAttackModifier,
        self.m_ItemVisionModifier,
    }
end

local function initItemsForStateAttackModifier(self)
    local items = {}
    for modifier = 30, -30, -30 do
        items[#items + 1] = {
            name     = "" .. modifier .. "%",
            callback = function()
                self.m_AttackModifier = modifier
                setStateMain(self)
            end,
        }
    end

    self.m_ItemsForStateAttackModifier = items
end

local function initItemsForStateEnableActiveSkill(self)
    self.m_ItemsForStateEnableActiveSkill = {
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsActiveSkillEnabled = true
                setStateMain(self)
            end,
        },
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsActiveSkillEnabled = false
                setStateMain(self)
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
                setStateMain(self)
            end,
        },
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsPassiveSkillEnabled = false
                setStateMain(self)
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
                setStateMain(self)
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

                setStateMain(self)
            end,
        },
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsFogOfWarByDefault = true

                setStateMain(self)
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
                setStateMain(self)
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

                setStateMain(self)
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

                setStateMain(self)
            end,
        }
    end
    items[#items + 1] = {
        name     = getLocalizedText(14, "NoLimit"),
        callback = function()
            self.m_MaxDiffScore = nil

            setStateMain(self)
        end,
    }

    self.m_ItemsForStateMaxDiffScore = items
end

local function initItemsForStateMoveRangeModifier(self)
    local items = {}
    for modifier = 1, -1, -1 do
        items[#items + 1] = {
            name     = "" .. modifier,
            callback = function()
                self.m_MoveRangeModifier = modifier
                setStateMain(self)
            end,
        }
    end

    self.m_ItemsForStateMoveRangeModifier = items
end

local function initItemsForStateRankMatch(self)
    self.m_ItemsForStateRankMatch = {
        {
            name     = getLocalizedText(14, "No"),
            callback = function()
                self.m_IsRankMatch = false

                setStateMain(self)
            end,
        },
        {
            name     = getLocalizedText(14, "Yes"),
            callback = function()
                self.m_IsRankMatch = true

                setStateMain(self)
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
                setStateMain(self)
            end
        }
    end

    self.m_ItemsForStateStartingEnergy = items
end

local function initItemsForStateStartingFund(self)
    local items = {}
    for _, fund in ipairs(STARTING_FUNDS) do
        items[#items + 1] = {
            name     = (fund ~= 0) and ("" .. fund) or (string.format("%d(%s)", fund, getLocalizedText(14, "Default"))),
            callback = function()
                self.m_StartingFund = fund
                setStateMain(self)
            end
        }
    end

    self.m_ItemsForStateStartingFund = items
end

local function initItemsForStateVisionModifier(self)
    local items = {}
    for modifier = 1, -1, -1 do
        items[#items + 1] = {
            name     = "" .. modifier,
            callback = function()
                self.m_VisionModifier = modifier
                setStateMain(self)
            end
        }
    end

    self.m_ItemsForStateVisionModifier = items
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarConfigurator:ctor()
    initItemAdvancedSettings(      self)
    initItemAttackModifier(        self)
    initItemEnableActiveSkill(     self)
    initItemEnablePassiveSkill(    self)
    initItemEnergyGainModifier(    self)
    initItemFogOfWar(              self)
    initItemIncomeModifier(        self)
    initItemIntervalUntilBoot(     self)
    initItemMaxDiffScore(          self)
    initItemMoveRangeModifier(     self)
    initItemPlayerIndex(           self)
    initItemPlaceHolder(           self)
    initItemRankMatch(             self)
    initItemStartingEnergy(        self)
    initItemStartingFund(          self)
    initItemTeamIndex(             self)
    initItemVisionModifier(        self)

    initItemsForStateAdvancedSettings(      self)
    initItemsForStateAttackModifier(        self)
    initItemsForStateEnableActiveSkill(     self)
    initItemsForStateEnablePassiveSkill(    self)
    initItemsForStateEnergyGainModifier(    self)
    initItemsForStateFogOfWar(              self)
    initItemsForStateIncomeModifier(        self)
    initItemsForStateIntervalUntilBoot(     self)
    initItemsForStateMaxDiffScore(          self)
    initItemsForStateMoveRangeModifier(     self)
    initItemsForStateRankMatch(             self)
    initItemsForStateStartingEnergy(        self)
    initItemsForStateStartingFund(          self)
    initItemsForStateVisionModifier(        self)

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
        self.m_AttackModifier            = 0
        self.m_EnergyGainModifier        = 100
        self.m_IncomeModifier            = 100
        self.m_IntervalUntilBoot         = 3600 * 24 * 3
        self.m_IsActiveSkillEnabled      = true
        self.m_IsFogOfWarByDefault       = false
        self.m_IsPassiveSkillEnabled     = true
        self.m_IsRankMatch               = false
        self.m_ItemsForStatePlayerIndex  = createItemsForStatePlayerIndex(self)
        self.m_ItemsForStateTeamIndex    = createItemsForStateTeamIndex(self)
        self.m_MaxDiffScore              = 100
        self.m_MoveRangeModifier         = 0
        self.m_PlayerIndex               = 1
        self.m_StartingEnergy            = 0
        self.m_StartingFund              = 0
        self.m_TeamIndex                 = 1
        self.m_VisionModifier            = 0

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmCreateWar"))

    elseif (mode == "modeJoin") then
        self.m_AttackModifier            = warConfiguration.attackModifier
        self.m_EnergyGainModifier        = warConfiguration.energyGainModifier
        self.m_IncomeModifier            = warConfiguration.incomeModifier
        self.m_IntervalUntilBoot         = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled      = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault       = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled     = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch               = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex  = createItemsForStatePlayerIndex(self)
        self.m_ItemsForStateTeamIndex    = createItemsForStateTeamIndex(self)
        self.m_MaxDiffScore              = warConfiguration.maxDiffScore
        self.m_MoveRangeModifier         = warConfiguration.moveRangeModifier
        self.m_PlayerIndex               = self.m_ItemsForStatePlayerIndex[1].playerIndex
        self.m_StartingEnergy            = warConfiguration.startingEnergy
        self.m_StartingFund              = warConfiguration.startingFund
        self.m_TeamIndex                 = getFirstUnusedTeamIndex(warConfiguration)
        self.m_VisionModifier            = warConfiguration.visionModifier

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmJoinWar"))

    elseif (mode == "modeContinue") then
        self.m_AttackModifier            = warConfiguration.attackModifier
        self.m_EnergyGainModifier        = warConfiguration.energyGainModifier
        self.m_IncomeModifier            = warConfiguration.incomeModifier
        self.m_IntervalUntilBoot         = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled      = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault       = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled     = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch               = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex  = nil
        self.m_ItemsForStateTeamIndex    = nil
        self.m_MaxDiffScore              = warConfiguration.maxDiffScore
        self.m_MoveRangeModifier         = warConfiguration.moveRangeModifier
        self.m_PlayerIndex               = getPlayerIndexForWarConfiguration(warConfiguration)
        self.m_StartingEnergy            = warConfiguration.startingEnergy
        self.m_StartingFund              = warConfiguration.startingFund
        self.m_TeamIndex                 = getTeamIndexForWarConfiguration(warConfiguration)
        self.m_VisionModifier            = warConfiguration.visionModifier

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmContinueWar"))

    elseif (mode == "modeExit") then
        self.m_AttackModifier            = warConfiguration.attackModifier
        self.m_EnergyGainModifier        = warConfiguration.energyGainModifier
        self.m_IncomeModifier            = warConfiguration.incomeModifier
        self.m_IntervalUntilBoot         = warConfiguration.intervalUntilBoot
        self.m_IsActiveSkillEnabled      = warConfiguration.isActiveSkillEnabled
        self.m_IsFogOfWarByDefault       = warConfiguration.isFogOfWarByDefault
        self.m_IsPassiveSkillEnabled     = warConfiguration.isPassiveSkillEnabled
        self.m_IsRankMatch               = warConfiguration.isRankMatch
        self.m_ItemsForStatePlayerIndex  = nil
        self.m_ItemsForStateTeamIndex    = nil
        self.m_MaxDiffScore              = warConfiguration.maxDiffScore
        self.m_MoveRangeModifier         = warConfiguration.moveRangeModifier
        self.m_PlayerIndex               = getPlayerIndexForWarConfiguration(warConfiguration)
        self.m_StartingEnergy            = warConfiguration.startingEnergy
        self.m_StartingFund              = warConfiguration.startingFund
        self.m_TeamIndex                 = getTeamIndexForWarConfiguration(warConfiguration)
        self.m_VisionModifier            = warConfiguration.visionModifier

        self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmExitWar"))

    else
        error("ModelWarConfigurator:resetWithWarConfiguration() the mode of the configurator is invalid: " .. (mode or ""))
    end

    setStateMain(self)

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
    local state = self.m_State
    if     (state == "stateAdvancedSettings")       then setStateMain(self)
    elseif (state == "stateAttackModifier")         then setStateAdvancedSettings(self)
    elseif (state == "stateEnableActiveSkill")      then setStateAdvancedSettings(self)
    elseif (state == "stateEnablePassiveSkill")     then setStateAdvancedSettings(self)
    elseif (state == "stateEnergyModifier")         then setStateAdvancedSettings(self)
    elseif (state == "stateFogOfWar")               then setStateMain(self)
    elseif (state == "stateIncomeModifier")         then setStateAdvancedSettings(self)
    elseif (state == "stateIntervalUntilBoot")      then setStateMain(self)
    elseif (state == "stateMaxDiffScore")           then setStateAdvancedSettings(self)
    elseif (state == "stateMoveRangeModifier")      then setStateAdvancedSettings(self)
    elseif (state == "statePlayerIndex")            then setStateMain(self)
    elseif (state == "stateRankMatch")              then setStateMain(self)
    elseif (state == "stateStartingEnergy")         then setStateAdvancedSettings(self)
    elseif (state == "stateStartingFund")           then setStateAdvancedSettings(self)
    elseif (state == "stateTeamIndex")              then setStateMain(self)
    elseif (state == "stateVisionModifier")         then setStateAdvancedSettings(self)
    elseif (self.m_OnButtonBackTouched)             then self.m_OnButtonBackTouched()
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
