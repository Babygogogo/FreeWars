
--[[--------------------------------------------------------------------------------
-- ModelWarOnline是战局场景，同时也是游戏中最重要的场景。
--
-- 主要职责和使用场景举例：
--   维护战局中的所有信息
--
-- 其他：
--  - ModelWarOnline功能很多，因此分成多个不同的子actor来共同工作。目前这些子actor包括：
--    - SceneWarHUD
--    - WarField
--    - PlayerManager
--    - TurnManager
--    - WeatherManager
--
--  - model和view的“时间差”
--    在目前的设计中，一旦收到事件，model将即时完成所有相关计算，而view将随后跨帧显示相应效果。
--    考虑服务器传来“某unit A按某路线移动后对unit B发起攻击”的事件的情况。这种情况下，在model中，unit的新的数值将马上完成结算（如hp，弹药量，消灭与否，等级等都会有更新），
--    但在view不可能立刻按model的新状态进行呈现（否则，玩家就会看到unit发生了瞬移，或是突然消失了），而必须跨帧逐步更新。
--    采取model先行结算的方式可以避免很多问题，所以后续开发应该遵守同样的规范。
--]]--------------------------------------------------------------------------------

local ModelWarOnline = requireFW("src.global.functions.class")("ModelWarOnline")

local ActionCodeFunctions        = requireFW("src.app.utilities.ActionCodeFunctions")
local ActionExecutorForWarOnline = requireFW("src.app.utilities.actionExecutors.ActionExecutorForWarOnline")
local LocalizationFunctions      = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions     = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions             = requireFW("src.app.utilities.TableFunctions")
local Actor                      = requireFW("src.global.actors.Actor")
local EventDispatcher            = requireFW("src.global.events.EventDispatcher")

local IS_SERVER        = requireFW("src.app.utilities.GameConstantFunctions").isServer()
local AudioManager     = (not IS_SERVER) and (requireFW("src.app.utilities.AudioManager"))     or (nil)
local WebSocketManager = (not IS_SERVER) and (requireFW("src.app.utilities.WebSocketManager")) or (nil)

local ipairs, next     = ipairs, next
local getLocalizedText = LocalizationFunctions.getLocalizedText

local IGNORED_KEYS_FOR_EXECUTED_ACTIONS = {"warID", "actionID"}
local TIME_INTERVAL_FOR_ACTIONS         = 1

