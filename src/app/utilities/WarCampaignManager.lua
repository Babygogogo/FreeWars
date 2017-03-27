
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
    local data = {playerIndex = generateSinglePlayerData("Player", playerIndex, 1, startingEnergy, startingFund)}
    for i = 1, WarFieldManager.getPlayersCount(warFieldFileName) do
        data[i] = data[i] or generateSinglePlayerData("A.I.", i, 2, startingEnergy, startingFund)
    end

    return data
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function WarCampaignManager.generateInitialCampaignData(campaignConfiguration)
    local playerIndex      = param.playerIndex
    local warFieldFileName = param.warFieldFileName
    return {
        actionID                  = 0,
        attackModifier            = param.attackModifier,
        energyGainModifier        = param.energyGainModifier,
        incomeModifier            = param.incomeModifier,
        isActiveSkillEnabled      = param.isActiveSkillEnabled,
        isFogOfWarByDefault       = param.isFogOfWarByDefault,
        isPassiveSkillEnabled     = param.isPassiveSkillEnabled,
        isSkillDeclarationEnabled = param.isSkillDeclarationEnabled,
        isWarEnded                = false,
        moveRangeModifier         = param.moveRangeModifier,
        saveIndex                 = param.saveIndex,
        startingEnergy            = param.startingEnergy,
        startingFund              = param.startingFund,
        visionModifier            = param.visionModifier,

        players  = generatePlayersData(warFieldFileName, playerIndex, param.startingEnergy, param.startingFund),
        turn     = TableFunctions.clone(DEFAULT_TURN_DATA),
        warField = {warFieldFileName = warFieldFileName},
    }
end

return WarCampaignManager
