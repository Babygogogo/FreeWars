
local WarCampaignManager = {}

local TableFunctions  = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager = requireFW("src.app.utilities.WarFieldManager")

local DEFAULT_TURN_DATA = {
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

return WarCampaignManager