--------------------------------------------------------------------------------
-- The private callback function on web socket events.
--------------------------------------------------------------------------------
local function onWebSocketOpen(self, param)
    print("ModelWarOnline-onWebSocketOpen()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(30, "ConnectionEstablished"))

    local modelTurnManager = self:getModelTurnManager()
    if ((modelTurnManager:isTurnPhaseRequestToBegin())                                                and
        (modelTurnManager:getPlayerIndex() == self:getModelPlayerManager():getPlayerIndexLoggedIn())) then
        modelTurnManager:runTurn()
    else
        WebSocketManager.sendAction({
            actionCode       = ActionCodeFunctions.getActionCode("ActionSyncSceneWar"),
            actionID         = self:getActionId(),
            warID            = self:getWarId(),
        })
    end
end

local function onWebSocketMessage(self, param)
    ---[[
    local action     = param.action
    local actionCode = action.actionCode
    print(string.format("ModelWarOnline-onWebSocketMessage() code: %d  name: %s  length: %d",
        actionCode,
        ActionCodeFunctions.getActionName(actionCode),
        string.len(param.message))
    )
    print(SerializationFunctions.toString(action))
    --]]

    ActionExecutorForWarOnline.execute(param.action, self)
end

local function onWebSocketClose(self, param)
    print("ModelWarOnline-onWebSocketClose()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(31))
end

local function onWebSocketError(self, param)
    print("ModelWarOnline-onWebSocketError()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(32, param.error))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initScriptEventDispatcher(self)
    self.m_ScriptEventDispatcher = EventDispatcher:create()
end

local function initActorChatManager(self, chatData)
    self.m_ActorChatManager = Actor.createWithModelAndViewName("warOnline.ModelChatManager", chatData, "warOnline.ViewChatManager")
    self.m_ActorChatManager:getModel():setEnabled(false)
end

local function initActorConfirmBox(self)
    local actor = Actor.createWithModelAndViewName("common.ModelConfirmBox", nil, "common.ViewConfirmBox")
    actor:getModel():setEnabled(false)

    self.m_ActorConfirmBox = actor
end

local function initActorMessageIndicator(self)
    self.m_ActorMessageIndicator = Actor.createWithModelAndViewName("common.ModelMessageIndicator", nil, "common.ViewMessageIndicator")
end

local function initActorPlayerManager(self, playersData)
    self.m_ActorPlayerManager = Actor.createWithModelAndViewName("common.ModelPlayerManager", playersData)
end

local function initActorSkillDataManager(self, skillData)
    self.m_ActorSkillDataManager = Actor.createWithModelAndViewName("common.ModelSkillDataManager", skillData)
end

local function initActorWeatherManager(self, weatherData)
    self.m_ActorWeatherManager = Actor.createWithModelAndViewName("common.ModelWeatherManager", weatherData)
end

local function initActorWarField(self, warFieldData)
    self.m_ActorWarField = Actor.createWithModelAndViewName("warOnline.ModelWarFieldForOnline", warFieldData, "common.ViewWarField")
end

local function initActorWarHud(self)
    self.m_ActorWarHud = Actor.createWithModelAndViewName("warOnline.ModelWarHudForOnline", nil, "common.ViewWarHud")
end

local function initActorTurnManager(self, turnData)
    self.m_ActorTurnManager = Actor.createWithModelAndViewName("warOnline.ModelTurnManagerForOnline", turnData, "common.ViewTurnManager")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarOnline:ctor(sceneData)
    self.m_CachedActions             = {}
    self.m_ActionID                  = sceneData.actionID
    self.m_AttackModifier            = sceneData.attackModifier
    self.m_EnergyGainModifier        = sceneData.energyGainModifier
    self.m_EnterTurnTime             = sceneData.enterTurnTime
    self.m_ExecutedActions           = sceneData.executedActions
    self.m_IncomeModifier            = sceneData.incomeModifier
    self.m_IntervalUntilBoot         = sceneData.intervalUntilBoot
    self.m_IsActiveSkillEnabled      = sceneData.isActiveSkillEnabled
    self.m_IsFogOfWarByDefault       = sceneData.isFogOfWarByDefault
    self.m_IsPassiveSkillEnabled     = sceneData.isPassiveSkillEnabled
    self.m_IsRandomWarField          = sceneData.isRandomWarField
    self.m_IsRankMatch               = sceneData.isRankMatch
    self.m_IsSkillDeclarationEnabled = sceneData.isSkillDeclarationEnabled
    self.m_IsWarEnded                = sceneData.isWarEnded
    self.m_MaxBaseSkillPoints        = sceneData.maxBaseSkillPoints
    self.m_MaxDiffScore              = sceneData.maxDiffScore
    self.m_MoveRangeModifier         = sceneData.moveRangeModifier
    self.m_RemainingVotesForDraw     = sceneData.remainingVotesForDraw
    self.m_StartingEnergy            = sceneData.startingEnergy
    self.m_StartingFund              = sceneData.startingFund
    self.m_VisionModifier            = sceneData.visionModifier
    self.m_WarID                     = sceneData.warID
    self.m_WarPassword               = sceneData.warPassword

    initScriptEventDispatcher(self)
    initActorChatManager(     self, sceneData.chatData)
    initActorPlayerManager(   self, sceneData.players)
    initActorSkillDataManager(self, sceneData.skillData)
    initActorWeatherManager(  self, sceneData.weather)
    initActorWarField(        self, sceneData.warField)
    initActorTurnManager(     self, sceneData.turn)

    if (not IS_SERVER) then
        initActorConfirmBox(      self)
        initActorMessageIndicator(self)
        initActorWarHud(          self)
    end

    return self
end

function ModelWarOnline:initView()
    assert(self.m_View, "ModelWarOnline:initView() no view is attached to the owner actor of the model.")
    self.m_View:setViewChatManager(self.m_ActorChatManager     :getView())
        :setViewConfirmBox(        self.m_ActorConfirmBox      :getView())
        :setViewWarField(          self.m_ActorWarField        :getView())
        :setViewWarHud(            self.m_ActorWarHud          :getView())
        :setViewTurnManager(       self.m_ActorTurnManager     :getView())
        :setViewMessageIndicator(  self.m_ActorMessageIndicator:getView())

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarOnline:toSerializableTable()
    return {
        actionID                  = self:getActionId(),
        attackModifier            = self.m_AttackModifier,
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
        maxBaseSkillPoints        = self.m_MaxBaseSkillPoints,
        maxDiffScore              = self.m_MaxDiffScore,
        moveRangeModifier         = self.m_MoveRangeModifier,
        remainingVotesForDraw     = self.m_RemainingVotesForDraw,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        visionModifier            = self.m_VisionModifier,
        warID                     = self.m_WarID,
        warPassword               = self.m_WarPassword,
        chatData                  = self:getModelChatManager()     :toSerializableTable(),
        players                   = self:getModelPlayerManager()   :toSerializableTable(),
        skillData                 = self:getModelSkillDataManager():toSerializableTable(),
        turn                      = self:getModelTurnManager()     :toSerializableTable(),
        warField                  = self:getModelWarField()        :toSerializableTable(),
        weather                   = self:getModelWeatherManager()  :toSerializableTable(),
    }
end

function ModelWarOnline:toSerializableTableForPlayerIndex(playerIndex)
    return {
        actionID                  = self:getActionId(),
        attackModifier            = self.m_AttackModifier,
        energyGainModifier        = self.m_EnergyGainModifier,
        enterTurnTime             = self.m_EnterTurnTime,
        executedActions           = nil,
        incomeModifier            = self.m_IncomeModifier,
        intervalUntilBoot         = self.m_IntervalUntilBoot,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
        isRandomWarField          = self.m_IsRandomWarField,
        isRankMatch               = self.m_IsRankMatch,
        isSkillDeclarationEnabled = self.m_IsSkillDeclarationEnabled,
        isWarEnded                = self.m_IsWarEnded,
        maxBaseSkillPoints        = self.m_MaxBaseSkillPoints,
        maxDiffScore              = self.m_MaxDiffScore,
        moveRangeModifier         = self.m_MoveRangeModifier,
        remainingVotesForDraw     = self.m_RemainingVotesForDraw,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        visionModifier            = self.m_VisionModifier,
        warID                     = self.m_WarID,
        warPassword               = self.m_WarPassword,
        chatData                  = self:getModelChatManager()     :toSerializableTableForPlayerIndex(playerIndex),
        players                   = self:getModelPlayerManager()   :toSerializableTableForPlayerIndex(playerIndex),
        skillData                 = self:getModelSkillDataManager():toSerializableTableForPlayerIndex(),
        turn                      = self:getModelTurnManager()     :toSerializableTableForPlayerIndex(playerIndex),
        warField                  = self:getModelWarField()        :toSerializableTableForPlayerIndex(playerIndex),
        weather                   = self:getModelWeatherManager()  :toSerializableTableForPlayerIndex(playerIndex),
    }
end

function ModelWarOnline:toSerializableReplayData()
    return {
        actionID                  = 0,
        attackModifier            = self.m_AttackModifier,
        energyGainModifier        = self.m_EnergyGainModifier,
        enterTurnTime             = nil,
        executedActions           = self.m_ExecutedActions,
        incomeModifier            = self.m_IncomeModifier,
        intervalUntilBoot         = self.m_IntervalUntilBoot,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
        isRandomWarField          = self.m_IsRandomWarField,
        isRankMatch               = self.m_IsRankMatch,
        isSkillDeclarationEnabled = self.m_IsSkillDeclarationEnabled,
        isWarEnded                = false,
        maxBaseSkillPoints        = self.m_MaxBaseSkillPoints,
        maxDiffScore              = self.m_MaxDiffScore,
        moveRangeModifier         = self.m_MoveRangeModifier,
        remainingVotesForDraw     = nil,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        visionModifier            = self.m_VisionModifier,
        warID                     = self.m_WarID,
        warPassword               = self.m_WarPassword,
        chatData                  = nil,
        players                   = self:getModelPlayerManager()   :toSerializableReplayData(),
        skillData                 = self:getModelSkillDataManager():toSerializableReplayData(),
        turn                      = self:getModelTurnManager()     :toSerializableReplayData(),
        warField                  = self:getModelWarField()        :toSerializableReplayData(),
        weather                   = self:getModelWeatherManager()  :toSerializableReplayData(),
    }
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running and script events.
--------------------------------------------------------------------------------
function ModelWarOnline:onStartRunning(ignoreWarMusic)
    local modelTurnManager = self:getModelTurnManager()
    self:getModelPlayerManager():onStartRunning(self)
    modelTurnManager            :onStartRunning(self)
    self:getModelChatManager()  :onStartRunning(self)
    self:getModelWarField()     :onStartRunning(self)
    if (not IS_SERVER) then
        self:getModelWarHud():onStartRunning(self)
    end

    self:getScriptEventDispatcher():dispatchEvent({name = "EvtSceneWarStarted"})

    modelTurnManager:runTurn()
    if ((not IS_SERVER) and (not ignoreWarMusic)) then
        AudioManager.playRandomWarMusic()
    end

    return self
end

function ModelWarOnline:onStopRunning()
    return self
end

function ModelWarOnline:onWebSocketEvent(eventName, param)
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
function ModelWarOnline:isWarReplay()
    return false
end

function ModelWarOnline:isExecutingAction()
    return self.m_IsExecutingAction
end

function ModelWarOnline:setExecutingAction(executing)
    assert(self.m_IsExecutingAction ~= executing)
    self.m_IsExecutingAction = executing

    if ((not IS_SERVER) and (not executing) and (not self:isEnded())) then
        local actionID = self:getActionId() + 1
        local action   = self.m_CachedActions[actionID]

        if (action) then
            self.m_CachedActions[actionID] = nil
            self.m_IsExecutingAction       = true

            self.m_View:runAction(cc.Sequence:create(
                cc.DelayTime:create(TIME_INTERVAL_FOR_ACTIONS),
                cc.CallFunc:create(function()
                    self.m_IsExecutingAction = false
                    ActionExecutorForWarOnline.execute(action, self)
                end)
            ))
        end
    end

    return self
end

function ModelWarOnline:getActionId()
    return self.m_ActionID
end

function ModelWarOnline:setActionId(actionID)
    self.m_ActionID = actionID

    return self
end

function ModelWarOnline:cacheAction(action)
    local actionID = action.actionID
    assert(not IS_SERVER,                 "ModelWarOnline:cacheAction() this should not happen on the server.")
    assert(actionID > self:getActionId(), "ModelWarOnline:cacheAction() the action to be cached has been executed already.")

    self.m_CachedActions[actionID] = action

    return self
end

function ModelWarOnline:pushBackExecutedAction(action)
    assert(IS_SERVER, "ModelWarOnline:pushBackExecutedAction() should not be invoked on the client.")
    self.m_ExecutedActions[action.actionID] = {
        [ActionCodeFunctions.getActionName(action.actionCode)] = TableFunctions.clone(action, IGNORED_KEYS_FOR_EXECUTED_ACTIONS)
    }

    return self
end

function ModelWarOnline:getWarId()
    return self.m_WarID
end

function ModelWarOnline:getAttackModifier()
    return self.m_AttackModifier
end

function ModelWarOnline:getEnergyGainModifier()
    return self.m_EnergyGainModifier
end

function ModelWarOnline:isActiveSkillEnabled()
    return self.m_IsActiveSkillEnabled
end

function ModelWarOnline:isPassiveSkillEnabled()
    return self.m_IsPassiveSkillEnabled
end

function ModelWarOnline:isSkillDeclarationEnabled()
    return self.m_IsSkillDeclarationEnabled
end

function ModelWarOnline:getIncomeModifier()
    return self.m_IncomeModifier
end

function ModelWarOnline:getIntervalUntilBoot()
    return self.m_IntervalUntilBoot
end

function ModelWarOnline:isFogOfWarByDefault()
    return self.m_IsFogOfWarByDefault
end

function ModelWarOnline:getMoveRangeModifier()
    return self.m_MoveRangeModifier
end

function ModelWarOnline:isRankMatch()
    return self.m_IsRankMatch
end

function ModelWarOnline:getStartingEnergy()
    return self.m_StartingEnergy
end

function ModelWarOnline:getStartingFund()
    return self.m_StartingFund
end

function ModelWarOnline:getVisionModifier()
    return self.m_VisionModifier
end

function ModelWarOnline:getEnterTurnTime()
    return self.m_EnterTurnTime
end

function ModelWarOnline:setEnterTurnTime(time)
    self.m_EnterTurnTime = time

    return self
end

function ModelWarOnline:isEnded()
    return self.m_IsWarEnded
end

function ModelWarOnline:setEnded(ended)
    self.m_IsWarEnded = ended

    return self
end

function ModelWarOnline:getRemainingVotesForDraw()
    return self.m_RemainingVotesForDraw
end

function ModelWarOnline:setRemainingVotesForDraw(votesCount)
    self.m_RemainingVotesForDraw = votesCount

    return self
end

function ModelWarOnline:getModelChatManager()
    return self.m_ActorChatManager:getModel()
end

function ModelWarOnline:getModelConfirmBox()
    return self.m_ActorConfirmBox:getModel()
end

function ModelWarOnline:getModelMessageIndicator()
    return self.m_ActorMessageIndicator:getModel()
end

function ModelWarOnline:getModelTurnManager()
    return self.m_ActorTurnManager:getModel()
end

function ModelWarOnline:getModelPlayerManager()
    return self.m_ActorPlayerManager:getModel()
end

function ModelWarOnline:getModelSkillDataManager()
    return self.m_ActorSkillDataManager:getModel()
end

function ModelWarOnline:getModelWeatherManager()
    return self.m_ActorWeatherManager:getModel()
end

function ModelWarOnline:getModelWarField()
    return self.m_ActorWarField:getModel()
end

function ModelWarOnline:getModelWarHud()
    return self.m_ActorWarHud:getModel()
end

function ModelWarOnline:getScriptEventDispatcher()
    return self.m_ScriptEventDispatcher
end

function ModelWarOnline:showEffectEndWithDraw(callback)
    assert(not IS_SERVER, "ModelWarOnline:showEffectEndWithDraw() should not be invoked on the server.")
    self.m_View:showEffectEndWithDraw(callback)

    return self
end

function ModelWarOnline:showEffectSurrender(callback)
    assert(not IS_SERVER, "ModelWarOnline:showEffectSurrender() should not be invoked on the server.")
    self.m_View:showEffectSurrender(callback)

    return self
end

function ModelWarOnline:showEffectWin(callback)
    assert(not IS_SERVER, "ModelWarOnline:showEffectWin() should not be invoked on the server.")
    self.m_View:showEffectWin(callback)

    return self
end

function ModelWarOnline:showEffectLose(callback)
    assert(not IS_SERVER, "ModelWarOnline:showEffectLose() should not be invoked on the server.")
    self.m_View:showEffectLose(callback)

    return self
end

return ModelWarOnline
