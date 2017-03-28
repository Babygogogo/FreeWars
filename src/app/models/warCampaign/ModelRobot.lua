
local ModelRobot = requireFW("src.global.functions.class")("ModelRobot")

local ActionCodeFunctions = requireFW("src.app.utilities.ActionCodeFunctions")
local SingletonGetters    = requireFW("src.app.utilities.SingletonGetters")

local assert = assert

local ACTION_CODES = ActionCodeFunctions.getFullList()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelRobot:ctor()
    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running.
--------------------------------------------------------------------------------
function ModelRobot:onStartRunning(modelWar)
    self.m_ModelWar            = modelWar
    self.m_ModelPlayerManager  = SingletonGetters.getModelPlayerManager(modelWar)
    self.m_ModelTurnManager    = SingletonGetters.getModelTurnManager(modelWar)
    self.m_PlayerIndexForHuman = self.m_ModelPlayerManager:getPlayerIndexForHuman()

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelRobot:getNextAction()
    print("ModelRobot:getNextAction()")
    local modelTurnManager = self.m_ModelTurnManager
    assert((modelTurnManager:getPlayerIndex() ~= self.m_PlayerIndexForHuman) and (modelTurnManager:isTurnPhaseMain()))

    return {actionCode = ACTION_CODES.ActionEndTurn}
end

return ModelRobot
