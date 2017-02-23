
local ModelPlayerManagerForReplay = requireFW("src.global.functions.class")("ModelPlayerManagerForReplay")

local ModelPlayer = requireFW("src.app.models.common.ModelPlayer")

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelPlayerManagerForReplay:ctor(param)
    self.m_ModelPlayers = {}
    for i, player in ipairs(param) do
        self.m_ModelPlayers[i] = ModelPlayer:create(player)
    end

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelPlayerManagerForReplay:toSerializableTable()
    local t = {}
    self:forEachModelPlayer(function(modelPlayer, playerIndex)
        t[playerIndex] = modelPlayer:toSerializableTable()
    end)

    return t
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function ModelPlayerManagerForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay = modelWarReplay
    self:forEachModelPlayer(function(modelPlayer)
        modelPlayer:onStartRunning(modelWarReplay)
    end)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelPlayerManagerForReplay:getModelPlayer(playerIndex)
    return self.m_ModelPlayers[playerIndex]
end

function ModelPlayerManagerForReplay:getPlayersCount()
    return #self.m_ModelPlayers
end

function ModelPlayerManagerForReplay:getAlivePlayersCount()
    local count = 0
    for _, modelPlayer in ipairs(self.m_ModelPlayers) do
        if (modelPlayer:isAlive()) then
            count = count + 1
        end
    end

    return count
end

function ModelPlayerManagerForReplay:getModelPlayerWithAccount(account)
    for playerIndex, modelPlayer in ipairs(self.m_ModelPlayers) do
        if (modelPlayer:getAccount() == account) then
            return modelPlayer, playerIndex
        end
    end

    return nil, nil
end

function ModelPlayerManagerForReplay:forEachModelPlayer(func)
    for playerIndex, modelPlayer in ipairs(self.m_ModelPlayers) do
        func(modelPlayer, playerIndex)
    end

    return self
end

return ModelPlayerManagerForReplay
