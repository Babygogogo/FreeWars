
local ModelWarNative = requireFW("src.global.functions.class")("ModelWarNative")

local ActionCodeFunctions		= requireFW("src.app.utilities.ActionCodeFunctions")
local ActionExecutorForWarNative = requireFW("src.app.utilities.actionExecutors.ActionExecutorForWarNative")
local ActionTranslatorForNative  = requireFW("src.app.utilities.actionTranslators.ActionTranslatorForNative")
local AudioManager			   = requireFW("src.app.utilities.AudioManager")
local LocalizationFunctions	  = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions	 = requireFW("src.app.utilities.SerializationFunctions")
local TableFunctions			 = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager			= requireFW("src.app.utilities.WarFieldManager")
local Actor					  = requireFW("src.global.actors.Actor")
local EventDispatcher			= requireFW("src.global.events.EventDispatcher")

local assert, ipairs, next	= assert, ipairs, next
local coroutine, cc, math, os = coroutine, cc, math, os
local getLocalizedText		= LocalizationFunctions.getLocalizedText

local ACTION_CODES			  = ActionCodeFunctions.getFullList()
local ACTION_CODE_BEGIN_TURN	= ActionCodeFunctions.getActionCode("ActionBeginTurn")
local TIME_INTERVAL_FOR_ACTIONS = 1

--------------------------------------------------------------------------------
-- The private callback function on web socket events.
--------------------------------------------------------------------------------
local function onWebSocketOpen(self, param)
	print("ModelWarNative-onWebSocketOpen()")
	self:getModelMessageIndicator():showMessage(getLocalizedText(30, "ConnectionEstablished"))
end

local function onWebSocketMessage(self, param)
	--[[
	local action	 = param.action
	local actionCode = action.actionCode
	print(string.format("ModelWarNative-onWebSocketMessage() code: %d  name: %s  length: %d",
		actionCode,
		ActionCodeFunctions.getActionName(actionCode),
		string.len(param.message))
	)
	print(SerializationFunctions.toString(action))
	--]]

	local actionCode = param.action.actionCode
	if ((actionCode == ACTION_CODES.ActionChat)	  or
		(actionCode == ACTION_CODES.ActionLogin)	 or
		(actionCode == ACTION_CODES.ActionLogout)	or
		(actionCode == ACTION_CODES.ActionMessage)   or
		(actionCode == ACTION_CODES.ActionRegister)) then
		ActionExecutorForWarNative.execute(param.action, self)
	end
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

local function initActorWarField(self, warData)
	self.m_ActorWarField = Actor.createWithModelAndViewName("warNative.ModelWarFieldForNative", warData, "common.ViewWarField")
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
	self.m_ActionID					 = warData.actionID
	self.m_AttackModifier			   = warData.attackModifier
	self.m_EnergyGainModifier		   = warData.energyGainModifier
	self.m_IncomeModifier			   = warData.incomeModifier
	self.m_IsActiveSkillEnabled		 = warData.isActiveSkillEnabled
	self.m_IsFogOfWarByDefault		  = warData.isFogOfWarByDefault
	self.m_IsPassiveSkillEnabled		= warData.isPassiveSkillEnabled
	self.m_IsCampaign				   = warData.isCampaign
	self.m_IsWarEnded				   = warData.isWarEnded
	self.m_MoveRangeModifier			= warData.moveRangeModifier
	self.m_SaveIndex					= warData.saveIndex
	self.m_StartingEnergy			   = warData.startingEnergy
	self.m_StartingFund				 = warData.startingFund
	self.m_TotalAttackDamage			= warData.totalAttackDamage			or 0
	self.m_TotalAttacksCount			= warData.totalAttacksCount			or 0
	self.m_TotalBuiltUnitValueForAI	 = warData.totalBuiltUnitValueForAI	 or 0
	self.m_TotalBuiltUnitValueForPlayer = warData.totalBuiltUnitValueForPlayer or 0
	self.m_TotalKillsCount			  = warData.totalKillsCount			  or 0
	self.m_TotalLostUnitValueForPlayer  = warData.totalLostUnitValueForPlayer  or 0
	self.m_VisionModifier			   = warData.visionModifier

	initScriptEventDispatcher(self)
	initActorConfirmBox(	  self)
	initActorMessageIndicator(self)
	initActorRobot(		   self)
	initActorWarHud(		  self)
	initActorPlayerManager(   self, warData.players)
	initActorSkillDataManager(self, warData.skillData)
	initActorTurnManager(	 self, warData.turn)
	initActorWarField(		self, warData)

	return self
end

