
--[[--------------------------------------------------------------------------------
-- ModelPlayerManager是战局上的玩家管理器，负责维护玩家列表及在适当时候更新玩家数据。
--
-- 主要职责
--   同上
--
-- 其他：
--  - 本类目前没有对应的view，因为暂时还不用显示。
--]]--------------------------------------------------------------------------------

local ModelPlayerManager = requireFW("src.global.functions.class")("ModelPlayerManager")

local ModelPlayer      = requireFW("src.app.models.common.ModelPlayer")
local SingletonGetters = requireFW("src.app.utilities.SingletonGetters")
local TableFunctions   = requireFW("src.app.utilities.TableFunctions")

local IS_SERVER        = requireFW("src.app.utilities.GameConstantFunctions").isServer()
local WebSocketManager = (not IS_SERVER) and (requireFW("src.app.utilities.WebSocketManager")) or (nil)

local assert, ipairs = assert, ipairs

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelPlayerManager:ctor(param)
    self.m_ModelPlayers = {}
    for i, player in ipairs(param) do
        self.m_ModelPlayers[i] = ModelPlayer:create(player)
    end

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelPlayerManager:toSerializableTable()
    local t = {}
    self:forEachModelPlayer(function(modelPlayer, playerIndex)
        t[playerIndex] = modelPlayer:toSerializableTable()
    end)

    return t
end

function ModelPlayerManager:toSerializableTableForPlayerIndex(playerIndex)
    return self:toSerializableTable()
end

function ModelPlayerManager:toSerializableReplayData()
    local t = {}
    self:forEachModelPlayer(function(modelPlayer, playerIndex)
        t[playerIndex] = modelPlayer:toSerializableReplayData()
    end)

    return t
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function ModelPlayerManager:onStartRunning(modelWar)
    self:forEachModelPlayer(function(modelPlayer)
        modelPlayer:onStartRunning(modelWar)
    end)

    if (not IS_SERVER) then
        if (SingletonGetters.isWarCampaign(modelWar)) then
            self.m_ModelPlayerForHuman, self.m_PlayerIndexForHuman = self:getModelPlayerWithAccount("Player")
        elseif (SingletonGetters.isWarOnline(modelWar)) then
            self.m_ModelPlayerLoggedIn, self.m_PlayerIndexLoggedIn = self:getModelPlayerWithAccount(WebSocketManager.getLoggedInAccountAndPassword())
        end
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelPlayerManager:getModelPlayer(playerIndex)
    return self.m_ModelPlayers[playerIndex]
end

function ModelPlayerManager:getPlayersCount()
    return #self.m_ModelPlayers
end

function ModelPlayerManager:getAlivePlayersCount()
    local count = 0
    for _, modelPlayer in ipairs(self.m_ModelPlayers) do
        if (modelPlayer:isAlive()) then
            count = count + 1
        end
    end

    return count
end

function ModelPlayerManager:getAliveTeamsCount(ignoredPlayerIndex)
    local aliveTeamIndices = {}
    self:forEachModelPlayer(function(modelPlayer, playerIndex)
        if ((modelPlayer:isAlive()) and (playerIndex ~= ignoredPlayerIndex)) then
            aliveTeamIndices[modelPlayer:getTeamIndex()] = true
        end
    end)

    return TableFunctions.getPairsCount(aliveTeamIndices)
end

function ModelPlayerManager:getPlayerIndexLoggedIn()
    assert(self.m_PlayerIndexLoggedIn, "ModelPlayerManager:getPlayerIndexLoggedIn() the index hasn't been initialized yet.")
    return self.m_PlayerIndexLoggedIn, self.m_ModelPlayerLoggedIn
end

function ModelPlayerManager:getPlayerIndexForHuman()
    assert(self.m_PlayerIndexForHuman, "ModelPlayerManager:getPlayerIndexForHuman() the index has not been initialized yet.")
    return self.m_PlayerIndexForHuman, self.m_ModelPlayerForHuman
end

function ModelPlayerManager:getModelPlayerWithAccount(account)
    for playerIndex, modelPlayer in ipairs(self.m_ModelPlayers) do
        if (modelPlayer:getAccount() == account) then
            return modelPlayer, playerIndex
        end
    end

    return nil, nil
end

function ModelPlayerManager:forEachModelPlayer(func)
    for playerIndex, modelPlayer in ipairs(self.m_ModelPlayers) do
        func(modelPlayer, playerIndex)
    end

    return self
end

function ModelPlayerManager:isSameTeamIndex(playerIndex1, playerIndex2)
    if ((playerIndex1 == 0) or (playerIndex2 == 0)) then
        return false
    else
        return self.m_ModelPlayers[playerIndex1]:getTeamIndex() == self.m_ModelPlayers[playerIndex2]:getTeamIndex()
    end
end

return ModelPlayerManager
