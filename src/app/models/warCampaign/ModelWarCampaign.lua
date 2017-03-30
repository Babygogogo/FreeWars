
local ModelWarCampaign = requireFW("src.global.functions.class")("ModelWarCampaign")

local ActionCodeFunctions          = requireFW("src.app.utilities.ActionCodeFunctions")
local ActionExecutorForWarCampaign = requireFW("src.app.utilities.actionExecutors.ActionExecutorForWarCampaign")
local ActionTranslatorForCampaign  = requireFW("src.app.utilities.actionTranslators.ActionTranslatorForCampaign")
local AudioManager                 = requireFW("src.app.utilities.AudioManager")
local LocalizationFunctions        = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions       = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions               = requireFW("src.app.utilities.TableFunctions")
local Actor                        = requireFW("src.global.actors.Actor")
local EventDispatcher              = requireFW("src.global.events.EventDispatcher")

local ipairs, next     = ipairs, next
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_BEGIN_TURN    = ActionCodeFunctions.getActionCode("ActionBeginTurn")
local TIME_INTERVAL_FOR_ACTIONS = 1

--------------------------------------------------------------------------------
-- The private callback function on web socket events.
--------------------------------------------------------------------------------
local function onWebSocketOpen(self, param)
    print("ModelWarCampaign-onWebSocketOpen()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(30, "ConnectionEstablished"))
end

local function onWebSocketMessage(self, param)
    ---[[
    local action     = param.action
    local actionCode = action.actionCode
    print(string.format("ModelWarCampaign-onWebSocketMessage() code: %d  name: %s  length: %d",
        actionCode,
        ActionCodeFunctions.getActionName(actionCode),
        string.len(param.message))
    )
    print(SerializationFunctions.toString(action))
    --]]

    ActionExecutorForWarCampaign.execute(param.action, self)
end

local function onWebSocketClose(self, param)
    print("ModelWarCampaign-onWebSocketClose()")
    self:getModelMessageIndicator():showMessage(getLocalizedText(31))
end

local function onWebSocketError(self, param)
    print("ModelWarCampaign-onWebSocketError()")
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
    self.m_ActorWarField = Actor.createWithModelAndViewName("warCampaign.ModelWarFieldForCampaign", warFieldData, "common.ViewWarField")
end

local function initActorRobot(self)
    self.m_ActorRobot = Actor.createWithModelAndViewName("warCampaign.ModelRobot")
end

local function initActorWarHud(self)
    self.m_ActorWarHud = Actor.createWithModelAndViewName("warCampaign.ModelWarHudForCampaign", nil, "common.ViewWarHud")
end

local function initActorTurnManager(self, turnData)
    self.m_ActorTurnManager = Actor.createWithModelAndViewName("warCampaign.ModelTurnManagerForCampaign", turnData, "common.ViewTurnManager")
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarCampaign:ctor(campaignData)
    self.m_ActionID                  = campaignData.actionID
    self.m_AttackModifier            = campaignData.attackModifier
    self.m_EnergyGainModifier        = campaignData.energyGainModifier
    self.m_IncomeModifier            = campaignData.incomeModifier
    self.m_IsActiveSkillEnabled      = campaignData.isActiveSkillEnabled
    self.m_IsFogOfWarByDefault       = campaignData.isFogOfWarByDefault
    self.m_IsPassiveSkillEnabled     = campaignData.isPassiveSkillEnabled
    self.m_IsSkillDeclarationEnabled = campaignData.isSkillDeclarationEnabled
    self.m_IsWarEnded                = campaignData.isWarEnded
    self.m_MoveRangeModifier         = campaignData.moveRangeModifier
    self.m_SaveIndex                 = campaignData.saveIndex
    self.m_StartingEnergy            = campaignData.startingEnergy
    self.m_StartingFund              = campaignData.startingFund
    self.m_VisionModifier            = campaignData.visionModifier

    initScriptEventDispatcher(self)
    initActorConfirmBox(      self)
    initActorMessageIndicator(self)
    initActorRobot(           self)
    initActorWarHud(          self)
    initActorPlayerManager(   self, campaignData.players)
    initActorSkillDataManager(self, campaignData.skillData)
    initActorTurnManager(     self, campaignData.turn)
    initActorWarField(        self, campaignData.warField)

    return self
end

function ModelWarCampaign:initView()
    assert(self.m_View, "ModelWarCampaign:initView() no view is attached to the owner actor of the model.")
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
function ModelWarCampaign:toSerializableTable()
    return {
        actionID                  = self:getActionId(),
        attackModifier            = self.m_AttackModifier,
        energyGainModifier        = self.m_EnergyGainModifier,
        incomeModifier            = self.m_IncomeModifier,
        isActiveSkillEnabled      = self.m_IsActiveSkillEnabled,
        isFogOfWarByDefault       = self.m_IsFogOfWarByDefault,
        isPassiveSkillEnabled     = self.m_IsPassiveSkillEnabled,
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
function ModelWarCampaign:onStartRunning()
    local modelTurnManager   = self:getModelTurnManager()
    local modelPlayerManager = self:getModelPlayerManager()
    modelPlayerManager     :onStartRunning(self)
    modelTurnManager       :onStartRunning(self)
    self:getModelWarField():onStartRunning(self)
    self:getModelWarHud()  :onStartRunning(self)
    self:getModelRobot()   :onStartRunning(self)

    self.m_PlayerIndexForHuman = modelPlayerManager:getPlayerIndexForHuman()
    self.m_View:runAction(cc.RepeatForever:create(cc.Sequence:create(
        cc.DelayTime:create(0.1),
        cc.CallFunc:create(function()
            if ((not self:isExecutingAction()) and (not self:isEnded())) then
                if (modelTurnManager:isTurnPhaseRequestToBegin()) then
                    self:translateAndExecuteAction({actionCode = ACTION_CODE_BEGIN_TURN})
                elseif (modelTurnManager:getPlayerIndex() ~= self.m_PlayerIndexForHuman) then
                    if (self.m_RobotAction) then
                        self:translateAndExecuteAction(self.m_RobotAction)
                        self.m_RobotAction = nil
                    else
                        self.m_RobotAction = coroutine.wrap(function()
                            return self:getModelRobot():getNextAction()
                        end)()
                    end
                end
            end
        end)
    )))

    self:getScriptEventDispatcher():dispatchEvent({name = "EvtSceneWarStarted"})
    AudioManager.playRandomWarMusic()

    modelTurnManager:runTurn()

    return self
end

function ModelWarCampaign:onStopRunning()
    return self
end

function ModelWarCampaign:onWebSocketEvent(eventName, param)
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
function ModelWarCampaign.isWarCampaign()
    return true
end

function ModelWarCampaign.isWarOnline()
    return false
end

function ModelWarCampaign.isWarReplay()
    return false
end

function ModelWarCampaign:translateAndExecuteAction(rawAction)
    assert(not self.m_IsExecutingAction, "ModelWarCampaign:translateAndExecuteAction() another action is being executed.")
    rawAction.actionID = self.m_ActionID + 1
    rawAction.modelWar = self

    ActionExecutorForWarCampaign.execute(ActionTranslatorForCampaign.translate(rawAction), self)
end

function ModelWarCampaign:isExecutingAction()
    return self.m_IsExecutingAction
end

function ModelWarCampaign:setExecutingAction(executing)
    assert(self.m_IsExecutingAction ~= executing)
    self.m_IsExecutingAction = executing

    return self
end

function ModelWarCampaign:getActionId()
    return self.m_ActionID
end

function ModelWarCampaign:setActionId(actionID)
    self.m_ActionID = actionID

    return self
end

function ModelWarCampaign:getSaveIndex()
    return self.m_SaveIndex
end

function ModelWarCampaign:getAttackModifier()
    return self.m_AttackModifier
end

function ModelWarCampaign:getEnergyGainModifier()
    return self.m_EnergyGainModifier
end

function ModelWarCampaign:isActiveSkillEnabled()
    return self.m_IsActiveSkillEnabled
end

function ModelWarCampaign:isPassiveSkillEnabled()
    return self.m_IsPassiveSkillEnabled
end

function ModelWarCampaign:isSkillDeclarationEnabled()
    return self.m_IsSkillDeclarationEnabled
end

function ModelWarCampaign:getIncomeModifier()
    return self.m_IncomeModifier
end

function ModelWarCampaign:isFogOfWarByDefault()
    return self.m_IsFogOfWarByDefault
end

function ModelWarCampaign:getMoveRangeModifier()
    return self.m_MoveRangeModifier
end

function ModelWarCampaign:getStartingEnergy()
    return self.m_StartingEnergy
end

function ModelWarCampaign:getStartingFund()
    return self.m_StartingFund
end

function ModelWarCampaign:getVisionModifier()
    return self.m_VisionModifier
end

function ModelWarCampaign:isEnded()
    return self.m_IsWarEnded
end

function ModelWarCampaign:setEnded(ended)
    self.m_IsWarEnded = ended

    return self
end

function ModelWarCampaign:getModelConfirmBox()
    return self.m_ActorConfirmBox:getModel()
end

function ModelWarCampaign:getModelMessageIndicator()
    return self.m_ActorMessageIndicator:getModel()
end

function ModelWarCampaign:getModelTurnManager()
    return self.m_ActorTurnManager:getModel()
end

function ModelWarCampaign:getModelPlayerManager()
    return self.m_ActorPlayerManager:getModel()
end

function ModelWarCampaign:getModelRobot()
    return self.m_ActorRobot:getModel()
end

function ModelWarCampaign:getModelSkillDataManager()
    return self.m_ActorSkillDataManager:getModel()
end

function ModelWarCampaign:getModelWarField()
    return self.m_ActorWarField:getModel()
end

function ModelWarCampaign:getModelWarHud()
    return self.m_ActorWarHud:getModel()
end

function ModelWarCampaign:getScriptEventDispatcher()
    return self.m_ScriptEventDispatcher
end

function ModelWarCampaign:showEffectLose(callback)
    self.m_View:showEffectLose(callback)

    return self
end

function ModelWarCampaign:showEffectSurrender(callback)
    self.m_View:showEffectSurrender(callback)

    return self
end

function ModelWarCampaign:showEffectWin(callback)
    self.m_View:showEffectWin(callback)

    return self
end

return ModelWarCampaign