function ModelWarNative:initView()
	assert(self.m_View, "ModelWarNative:initView() no view is attached to the owner actor of the model.")
	self.m_View:setViewConfirmBox(self.m_ActorConfirmBox	  :getView())
		:setViewWarField(		 self.m_ActorWarField		:getView())
		:setViewWarHud(		   self.m_ActorWarHud		  :getView())
		:setViewTurnManager(	  self.m_ActorTurnManager	 :getView())
		:setViewMessageIndicator( self.m_ActorMessageIndicator:getView())

	return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelWarNative:toSerializableTable()
	return {
		actionID					 = self:getActionId(),
		attackModifier			   = self.m_AttackModifier,
		energyGainModifier		   = self.m_EnergyGainModifier,
		incomeModifier			   = self.m_IncomeModifier,
		isActiveSkillEnabled		 = self.m_IsActiveSkillEnabled,
		isFogOfWarByDefault		  = self.m_IsFogOfWarByDefault,
		isPassiveSkillEnabled		= self.m_IsPassiveSkillEnabled,
		isCampaign				   = self.m_IsCampaign,
		isWarEnded				   = self.m_IsWarEnded,
		moveRangeModifier			= self.m_MoveRangeModifier,
		saveIndex					= self.m_SaveIndex,
		startingEnergy			   = self.m_StartingEnergy,
		startingFund				 = self.m_StartingFund,
		totalAttackDamage			= self.m_TotalAttackDamage,
		totalAttacksCount			= self.m_TotalAttacksCount,
		totalBuiltUnitValueForAI	 = self.m_TotalBuiltUnitValueForAI,
		totalBuiltUnitValueForPlayer = self.m_TotalBuiltUnitValueForPlayer,
		totalKillsCount			  = self.m_TotalKillsCount,
		totalLostUnitValueForPlayer  = self.m_TotalLostUnitValueForPlayer,
		visionModifier			   = self.m_VisionModifier,
		players					  = self:getModelPlayerManager()   :toSerializableTable(),
		skillData					= self:getModelSkillDataManager():toSerializableTable(),
		turn						 = self:getModelTurnManager()	 :toSerializableTable(),
		warField					 = self:getModelWarField()		:toSerializableTable(),
	}
end

