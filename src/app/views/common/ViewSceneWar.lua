
local ViewSceneWar = class("ViewSceneWar", cc.Scene)

local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")

local MESSAGE_INDICATOR_Z_ORDER = 4
local END_WAR_EFFECT_Z_ORDER	= 3
local TURN_MANAGER_Z_ORDER	  = 3
local CONFIRM_BOX_Z_ORDER	   = 2
local CHAT_MANAGER_Z_ORDER	  = 1
local WAR_HUD_Z_ORDER		   = 1
local WAR_FIELD_Z_ORDER		 = 0
local BACKGROUND_Z_ORDER		= -1

local END_WAR_EFFECT_FONT_SIZE		  = 50
local END_WAR_EFFECT_LINE_HEIGHT		= END_WAR_EFFECT_FONT_SIZE / 5 * 8
local END_WAR_EFFECT_WIDTH			  = 500
local END_WAR_EFFECT_HEIGHT			 = END_WAR_EFFECT_LINE_HEIGHT * 2
local END_WAR_EFFECT_START_X			= display.width
local END_WAR_EFFECT_START_Y			= (display.height - END_WAR_EFFECT_HEIGHT) / 2
local END_WAR_EFFECT_MIDDLE_X		   = (display.width  - END_WAR_EFFECT_WIDTH) / 2
local END_WAR_EFFECT_MIDDLE_Y		   = END_WAR_EFFECT_START_Y
local END_WAR_EFFECT_MOVEIN_DURATION	= 0.5
local END_WAR_EFFECT_STAY_DURATION	  = 3
local END_WAR_EFFECT_FONT_NAME		  = "res/fonts/msyhbd.ttc"
local END_WAR_EFFECT_FONT_COLOR		 = {r = 255, g = 255, b = 255}
local END_WAR_EFFECT_FONT_OUTLINE_COLOR = {r = 0, g = 0, b = 0}
local END_WAR_EFFECT_FONT_OUTLINE_WIDTH = math.ceil(END_WAR_EFFECT_FONT_SIZE / 15)

local EFFECT_WIN_WITH_SCORE_FONT_SIZE		  = 25
local EFFECT_WIN_WITH_SCORE_WIDTH			  = 550
local EFFECT_WIN_WITH_SCORE_HEIGHT			 = 200
local EFFECT_WIN_WITH_SCORE_START_X			= display.width
local EFFECT_WIN_WITH_SCORE_START_Y			= (display.height - EFFECT_WIN_WITH_SCORE_HEIGHT) / 2
local EFFECT_WIN_WITH_SCORE_MIDDLE_X		   = (display.width  - EFFECT_WIN_WITH_SCORE_WIDTH)  / 2
local EFFECT_WIN_WITH_SCORE_MIDDLE_Y		   = EFFECT_WIN_WITH_SCORE_START_Y
local EFFECT_WIN_WITH_SCORE_MOVEIN_DURATION	= 0.5
local EFFECT_WIN_WITH_SCORE_STAY_DURATION	  = 3
local EFFECT_WIN_WITH_SCORE_FONT_NAME		  = "res/fonts/msyhbd.ttc"
local EFFECT_WIN_WITH_SCORE_FONT_COLOR		 = {r = 255, g = 255, b = 255}
local EFFECT_WIN_WITH_SCORE_FONT_OUTLINE_COLOR = {r = 0, g = 0, b = 0}
local EFFECT_WIN_WITH_SCORE_FONT_OUTLINE_WIDTH = 2

local getLocalizedText = LocalizationFunctions.getLocalizedText

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initSceneBackground(self)
	local background = cc.Sprite:createWithSpriteFrameName("c04_t01_s02_f01.png")
	background:move(display.center)

	self.m_Background = background
	self:addChild(background, BACKGROUND_Z_ORDER)
end

local function createEndWarEffectMoveInAction(effect, durationForStay)
	local moveIn = cc.EaseSineOut:create(cc.MoveTo:create(END_WAR_EFFECT_MOVEIN_DURATION, {x = END_WAR_EFFECT_MIDDLE_X, y = END_WAR_EFFECT_MIDDLE_Y}))
	local callbackAfterMoveIn = cc.CallFunc:create(function()
		effect.m_IsMoveInFinished = true
	end)
	local delay = cc.DelayTime:create(durationForStay or END_WAR_EFFECT_STAY_DURATION)
	local callbackAfterDelay = cc.CallFunc:create(function()
		if (effect.m_Callback) then
			effect.m_Callback()
			effect.m_Callback = nil
		end
	end)

	return cc.Sequence:create(moveIn, callbackAfterMoveIn, delay, callbackAfterDelay)
