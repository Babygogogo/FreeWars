
local NativeWarManager = {}

local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions         = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")

local io = io

local PATH_WRITABLE                     = cc.FileUtils:getInstance():getWritablePath() .. "writablePath/"
local WAR_DATA_PATH                     = PATH_WRITABLE .. "nativeWarData/"
local FULL_FILENAME_SCORES_FOR_CAMPAIGN = WAR_DATA_PATH .. "ScoresForCampaign.spdata"
local DEFAULT_TURN_DATA  = {
    turnIndex     = 1,
    playerIndex   = 1,
    turnPhaseCode = 1,
}

local s_IsInitialized = false
local s_ScoresForCampaign

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getDataFilenameWithSaveIndex(saveIndex)
    return WAR_DATA_PATH .. saveIndex .. "_data.spdata"
end

local function getConfigurationFilenameWithSaveIndex(saveIndex)
    return WAR_DATA_PATH .. saveIndex .. "_configuration.spdata"
end

local function generateSinglePlayerData(account, playerIndex, teamIndex, startingEnergy, startingFund)
    return {
        account           = account,
        canActivateSkill  = false,
        energy            = startingEnergy,
        fund              = startingFund,
        isActivatingSkill = false,
        isAlive           = true,
        isSkillDeclared   = false,
        nickname          = account,
        playerIndex       = playerIndex,
        teamIndex         = teamIndex,
    }
end

local function generatePlayersData(warFieldFileName, playerIndex, startingEnergy, startingFund)
    local data = {[playerIndex] = generateSinglePlayerData("Player", playerIndex, 1, startingEnergy, startingFund)}
    for i = 1, WarFieldManager.getPlayersCount(warFieldFileName) do
        data[i] = data[i] or generateSinglePlayerData("A.I.", i, 2, startingEnergy, startingFund)
    end

    return data
end

local function generateWarConfiguration(warData)
    local players = {}
    for playerIndex, player in pairs(warData.players) do
        players[playerIndex] = {
            playerIndex = playerIndex,
            teamIndex   = player.teamIndex,
            account     = player.account,
            nickname    = player.nickname,
        }
    end

    return {
        attackModifier            = warData.attackModifier,
        energyGainModifier        = warData.energyGainModifier,
        incomeModifier            = warData.incomeModifier,
        isActiveSkillEnabled      = warData.isActiveSkillEnabled,
        isFogOfWarByDefault       = warData.isFogOfWarByDefault,
        isPassiveSkillEnabled     = warData.isPassiveSkillEnabled,
        isSkillDeclarationEnabled = warData.isSkillDeclarationEnabled,
        moveRangeModifier         = warData.moveRangeModifier,
        players                   = players,
        saveIndex                 = warData.saveIndex,
        startingEnergy            = warData.startingEnergy,
        startingFund              = warData.startingFund,
        visionModifier            = warData.visionModifier,
        warFieldFileName          = warData.warField.warFieldFileName,
    }
end

local function loadWarConfiguration(saveIndex)
    local file = io.open(getConfigurationFilenameWithSaveIndex(saveIndex), "rb")
    if (not file) then
        return nil
    else
        local encodedData = file:read("*a")
        file:close()
        return SerializationFunctions.decode("WarConfiguration", encodedData)
    end
end

local function saveWarConfiguration(configuration)
    local file = io.open(getConfigurationFilenameWithSaveIndex(configuration.saveIndex), "wb")
    file:write(SerializationFunctions.encode("WarConfiguration", configuration))
    file:close()
end

local function loadScoresForCampaign()
    local file = io.open(FULL_FILENAME_SCORES_FOR_CAMPAIGN, "rb")
    if (not file) then
        return nil
    else
        local scores = SerializationFunctions.decode("ScoresForCampaign", file:read("*a")).list
        file:close()
        return scores
    end
end

local function saveScoresForCampaign(scores)
    local file = io.open(FULL_FILENAME_SCORES_FOR_CAMPAIGN, "wb")
    file:write(SerializationFunctions.encode("ScoresForCampaign", {list = scores}))
    file:close()
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function NativeWarManager.init()
    if (not s_IsInitialized) then
        s_IsInitialized = true

        cc.FileUtils:getInstance():createDirectory(WAR_DATA_PATH)
        s_ScoresForCampaign = loadScoresForCampaign() or {}
    end

    return NativeWarManager
end

function NativeWarManager.createInitialWarData(warConfiguration)
    local warFieldFileName = warConfiguration.warFieldFileName
    return {
        actionID                  = 0,
        attackModifier            = warConfiguration.attackModifier,
        energyGainModifier        = warConfiguration.energyGainModifier,
        incomeModifier            = warConfiguration.incomeModifier,
        isActiveSkillEnabled      = warConfiguration.isActiveSkillEnabled,
        isCampaign                = warConfiguration.isCampaign,
        isFogOfWarByDefault       = warConfiguration.isFogOfWarByDefault,
        isPassiveSkillEnabled     = warConfiguration.isPassiveSkillEnabled,
        isSkillDeclarationEnabled = warConfiguration.isSkillDeclarationEnabled,
        isWarEnded                = false,
        moveRangeModifier         = warConfiguration.moveRangeModifier,
        saveIndex                 = warConfiguration.saveIndex,
        startingEnergy            = warConfiguration.startingEnergy,
        startingFund              = warConfiguration.startingFund,
        visionModifier            = warConfiguration.visionModifier,

        players  = generatePlayersData(warFieldFileName, warConfiguration.playerIndex, warConfiguration.startingEnergy, warConfiguration.startingFund),
        turn     = TableFunctions.clone(DEFAULT_TURN_DATA),
        warField = {warFieldFileName = warFieldFileName},
    }
end

function NativeWarManager.loadWarData(saveIndex)
    local file = io.open(getDataFilenameWithSaveIndex(saveIndex), "rb")
    if (not file) then
        return nil
    else
        local encodedData = file:read("*a")
        file:close()
        return SerializationFunctions.decode("SceneWar", encodedData)
    end
end

function NativeWarManager.saveWarData(warData)
    saveWarConfiguration(generateWarConfiguration(warData))

    local file = io.open(getDataFilenameWithSaveIndex(warData.saveIndex), "wb")
    file:write(SerializationFunctions.encode("SceneWar", warData))
    file:close()

    return NativeWarManager
end

function NativeWarManager.getAllWarConfigurations()
    local configurations = {}
    for saveIndex = 1, 10 do
        configurations[#configurations + 1] = loadWarConfiguration(saveIndex)
    end

    return configurations
end

function NativeWarManager.updateCampaignHighScore(warFieldFileName, score)
    if (s_ScoresForCampaign[warFieldFileName]) then
        s_ScoresForCampaign[warFieldFileName].score = math.max(s_ScoresForCampaign[warFieldFileName].score, score)
    else
        s_ScoresForCampaign[warFieldFileName] = {
            warFieldFileName = warFieldFileName,
            score            = score,
        }
    end
    saveScoresForCampaign(s_ScoresForCampaign)

    return NativeWarManager
end

function NativeWarManager.getCampaignHighScore(warFieldFileName)
    if (not s_ScoresForCampaign[warFieldFileName]) then
        return nil
    else
        return s_ScoresForCampaign[warFieldFileName].score
    end
end

return NativeWarManager
