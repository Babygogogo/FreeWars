
local ModelWarNative = requireFW("src.global.functions.class")("ModelWarNative")

local ActionCodeFunctions          = requireFW("src.app.utilities.ActionCodeFunctions")
local ActionExecutorForWarCampaign = requireFW("src.app.utilities.actionExecutors.ActionExecutorForWarCampaign")
local ActionTranslatorForCampaign  = requireFW("src.app.utilities.actionTranslators.ActionTranslatorForCampaign")
local AudioManager                 = requireFW("src.app.utilities.AudioManager")
local LocalizationFunctions        = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions       = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions               = requireFW("src.app.utilities.TableFunctions")
local Actor                        = requireFW("src.global.actors.Actor")
local EventDispatcher              = requireFW("src.global.events.EventDispatcher")

local assert, ipairs, next = assert, ipairs, next
local coroutine, cc, os    = coroutine, cc, os
local getLocalizedText     = LocalizationFunctions.getLocalizedText

local ACTION_CODE_BEGIN_TURN    = ActionCodeFunctions.getActionCode("ActionBeginTurn")
local TIME_INTERVAL_FOR_ACTIONS = 1

--------------------------------------------------------------------------------
-- The private callback function on web socket events.
--------------------------------------------------------------------------------
local function onWebSocketOpen(self, param)
    print("ModelWarNative-onWebSocketOpen()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(30, "ConnectionEstablished"))
end

local function onWebSocketMessage(self, param)
    ---[[
    local action     = param.action
    local actionCode = action.actionCode
    print(string.format("ModelWarNative-onWebSocketMessage() code: %d  name: %s  length: %d",
        actionCode,
        ActionCodeFunctions.getActionName(actionCode),
        string.len(param.message))
    )
    print(SerializationFunctions.toString(action))
    --]]

    ActionExecutorForWarCampaign.execute(param.action, self)
end

local function onWebSocketClose(self, param)
    print("ModelWarNative-onWebSocketClose()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(31))
end

local function onWebSocketError(self, param)
    print("ModelWarNative-onWebSocketError()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(32, param.error))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initScriptEventDispatcher(self)
    self.m_ScriptEventDispatcher = EventDispatcher:create()
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

local function initActorWarField(self, warFieldData)
    self.m_ActorWarField = Actor.createWithModelAndViewName("warNative.ModelWarFieldForNative", warFieldData, "common.ViewWarField")
end

local function initActorRobot(self)
    self.m_ActorRobot = Actor.createWithModelAndViewName("warNative.ModelRobot")
end

local function initActorWarHud(self)
    self.m_ActorWarHud = Actor.createWithModelAndViewName("warNative.ModelWarHudForNative", nil, "common.ViewWarHud")
end

local function initActorTurnManager(self, turnData)
    self.m_ActorTurnManager = Actor.createWithModelAndViewName("warNative.ModelTurnManagerForNative", turnData, "common.ViewTurnManager")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarNative:ctor(warData)
    self.m_ActionID                  = warData.actionID
    self.m_AttackModifier            = warData.attackModifier
    self.m_EnergyGainModifier        = warData.energyGainModifier
    self.m_IncomeModifier            = warData.incomeModifier
    self.m_IsActiveSkillEnabled      = warData.isActiveSkillEnabled
    self.m_IsFogOfWarByDefault       = warData.isFogOfWarByDefault
    self.m_IsPassiveSkillEnabled     = warData.isPassiveSkillEnabled
    self.m_IsScoreGame               = warData.isScoreGame
    self.m_IsSkillDeclarationEnabled = warData.isSkillDeclarationEnabled
    self.m_IsWarEnded                = warData.isWarEnded
    self.m_MoveRangeModifier         = warData.moveRangeModifier
    self.m_SaveIndex                 = warData.saveIndex
    self.m_StartingEnergy            = warData.startingEnergy
    self.m_StartingFund              = warData.startingFund
    self.m_VisionModifier            = warData.visionModifier

    initScriptEventDispatcher(self)
    initActorConfirmBox(      self)
    initActorMessageIndicator(self)
    initActorRobot(           self)
    initActorWarHud(          self)
    initActorPlayerManager(   self, warData.players)
    initActorSkillDataManager(self, warData.skillData)
    initActorTurnManager(     self, warData.turn)
    initActorWarField(        self, warData.warField)

    return self
end

function ModelWarNative:initView()
    assert(self.m_View, "ModelWarNative:initView() no view is attached to the owner actor of the model.")
    self.m_View:setViewConfirmBox(self.m_ActorConfirmBox      :getView())
        :setViewWarField(         self.m_ActorWarField        :getView())
        :setViewWarHud(           self.m_ActorWarHud          :getView())
        :setViewTurnManager(      self.m_ActorTurnManager     :getView())
        :setViewMessageIndicator( self.m_ActorMessageIndicator:getView())

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarNative:toSerializableTable()
    return {
        actionID                  = self:getActionId(),
        attackModifier            = self.m_AttackModifier,
        energyGainModifier        = self.m_EnergyGainModifier,
        incomeModifier            = self.m_IncomeModifier,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
        isScoreGame               = self.m_IsScoreGame,
        isSkillDeclarationEnabled = self.m_IsSkillDeclarationEnabled,
        isWarEnded                = self.m_IsWarEnded,
        moveRangeModifier         = self.m_MoveRangeModifier,
        saveIndex                 = self.m_SaveIndex,
        startingEnergy            = self.m_StartingEnergy,
        startingFund              = self.m_StartingFund,
        visionModifier            = self.m_VisionModifier,
        players                   = self:getModelPlayerManager()   :toSerializableTable(),
        skillData                 = self:getModelSkillDataManager():toSerializableTable(),
        turn                      = self:getModelTurnManager()     :toSerializableTable(),
        warField                  = self:getModelWarField()        :toSerializableTable(),
    }
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running and script events.
--------------------------------------------------------------------------------
function ModelWarNative:onStartRunning()
    local modelTurnManager   = self:getModelTurnManager()
    local modelPlayerManager = self:getModelPlayerManager()
    modelPlayerManager     :onStartRunning(self)
    modelTurnManager       :onStartRunning(self)
    self:getModelWarField():onStartRunning(self)
    self:getModelWarHud()  :onStartRunning(self)
    self:getModelRobot()   :onStartRunning(self)

    self.m_PlayerIndexForHuman = modelPlayerManager:getPlayerIndexForHuman()
    self.m_View:scheduleUpdateWithPriorityLua(function(dt)
        if ((not self:isExecutingAction()) and (not self:isEnded())) then
            if (modelTurnManager:isTurnPhaseRequestToBegin()) then
                self:translateAndExecuteAction({actionCode = ACTION_CODE_BEGIN_TURN})
            elseif (modelTurnManager:getPlayerIndex() ~= self.m_PlayerIndexForHuman) then
                self.m_ThreadForRobot = (self.m_ThreadForRobot) or (coroutine.create(function()
                    return self:getModelRobot():getNextAction()
                end))

                local beginTime = os.clock()
                while ((self.m_ThreadForRobot) and (os.clock() - beginTime <= 0.01)) do
                    local isSuccessful, result = coroutine.resume(self.m_ThreadForRobot)
                    assert(isSuccessful, result)

                    if (result) then
                        self.m_ThreadForRobot = nil
                        self:translateAndExecuteAction(result)
                    end
                end
            end
        end
    end, 0)

    self:getScriptEventDispatcher():dispatchEvent({name = "EvtSceneWarStarted"})
    AudioManager.playRandomWarMusic()

    modelTurnManager:runTurn()

    return self
end

function ModelWarNative:onStopRunning()
    return self
end

function ModelWarNative:onWebSocketEvent(eventName, param)
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
function ModelWarNative.isWarNative()
    return true
end

function ModelWarNative.isWarOnline()
    return false
end

function ModelWarNative.isWarReplay()
    return false
end

function ModelWarNative:translateAndExecuteAction(rawAction)
    assert(not self.m_IsExecutingAction, "ModelWarNative:translateAndExecuteAction() another action is being executed.")
    rawAction.actionID = self.m_ActionID + 1
    rawAction.modelWar = self

    ActionExecutorForWarCampaign.execute(ActionTranslatorForCampaign.translate(rawAction), self)
end

function ModelWarNative:isExecutingAction()
    return self.m_IsExecutingAction
end

function ModelWarNative:setExecutingAction(executing)
    assert(self.m_IsExecutingAction ~= executing)
    self.m_IsExecutingAction = executing

    return self
end

function ModelWarNative:getActionId()
    return self.m_ActionID
end

function ModelWarNative:setActionId(actionID)
    self.m_ActionID = actionID

    return self
end

function ModelWarNative:getSaveIndex()
    return self.m_SaveIndex
end

function ModelWarNative:getAttackModifier()
    return self.m_AttackModifier
end

function ModelWarNative:getEnergyGainModifier()
    return self.m_EnergyGainModifier
end

function ModelWarNative:isActiveSkillEnabled()
    return self.m_IsActiveSkillEnabled
end

function ModelWarNative:isPassiveSkillEnabled()
    return self.m_IsPassiveSkillEnabled
end

function ModelWarNative:isSkillDeclarationEnabled()
    return self.m_IsSkillDeclarationEnabled
end

function ModelWarNative:isScoreGame()
    return self.m_IsScoreGame
end

function ModelWarNative:getIncomeModifier()
    return self.m_IncomeModifier
end

function ModelWarNative:isFogOfWarByDefault()
    return self.m_IsFogOfWarByDefault
end

function ModelWarNative:getMoveRangeModifier()
    return self.m_MoveRangeModifier
end

function ModelWarNative:getStartingEnergy()
    return self.m_StartingEnergy
end

function ModelWarNative:getStartingFund()
    return self.m_StartingFund
end

function ModelWarNative:getVisionModifier()
    return self.m_VisionModifier
end

function ModelWarNative:isEnded()
    return self.m_IsWarEnded
end

function ModelWarNative:setEnded(ended)
    self.m_IsWarEnded = ended

    return self
end

function ModelWarNative:getModelConfirmBox()
    return self.m_ActorConfirmBox:getModel()
end

function ModelWarNative:getModelMessageIndicator()
    return self.m_ActorMessageIndicator:getModel()
end

function ModelWarNative:getModelTurnManager()
    return self.m_ActorTurnManager:getModel()
end

function ModelWarNative:getModelPlayerManager()
    return self.m_ActorPlayerManager:getModel()
end

function ModelWarNative:getModelRobot()
    return self.m_ActorRobot:getModel()
end

function ModelWarNative:getModelSkillDataManager()
    return self.m_ActorSkillDataManager:getModel()
end

function ModelWarNative:getModelWarField()
    return self.m_ActorWarField:getModel()
end

function ModelWarNative:getModelWarHud()
    return self.m_ActorWarHud:getModel()
end

function ModelWarNative:getScriptEventDispatcher()
    return self.m_ScriptEventDispatcher
end

function ModelWarNative:showEffectLose(callback)
    self.m_View:showEffectLose(callback)

    return self
end

function ModelWarNative:showEffectSurrender(callback)
    self.m_View:showEffectSurrender(callback)

    return self
end

function ModelWarNative:showEffectWin(callback)
    self.m_View:showEffectWin(callback)

    return self
end

return ModelWarNative