end

local function createEndWarEffectBackground()
	local background = cc.Scale9Sprite:createWithSpriteFrameName("c03_t01_s02_f01.png", {x = 4, y = 6, width = 1, height = 1})
	background:ignoreAnchorPointForPosition(true)
		:setContentSize(END_WAR_EFFECT_WIDTH, END_WAR_EFFECT_HEIGHT)

		:setOpacity(180)

	return background
end

local function createBackgroundForEffectWinWithScore()
	local background = cc.Scale9Sprite:createWithSpriteFrameName("c03_t01_s02_f01.png", {x = 4, y = 6, width = 1, height = 1})
	background:ignoreAnchorPointForPosition(true)
		:setContentSize(EFFECT_WIN_WITH_SCORE_WIDTH, EFFECT_WIN_WITH_SCORE_HEIGHT)

		:setOpacity(180)

	return background
end

local function createEndWarEffectLabel(text)
	local label = cc.Label:createWithTTF(text, END_WAR_EFFECT_FONT_NAME, END_WAR_EFFECT_FONT_SIZE)
	label:ignoreAnchorPointForPosition(true)
		:setPosition(5, 5)

		:setDimensions(END_WAR_EFFECT_WIDTH - 10, END_WAR_EFFECT_HEIGHT - 10)
		:setHorizontalAlignment(cc.TEXT_ALIGNMENT_CENTER)
		:setVerticalAlignment(cc.VERTICAL_TEXT_ALIGNMENT_CENTER)

		:setTextColor(END_WAR_EFFECT_FONT_COLOR)
		:enableOutline(END_WAR_EFFECT_FONT_OUTLINE_COLOR, END_WAR_EFFECT_FONT_OUTLINE_WIDTH)

	return label
end

local function createLabelForEffectWinWithScore(scoreForSpeed, scoreForPower, scoreForTechnique, turnIndex)
	local text = string.format("%s\n%s: %d	  %s: %d\n%s: %d	%s: %d	%s: %d",
		getLocalizedText(73, "Win"), getLocalizedText(65, "TotalScore"), scoreForSpeed + scoreForPower + scoreForTechnique,
		getLocalizedText(65, "TurnIndex"),		 turnIndex,
		getLocalizedText(65, "ScoreForSpeed"),	 scoreForSpeed,
		getLocalizedText(65, "ScoreForPower"),	 scoreForPower,
		getLocalizedText(65, "ScoreForTechnique"), scoreForTechnique
	)
	local label = cc.Label:createWithTTF(text, EFFECT_WIN_WITH_SCORE_FONT_NAME, EFFECT_WIN_WITH_SCORE_FONT_SIZE)
	label:ignoreAnchorPointForPosition(true)
		:setPosition(5, 5)

		:setDimensions(EFFECT_WIN_WITH_SCORE_WIDTH - 10, EFFECT_WIN_WITH_SCORE_HEIGHT - 10)
		:setHorizontalAlignment(cc.TEXT_ALIGNMENT_CENTER)
		:setVerticalAlignment(cc.VERTICAL_TEXT_ALIGNMENT_CENTER)

		:setTextColor(EFFECT_WIN_WITH_SCORE_FONT_COLOR)
		:enableOutline(EFFECT_WIN_WITH_SCORE_FONT_OUTLINE_COLOR, EFFECT_WIN_WITH_SCORE_FONT_OUTLINE_WIDTH)

	return label
end

local function createEndWarEffectTouchListener(effect)
	local listener = cc.EventListenerTouchOneByOne:create()
	listener:setSwallowTouches(true)

	listener:registerScriptHandler(function()
		return true
	end, cc.Handler.EVENT_TOUCH_BEGAN)

	listener:registerScriptHandler(function(touch, event)
		if ((effect.m_IsMoveInFinished) and (effect.m_Callback)) then
			effect.m_Callback()
			effect.m_Callback = nil
		end
	end, cc.Handler.EVENT_TOUCH_ENDED)

	return listener
end