--------------------------------------------------------------------------------
-- The callback functions on start/stop running and script events.
--------------------------------------------------------------------------------
function ModelWarNative:onStartRunning()
	local modelTurnManager   = self:getModelTurnManager()
	local modelPlayerManager = self:getModelPlayerManager()
	modelPlayerManager	 :onStartRunning(self)
	modelTurnManager	   :onStartRunning(self)
	self:getModelWarField():onStartRunning(self)
	self:getModelWarHud()  :onStartRunning(self)
	self:getModelRobot()   :onStartRunning(self)

	self.m_PlayerIndexForHuman = modelPlayerManager:getPlayerIndexForHuman()
	if ((modelTurnManager:getTurnIndex() == 1) and (modelTurnManager:isTurnPhaseRequestToBegin())) then
		local func = function(modelUnit)
			if (modelUnit:getPlayerIndex() == self.m_PlayerIndexForHuman) then
				self.m_TotalBuiltUnitValueForPlayer = self.m_TotalBuiltUnitValueForPlayer + modelUnit:getProductionCost()
			else
				self.m_TotalBuiltUnitValueForAI	 = self.m_TotalBuiltUnitValueForAI	 + modelUnit:getProductionCost()
			end
		end
		self:getModelWarField():getModelUnitMap()
			:forEachModelUnitOnMap(func)
			:forEachModelUnitLoaded(func)
	end

	self.m_View:scheduleUpdateWithPriorityLua(function(dt)
		if ((not self:isExecutingAction()) and (not self:isEnded())) then
			if (modelTurnManager:getPlayerIndex() == self.m_PlayerIndexForHuman) then
				if (modelTurnManager:isTurnPhaseRequestToBegin()) then
					self:translateAndExecuteAction({actionCode = ACTION_CODE_BEGIN_TURN})
				end
			else
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

function ModelWarNative:onWebSocketEvent(eventName, param)
	if	 (eventName == "open")	then onWebSocketOpen(   self, param)
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

	ActionExecutorForWarNative.execute(ActionTranslatorForNative.translate(rawAction), self)
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

function ModelWarNative:setSaveIndex(saveIndex)
	self.m_SaveIndex = saveIndex

	return self
end

function ModelWarNative:getAttackModifier()
	return self.m_AttackModifier
end

function ModelWarNative:getTotalAttackDamage()
	return self.m_TotalAttackDamage
end

function ModelWarNative:setTotalAttackDamage(damage)
	self.m_TotalAttackDamage = damage

	return self
end

function ModelWarNative:getTotalAttacksCount()
	return self.m_TotalAttacksCount
end

function ModelWarNative:setTotalAttacksCount(count)
	self.m_TotalAttacksCount = count

	return self
end

function ModelWarNative:getTotalKillsCount()
	return self.m_TotalKillsCount
end

function ModelWarNative:setTotalKillsCount(count)
	self.m_TotalKillsCount = count

	return self
end

function ModelWarNative:getTotalBuiltUnitValueForAi()
	return self.m_TotalBuiltUnitValueForAI
end

function ModelWarNative:setTotalBuiltUnitValueForAi(value)
	self.m_TotalBuiltUnitValueForAI = value

	return self
end

function ModelWarNative:getTotalBuiltUnitValueForPlayer()
	return self.m_TotalBuiltUnitValueForPlayer
end

function ModelWarNative:setTotalBuiltUnitValueForPlayer(value)
	self.m_TotalBuiltUnitValueForPlayer = value

	return self
end

function ModelWarNative:getTotalLostUnitValueForPlayer()
	return self.m_TotalLostUnitValueForPlayer
end

function ModelWarNative:setTotalLostUnitValueForPlayer(value)
	self.m_TotalLostUnitValueForPlayer = value

	return self
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

function ModelWarNative:isCampaign()
	return self.m_IsCampaign
end

function ModelWarNative:getTotalScoreForCampaign()
	return self:getScoreForSpeed() + self:getScoreForPower() + self:getScoreForTechnique()
end

function ModelWarNative:getScoreForPower()
	--[[
	力量分的评判参数是R=「平均伤害值+平均击杀率」，该两个数值均为0-100之间的自然数；
	计算公式为：
	（1）当R≤100时：力量分=max（Rx2-100，0）
	（2）当R≥100时：力量分=min（R，150）
	]]
	local totalAttackDamage = self:getTotalAttackDamage()
	local totalAttacksCount = self:getTotalAttacksCount()
	local totalKillsCount   = self:getTotalKillsCount()
	local averageDamage	 = math.floor(totalAttackDamage	 / math.max(1, totalAttacksCount))
	local averageKills	  = math.floor(totalKillsCount * 100 / math.max(1, totalAttacksCount))
	local reference		 = averageDamage + averageKills
	return (reference >= 100)				and
		(math.min(reference,		   150)) or
		(math.max(reference * 2 - 100, 0))
end

function ModelWarNative:getScoreForSpeed()
	--[[
	速度分的评判参数是R=「实际通关天数/目标天数」，其中目标天数默认为15天，可以人工设定；
	计算公式为：
	（1）当R≤1时：速度分=min（200-Rx100，150）
	（2）当R≥1时：速度分=max（150-Rx50，0）
	]]
	local advancedSettings = WarFieldManager.getWarFieldData(self:getModelWarField():getWarFieldFileName()).advancedSettings or {}
	local targetTurnsCount = advancedSettings.targetTurnsCount or 15
	local currentTurnIndex = self:getModelTurnManager():getTurnIndex()
	return (currentTurnIndex <= targetTurnsCount)									and
		(math.min(math.floor(200 - 100 * currentTurnIndex / targetTurnsCount), 150)) or
		(math.max(math.floor(150 - 50  * currentTurnIndex / targetTurnsCount), 0))
end

function ModelWarNative:getScoreForTechnique()
	--[[
	技术（Technique）
	技术分的评判参数是R=「sqrt（敌总单位价值）/[sqrt（我总单位价值）+sqrt（我损失单位价值）]」
	计算公式为：
	（1）当R≤0.8时：技术分=max（Rx125，0）
	（2）当R≥0.8时：技术分=min（Rx62.5+50，150）
	local builtValueForAi	 = self:getTotalBuiltUnitValueForAi()
	local builtValueForPlayer = self:getTotalBuiltUnitValueForPlayer()
	local lostValueForPlayer  = self:getTotalLostUnitValueForPlayer()
	local reference		   = math.sqrt(builtValueForAi) / (math.max(1, math.sqrt(builtValueForPlayer) + math.sqrt(lostValueForPlayer)))
	return (reference >= 0.8)							  and
		(math.floor(math.min(reference * 62.5 + 50, 150))) or
		(math.floor(math.max(reference * 125,	   0)))
	]]
	--[[
	技术（Technique）
	技术分的评判参数是R = 我损失单位价值 / 敌总单位价值
	令r为地图作者设置的标准值（默认为0.4），则计算公式为：
	score = floor(100 / (R / r))
		  = floor(100 * 0.4 * 敌总价值 / 我损失价值)
	且范围为0~150
	]]
	local builtValueForAi	= self:getTotalBuiltUnitValueForAi()
	local lostValueForPlayer = math.max(self:getTotalLostUnitValueForPlayer(), 1)
	local score			  = math.floor(100 * 0.4 * builtValueForAi / lostValueForPlayer)
	if	 (score > 150) then return 150
	elseif (score < 0)   then return 0
	else					  return score
	end
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
	if (not self.m_IsCampaign) then
		self.m_View:showEffectWin(callback)
	else
		self.m_View:showEffectWinWithScore(callback,
			self:getScoreForSpeed(),
			self:getScoreForPower(),
			self:getScoreForTechnique(),
			self:getModelTurnManager():getTurnIndex()
		)
	end

	return self
end

return ModelWarNative
