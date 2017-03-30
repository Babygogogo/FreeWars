
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

local function getFilenameWithSaveIndex(saveIndex)
    return CAMPAIGN_DATA_PATH .. saveIndex .. ".spdata"
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
    local filename = getFilenameWithSaveIndex(saveIndex)
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
    local filename = getFilenameWithSaveIndex(campaignData.saveIndex)
    local file     = io.open(filename, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(CAMPAIGN_DATA_PATH)
        file = io.open(filename, "wb")
    end

    file:write(SerializationFunctions.encode("SceneWar", campaignData))
    file:close()
end

return WarCampaignManager
