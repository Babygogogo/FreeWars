
local WarCampaignManager = {}

local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions         = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")

local io = io

local WRITABLE_PATH      = cc.FileUtils:getInstance():getWritablePath() .. "writablePath/"
local CAMPAIGN_DATA_PATH = WRITABLE_PATH .. "campaignData/"
local DEFAULT_TURN_DATA  = {
    turnIndex     = 1,
    playerIndex   = 1,
    turnPhaseCode = 1,
}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getDataFilenameWithSaveIndex(saveIndex)
    return CAMPAIGN_DATA_PATH .. saveIndex .. "_data.spdata"
end

local function getConfigurationFilenameWithSaveIndex(saveIndex)
    return CAMPAIGN_DATA_PATH .. saveIndex .. "_configuration.spdata"
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

local function generateCampaignConfiguration(campaignData)
    local players = {}
    for playerIndex, player in pairs(campaignData.players) do
        players[playerIndex] = {
            playerIndex = playerIndex,
            teamIndex   = player.teamIndex,
            account     = player.account,
            nickname    = player.nickname,
        }
    end

    return {
        attackModifier            = campaignData.attackModifier,
        energyGainModifier        = campaignData.energyGainModifier,
        incomeModifier            = campaignData.incomeModifier,
        isActiveSkillEnabled      = campaignData.isActiveSkillEnabled,
        isFogOfWarByDefault       = campaignData.isFogOfWarByDefault,
        isPassiveSkillEnabled     = campaignData.isPassiveSkillEnabled,
        isSkillDeclarationEnabled = campaignData.isSkillDeclarationEnabled,
        moveRangeModifier         = campaignData.moveRangeModifier,
        players                   = players,
        saveIndex                 = campaignData.saveIndex,
        startingEnergy            = campaignData.startingEnergy,
        startingFund              = campaignData.startingFund,
        visionModifier            = campaignData.visionModifier,
        warFieldFileName          = campaignData.warField.warFieldFileName,
    }
end

local function loadCampaignConfiguration(saveIndex)
    local filename = getConfigurationFilenameWithSaveIndex(saveIndex)
    local file     = io.open(filename, "rb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(CAMPAIGN_DATA_PATH)
        file = io.open(filename, "rb")
    end

    if (not file) then
        return nil
    else
        local encodedData = file:read("*a")
        file:close()
        return SerializationFunctions.decode("WarConfiguration", encodedData)
    end
end

local function saveCampaignConfiguration(configuration)
    local filename = getConfigurationFilenameWithSaveIndex(configuration.saveIndex)
    local file     = io.open(filename, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(CAMPAIGN_DATA_PATH)
        file = io.open(filename, "wb")
    end

    file:write(SerializationFunctions.encode("WarConfiguration", configuration))
    file:close()
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function WarCampaignManager.createInitialCampaignData(campaignConfiguration)
    local warFieldFileName = campaignConfiguration.warFieldFileName
    return {
        actionID                  = 0,
        attackModifier            = campaignConfiguration.attackModifier,
        energyGainModifier        = campaignConfiguration.energyGainModifier,
        incomeModifier            = campaignConfiguration.incomeModifier,
        isActiveSkillEnabled      = campaignConfiguration.isActiveSkillEnabled,
        isFogOfWarByDefault       = campaignConfiguration.isFogOfWarByDefault,
        isPassiveSkillEnabled     = campaignConfiguration.isPassiveSkillEnabled,
        isSkillDeclarationEnabled = campaignConfiguration.isSkillDeclarationEnabled,
        isWarEnded                = false,
        moveRangeModifier         = campaignConfiguration.moveRangeModifier,
        saveIndex                 = campaignConfiguration.saveIndex,
        startingEnergy            = campaignConfiguration.startingEnergy,
        startingFund              = campaignConfiguration.startingFund,
        visionModifier            = campaignConfiguration.visionModifier,

        players  = generatePlayersData(warFieldFileName, campaignConfiguration.playerIndex, campaignConfiguration.startingEnergy, campaignConfiguration.startingFund),
        turn     = TableFunctions.clone(DEFAULT_TURN_DATA),
        warField = {warFieldFileName = warFieldFileName},
    }
end

function WarCampaignManager.loadCampaignData(saveIndex)
    local filename = getDataFilenameWithSaveIndex(saveIndex)
    local file     = io.open(filename, "rb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(CAMPAIGN_DATA_PATH)
        file = io.open(filename, "rb")
    end

    if (not file) then
        return nil
    else
        local encodedData = file:read("*a")
        file:close()
        return SerializationFunctions.decode("SceneWar", encodedData)
    end
end

function WarCampaignManager.saveCampaignData(campaignData)
    saveCampaignConfiguration(generateCampaignConfiguration(campaignData))

    local filename = getDataFilenameWithSaveIndex(campaignData.saveIndex)
    local file     = io.open(filename, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(CAMPAIGN_DATA_PATH)
        file = io.open(filename, "wb")
    end

    file:write(SerializationFunctions.encode("SceneWar", campaignData))
    file:close()
end

function WarCampaignManager.getAllCampaignConfigurations()
    local configurations = {}
    for saveIndex = 1, 10 do
        configurations[#configurations + 1] = loadCampaignConfiguration(saveIndex)
    end

    return configurations
end

return WarCampaignManager