local function createEndWarEffect(text, callback)
	local effect = cc.Node:create()
	effect:ignoreAnchorPointForPosition(true)
		:setPosition(END_WAR_EFFECT_START_X, END_WAR_EFFECT_START_Y)

	local background	= createEndWarEffectBackground()
	local label		 = createEndWarEffectLabel(text)
	local touchListener = createEndWarEffectTouchListener(effect)

	effect.m_Callback = callback
	effect:addChild(background)
		:addChild(label)
		:getEventDispatcher():addEventListenerWithSceneGraphPriority(touchListener, effect)

	return effect
end

local function createEffectWinWithScore(callback, scoreForSpeed, scoreForPower, scoreForTechnique, turnIndex)
	local effect = cc.Node:create()
	effect:ignoreAnchorPointForPosition(true)
		:setPosition(END_WAR_EFFECT_START_X, END_WAR_EFFECT_START_Y)

	local background	= createBackgroundForEffectWinWithScore()
	local label		 = createLabelForEffectWinWithScore(scoreForSpeed, scoreForPower, scoreForTechnique, turnIndex)
	local touchListener = createEndWarEffectTouchListener(effect)

	effect.m_Callback = callback
	effect:addChild(background)
		:addChild(label)
		:getEventDispatcher():addEventListenerWithSceneGraphPriority(touchListener, effect)

	return effect
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewSceneWar:ctor(param)
	initSceneBackground(self)

	return self
end

function ViewSceneWar:setViewChatManager(view)
	assert(self.m_ViewChatManager == nil, "ViewSceneWar:setViewChatManager() the view has been set already.")

	self.m_ViewChatManager = view
	self:addChild(view, CHAT_MANAGER_Z_ORDER)

	return self
end

function ViewSceneWar:setViewConfirmBox(view)
	self:addChild(view, CONFIRM_BOX_Z_ORDER)
	return self
end

function ViewSceneWar:setViewWarField(view)
	assert(self.m_ViewWarField == nil, "ViewSceneWar:setViewWarField() the view has been set.")

	self.m_ViewWarField = view
	self:addChild(view, WAR_FIELD_Z_ORDER)

	return self
end

function ViewSceneWar:setViewWarHud(view)
	assert(self.m_ViewWarHud == nil, "ViewSceneWar:setViewWarHud() the view has been set.")

	self.m_ViewWarHud = view
	self:addChild(view, WAR_HUD_Z_ORDER)

	return self
end

function ViewSceneWar:setViewTurnManager(view)
	assert(self.m_ViewTurnManager == nil, "ViewSceneWar:setViewTurnManager() the view has been set.")

	self.m_ViewTurnManager = view
	self:addChild(view, TURN_MANAGER_Z_ORDER)

	return self
end

function ViewSceneWar:setViewMessageIndicator(view)
	assert(self.m_ViewMessageIndicator == nil, "ViewSceneWar:setViewMessageIndicator() the view has been set.")

	self.m_ViewMessageIndicator = view
	self:addChild(view, MESSAGE_INDICATOR_Z_ORDER)

	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewSceneWar:showEffectEndWithDraw(callback)
	local effect = createEndWarEffect(getLocalizedText(73, "Draw"), callback)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect))

	return self
end

function ViewSceneWar:showEffectSurrender(callback)
	local effect = createEndWarEffect(getLocalizedText(73, "Surrender"), callback)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect))

	return self
end

function ViewSceneWar:showEffectWin(callback)
	local effect = createEndWarEffect(getLocalizedText(73, "Win"), callback)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect))

	return self
end

function ViewSceneWar:showEffectWinWithScore(callback, scoreForSpeed, scoreForPower, scoreForTechnique, turnIndex)
	local effect = createEffectWinWithScore(callback, scoreForSpeed, scoreForPower, scoreForTechnique, turnIndex)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect, 15))

	return self
end

function ViewSceneWar:showEffectLose(callback)
	local effect = createEndWarEffect(getLocalizedText(73, "Lose"), callback)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect))

	return self
end

function ViewSceneWar:showEffectReplayEnd(callback)
	local effect = createEndWarEffect(getLocalizedText(73, "ReplayEnd"), callback)
	self:addChild(effect, END_WAR_EFFECT_Z_ORDER)
	effect:runAction(createEndWarEffectMoveInAction(effect))

	return self
end

return ViewSceneWar
