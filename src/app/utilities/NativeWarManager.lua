
local NativeWarManager = {}

local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions         = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")

local io = io

local WRITABLE_PATH = cc.FileUtils:getInstance():getWritablePath() .. "writablePath/"
local WAR_DATA_PATH = WRITABLE_PATH .. "campaignData/"
local DEFAULT_TURN_DATA  = {
    turnIndex     = 1,
    playerIndex   = 1,
    turnPhaseCode = 1,
}

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
    local filename = getConfigurationFilenameWithSaveIndex(saveIndex)
    local file     = io.open(filename, "rb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(WAR_DATA_PATH)
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

local function saveWarConfiguration(configuration)
    local filename = getConfigurationFilenameWithSaveIndex(configuration.saveIndex)
    local file     = io.open(filename, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(WAR_DATA_PATH)
        file = io.open(filename, "wb")
    end

    file:write(SerializationFunctions.encode("WarConfiguration", configuration))
    file:close()
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function NativeWarManager.createInitialWarData(warConfiguration)
    local warFieldFileName = warConfiguration.warFieldFileName
    return {
        actionID                  = 0,
        attackModifier            = warConfiguration.attackModifier,
        energyGainModifier        = warConfiguration.energyGainModifier,
        incomeModifier            = warConfiguration.incomeModifier,
        isActiveSkillEnabled      = warConfiguration.isActiveSkillEnabled,
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
    local filename = getDataFilenameWithSaveIndex(saveIndex)
    local file     = io.open(filename, "rb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(WAR_DATA_PATH)
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

function NativeWarManager.saveWarData(warData)
    saveWarConfiguration(generateWarConfiguration(warData))

    local filename = getDataFilenameWithSaveIndex(warData.saveIndex)
    local file     = io.open(filename, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(WAR_DATA_PATH)
        file = io.open(filename, "wb")
    end

    file:write(SerializationFunctions.encode("SceneWar", warData))
    file:close()
end

function NativeWarManager.getAllWarConfigurations()
    local configurations = {}
    for saveIndex = 1, 10 do
        configurations[#configurations + 1] = loadWarConfiguration(saveIndex)
    end

    return configurations
end

return NativeWarManager
