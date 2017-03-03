
local ModelWarReplay = requireFW("src.global.functions.class")("ModelWarReplay")

local ActionCodeFunctions        = requireFW("src.app.utilities.ActionCodeFunctions")
local ActionExecutorForWarReplay = requireFW("src.app.utilities.actionExecutors.ActionExecutorForWarReplay")
local AudioManager               = requireFW("src.app.utilities.AudioManager")
local LocalizationFunctions      = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions     = requireFW("src.app.utilities.SerializationFunctions")
local Actor                      = requireFW("src.global.actors.Actor")
local EventDispatcher            = requireFW("src.global.events.EventDispatcher")

local cc, math, string    = cc, math, string
local ipairs, next, print = ipairs, next, print
local getLocalizedText    = LocalizationFunctions.getLocalizedText

local TIME_INTERVAL_FOR_ACTIONS = 1

--------------------------------------------------------------------------------
-- The private callback function on web socket events.
--------------------------------------------------------------------------------
local function onWebSocketOpen(self, param)
    print("ModelWarReplay-onWebSocketOpen()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(30, "ConnectionEstablished"))
end

local function onWebSocketMessage(self, param)
    local actionCode = param.action.actionCode
    print(string.format("ModelWarReplay-onWebSocketMessage() code: %d  name: %s  length: %d",
        actionCode,
        ActionCodeFunctions.getActionName(actionCode),
        string.len(param.message))
    )
    print(SerializationFunctions.toString(param.action))

    ActionExecutorForWarReplay.executeWebAction(param.action, self)
end

local function onWebSocketClose(self, param)
    print("ModelWarReplay-onWebSocketClose()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(31))
end

local function onWebSocketError(self, param)
    print("ModelWarReplay-onWebSocketError()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(32, param.error))
end

--------------------------------------------------------------------------------
-- The private functions for actions.
--------------------------------------------------------------------------------
local function setActionId(self, actionID)
    assert(math.floor(actionID) == actionID, "ModelWarReplay-setActionId() invalid actionID: " .. (actionID or ""))
    self.m_ActionID = actionID
end

local function hasNextReplayAction(self)
    return self.m_ExecutedActions[self:getActionId() + 1] ~= nil
end

local function executeNextReplayAction(self)
    assert(not self:isExecutingAction(), "ModelWarReplay-executeNextReplayAction() another action is being executed.")

    self.m_ExecutedActionsCount = self.m_ExecutedActionsCount or #self.m_ExecutedActions
    local actionID  = self:getActionId() + 1
    local _, action = next(self.m_ExecutedActions[actionID])
    if (not action) then
        self:getModelMessageIndicator():showMessage(getLocalizedText(11, "NoMoreReplayActions"))
    else
        self:getModelWarField():getModelActionPlanner():setStateIdle(true)
        self:getModelMessageIndicator():showMessage(string.format("%s: %d / %d (%s)",
            getLocalizedText(11, "Progress"),
            actionID,
            self.m_ExecutedActionsCount,
            getLocalizedText(12, ActionCodeFunctions.getActionName(action.actionCode))
        ))

        setActionId(self, actionID)
        ActionExecutorForWarReplay.executeReplayAction(action, self)
    end

    return self
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initScriptEventDispatcher(self)
    self.m_ScriptEventDispatcher = EventDispatcher:create()
end

local function initActorConfirmBox(self)
    if (not self.m_ActorConfirmBox) then
        local actor = Actor.createWithModelAndViewName("common.ModelConfirmBox", nil, "common.ViewConfirmBox")
        actor:getModel():setEnabled(false)

        self.m_ActorConfirmBox = actor
    end
end

local function initActorMessageIndicator(self)
    if (not self.m_ActorMessageIndicator) then
        self.m_ActorMessageIndicator = Actor.createWithModelAndViewName("common.ModelMessageIndicator", nil, "common.ViewMessageIndicator")
    end
end

local function initActorPlayerManager(self, playersData)
    if (not self.m_ActorPlayerManager) then
        self.m_ActorPlayerManager = Actor.createWithModelAndViewName("common.ModelPlayerManager", playersData)
    else
        self.m_ActorPlayerManager:getModel():ctor(playersData)
    end
end

local function initActorSkillDataManager(self, skillData)
    if (not self.m_ActorSkillDataManager) then
        self.m_ActorSkillDataManager = Actor.createWithModelAndViewName("common.ModelSkillDataManager", skillData)
    end
end

local function initActorWeatherManager(self, weatherData)
    if (not self.m_ActorWeatherManager) then
        self.m_ActorWeatherManager = Actor.createWithModelAndViewName("common.ModelWeatherManager", weatherData)
    else
        self.m_ActorWeatherManager:getModel():ctor(weatherData)
    end
end

local function initActorWarField(self, warFieldData)
    if (not self.m_ActorWarField) then
        self.m_ActorWarField = Actor.createWithModelAndViewName("warReplay.ModelWarFieldForReplay", warFieldData, "common.ViewWarField")
    else
        self.m_ActorWarField:getModel():ctor(warFieldData)
    end
end

local function initActorWarHud(self)
    if (not self.m_ActorWarHud) then
        self.m_ActorWarHud = Actor.createWithModelAndViewName("warReplay.ModelWarHudForReplay", nil, "common.ViewWarHud")
    end
end

local function initActorTurnManager(self, turnData)
    if (not self.m_ActorTurnManager) then
        self.m_ActorTurnManager = Actor.createWithModelAndViewName("warReplay.ModelTurnManagerForReplay", turnData, "common.ViewTurnManager")
    else
        self.m_ActorTurnManager:getModel():ctor(turnData)
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarReplay:ctor(sceneData)
    self.m_EnergyGainModifier         = sceneData.energyGainModifier
    self.m_EnterTurnTime              = sceneData.enterTurnTime
    self.m_ExecutedActions            = sceneData.executedActions
    self.m_IncomeModifier             = sceneData.incomeModifier
    self.m_IntervalUntilBoot          = sceneData.intervalUntilBoot
    self.m_IsActiveSkillEnabled       = sceneData.isActiveSkillEnabled
    self.m_IsFogOfWarByDefault        = sceneData.isFogOfWarByDefault
    self.m_IsPassiveSkillEnabled      = sceneData.isPassiveSkillEnabled
    self.m_IsRandomWarField           = sceneData.isRandomWarField
    self.m_IsRankMatch                = sceneData.isRankMatch
    self.m_IsSkillDeclarationEnabled  = sceneData.isSkillDeclarationEnabled
    self.m_IsWarEnded                 = sceneData.isWarEnded
    self.m_MaxDiffScore               = sceneData.maxDiffScore
    self.m_RemainingVotesForDraw      = sceneData.remainingVotesForDraw
    self.m_StartingEnergy             = sceneData.startingEnergy
    self.m_StartingFund               = sceneData.startingFund
    self.m_WarID                      = sceneData.warID
    self.m_WarPassword                = sceneData.warPassword
    setActionId(self, sceneData.actionID)

    if (self.m_IsSkillDeclarationEnabled == nil) then
        self.m_IsSkillDeclarationEnabled = true
    end

    initScriptEventDispatcher(self)
    initActorPlayerManager(   self, sceneData.players)
    initActorWeatherManager(  self, sceneData.weather)
    initActorWarField(        self, sceneData.warField)
    initActorSkillDataManager(self, sceneData.skillData)
    initActorTurnManager(     self, sceneData.turn)
    initActorConfirmBox(      self)
    initActorMessageIndicator(self)
    initActorWarHud(          self)

    return self
end

function ModelWarReplay:initView()
    assert(self.m_View, "ModelWarReplay:initView() no view is attached to the owner actor of the model.")
    self.m_View:setViewConfirmBox( self.m_ActorConfirmBox      :getView())
        :setViewWarField(          self.m_ActorWarField        :getView())
        :setViewWarHud(            self.m_ActorWarHud          :getView())
        :setViewTurnManager(       self.m_ActorTurnManager     :getView())
        :setViewMessageIndicator(  self.m_ActorMessageIndicator:getView())

    return self
end

function ModelWarReplay:initWarDataForEachTurn()
    assert((not self.m_WarDataForEachTurn) and (self:getActionId() == 0))
    self.m_IsFastExecutingActions = true
    self:onStartRunning(true)

    local modelTurnManager           = self:getModelTurnManager()
    local turnCounter                = 0
    local turnCounterForEachActionID = {[0] = 0}
    local warDataForEachTurn         = {}

    for actionID, wrappedAction in ipairs(self.m_ExecutedActions) do
        if (modelTurnManager:isTurnPhaseRequestToBegin()) then
            turnCounter                              = turnCounter + 1
            warDataForEachTurn[turnCounter]          = self:toSerializableTable()
            turnCounterForEachActionID[actionID - 1] = turnCounterForEachActionID[actionID - 1] + 1
        end
        turnCounterForEachActionID[actionID] = turnCounter

        local _, action = next(wrappedAction)
        setActionId(self, actionID)
        ActionExecutorForWarReplay.executeReplayAction(action, self)
    end

    self.m_IsFastExecutingActions     = false
    self.m_TurnCounterForEachActionID = turnCounterForEachActionID
    self.m_WarDataForEachTurn         = warDataForEachTurn
    self.m_WarDataCount               = #warDataForEachTurn
    self:ctor(warDataForEachTurn[1])

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarReplay:toSerializableTable()
    return {
        actionID                  = self:getActionId(),
        energyGainModifier        = self.m_EnergyGainModifier,
        enterTurnTime             = self.m_EnterTurnTime,
        executedActions           = self.m_ExecutedActions,
        incomeModifier            = self.m_IncomeModifier,
        intervalUntilBoot         = self.m_IntervalUntilBoot,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
        isRandomWarField          = self.m_IsRandomWarField,
        isRankMatch               = self.m_IsRankMatch,
        isSkillDeclarationEnabled = self.m_IsSkillDeclarationEnabled,
        isWarEnded                = self.m_IsWarEnded,
        maxDiffScore              = self.m_MaxDiffScore,
        remainingVotesForDraw     = self.m_RemainingVotesForDraw,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        warID                     = self.m_WarID,
        warPassword               = self.m_WarPassword,
        players                   = self:getModelPlayerManager()   :toSerializableTable(),
        skillData                 = self:getModelSkillDataManager():toSerializableTable(),
        turn                      = self:getModelTurnManager()     :toSerializableTable(),
        warField                  = self:getModelWarField()        :toSerializableTable(),
        weather                   = self:getModelWeatherManager()  :toSerializableTable(),
    }
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running and script events.
--------------------------------------------------------------------------------
function ModelWarReplay:onStartRunning(ignoreWarMusic)
    self:getModelTurnManager()  :onStartRunning(self)
    self:getModelPlayerManager():onStartRunning(self)
    self:getModelWarField()     :onStartRunning(self)
    self:getModelWarHud()       :onStartRunning(self)

    self:getScriptEventDispatcher():dispatchEvent({name = "EvtWarStarted"})

    if (not ignoreWarMusic) then
        AudioManager.playRandomWarMusic()
    end

    return self
end

function ModelWarReplay:onStopRunning()
    return self
end

function ModelWarReplay:onWebSocketEvent(eventName, param)
    if     (eventName == "open")    then onWebSocketOpen(   self, param)
    elseif (eventName == "message") then onWebSocketMessage(self, param)
    elseif (eventName == "close")   then onWebSocketClose(  self, param)
    elseif (eventName == "error")   then onWebSocketError(  self, param)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions/accessors.
--------------------------------------------------------------------------------
function ModelWarReplay.isWarReplay()
    return true
end

function ModelWarReplay:isAutoReplay()
    return self.m_IsAutoReplay
end

function ModelWarReplay:setAutoReplay(isAuto)
    self.m_IsAutoReplay = isAuto

    if ((isAuto) and (not self:isExecutingAction())) then
        executeNextReplayAction(self)
    end

    return self
end

function ModelWarReplay:isExecutingAction()
    return self.m_IsExecutingAction
end

function ModelWarReplay:isFastExecutingActions()
    return self.m_IsFastExecutingActions
end

function ModelWarReplay:canFastForwardForReplay()
    return self.m_TurnCounterForEachActionID[self:getActionId()] < #self.m_WarDataForEachTurn
end

function ModelWarReplay:canFastRewindForReplay()
    return self:getActionId() > 0
end

function ModelWarReplay:fastForwardForReplay()
    self:getModelWarField():getModelActionPlanner():setStateIdle(true)

    local warDataIndex = self.m_TurnCounterForEachActionID[self:getActionId()] + 1
    self:ctor(self.m_WarDataForEachTurn[warDataIndex])
        :onStartRunning(true)

    self.m_IsExecutingAction = false
    self:getModelMessageIndicator():showMessage(string.format("%s: %d/ %d", getLocalizedText(11, "SwitchTurn"), warDataIndex, self.m_WarDataCount))

    return self
end

function ModelWarReplay:fastRewindForReplay()
    self:getModelWarField():getModelActionPlanner():setStateIdle(true)

    local actionID     = self:getActionId()
    local warDataIndex = self.m_TurnCounterForEachActionID[actionID]
    if (warDataIndex > self.m_TurnCounterForEachActionID[actionID - 1]) then
        warDataIndex = warDataIndex - 1
    end

    self.m_IsExecutingAction = false
    self:ctor(self.m_WarDataForEachTurn[warDataIndex])
        :onStartRunning(true)

    self:getModelMessageIndicator():showMessage(string.format("%s: %d/ %d", getLocalizedText(11, "SwitchTurn"), warDataIndex, self.m_WarDataCount))

    return self
end

function ModelWarReplay:setExecutingAction(executing)
    assert(self.m_IsExecutingAction ~= executing)
    self.m_IsExecutingAction = executing

    if ((not executing) and (not self:isEnded()) and (self:isAutoReplay()) and (hasNextReplayAction(self))) then
        self.m_IsExecutingAction = true
        self.m_View:runAction(cc.Sequence:create(
            cc.DelayTime:create(TIME_INTERVAL_FOR_ACTIONS),
            cc.CallFunc:create(function()
                self.m_IsExecutingAction = false
                if (self:isAutoReplay()) then
                    executeNextReplayAction(self)
                end
            end)
        ))
    end

    return self
end

function ModelWarReplay:getActionId()
    return self.m_ActionID
end

function ModelWarReplay:getWarId()
    return self.m_WarID
end

function ModelWarReplay:getEnergyGainModifier()
    return self.m_EnergyGainModifier
end

function ModelWarReplay:isActiveSkillEnabled()
    return self.m_IsActiveSkillEnabled
end

function ModelWarReplay:isPassiveSkillEnabled()
    return self.m_IsPassiveSkillEnabled
end

function ModelWarReplay:isSkillDeclarationEnabled()
    return self.m_IsSkillDeclarationEnabled
end

function ModelWarReplay:getIncomeModifier()
    return self.m_IncomeModifier
end

function ModelWarReplay:getIntervalUntilBoot()
    return self.m_IntervalUntilBoot
end

function ModelWarReplay:isFogOfWarByDefault()
    return self.m_IsFogOfWarByDefault
end

function ModelWarReplay:isRankMatch()
    return self.m_IsRankMatch
end

function ModelWarReplay:getStartingEnergy()
    return self.m_StartingEnergy
end

function ModelWarReplay:getStartingFund()
    return self.m_StartingFund
end

function ModelWarReplay:getEnterTurnTime()
    return self.m_EnterTurnTime
end

function ModelWarReplay:setEnterTurnTime(time)
    self.m_EnterTurnTime = time

    return self
end

function ModelWarReplay:isEnded()
    return self.m_IsWarEnded
end

function ModelWarReplay:setEnded(ended)
    self.m_IsWarEnded = ended

    return self
end

function ModelWarReplay:getRemainingVotesForDraw()
    return self.m_RemainingVotesForDraw
end

function ModelWarReplay:setRemainingVotesForDraw(votesCount)
    self.m_RemainingVotesForDraw = votesCount

    return self
end

function ModelWarReplay:getModelConfirmBox()
    return self.m_ActorConfirmBox:getModel()
end

function ModelWarReplay:getModelMessageIndicator()
    return self.m_ActorMessageIndicator:getModel()
end

function ModelWarReplay:getModelTurnManager()
    return self.m_ActorTurnManager:getModel()
end

function ModelWarReplay:getModelPlayerManager()
    return self.m_ActorPlayerManager:getModel()
end

function ModelWarReplay:getModelSkillDataManager()
    return self.m_ActorSkillDataManager:getModel()
end

function ModelWarReplay:getModelWeatherManager()
    return self.m_ActorWeatherManager:getModel()
end

function ModelWarReplay:getModelWarField()
    return self.m_ActorWarField:getModel()
end

function ModelWarReplay:getModelWarHud()
    return self.m_ActorWarHud:getModel()
end

function ModelWarReplay:getScriptEventDispatcher()
    return self.m_ScriptEventDispatcher
end

function ModelWarReplay:showEffectReplayEnd(callback)
    self.m_View:showEffectReplayEnd(callback)

    return self
end

return ModelWarReplay
