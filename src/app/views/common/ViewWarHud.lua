
local ViewWarHud = class("ViewWarHud", cc.Node)

local CONFIRM_BOX_Z_ORDER	   = 99
local WAR_COMMAND_MENU_Z_ORDER  = 3
local TILE_DETAIL_Z_ORDER	   = 1
local UNIT_DETAIL_Z_ORDER	   = 1
local REPLAY_CONTROLLER_Z_ORDER = 0
local BATTLE_INFO_Z_ORDER	   = 0
local ACTION_MENU_Z_ORDER	   = 0

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function adjustPositionForSubViews(self, touch)
	self.m_ViewMoneyEnergyInfo:adjustPositionOnTouch(touch)
	self.m_ViewTileInfo	   :adjustPositionOnTouch(touch)
	self.m_ViewUnitInfo	   :adjustPositionOnTouch(touch)

	if (self.m_ViewBattleInfo) then
		self.m_ViewBattleInfo:adjustPositionOnTouch(touch)
	end
	if (self.m_ViewActionMenu) then
		self.m_ViewActionMenu:adjustPositionOnTouch(touch)
	end
	if (self.m_ViewReplayController) then
		self.m_ViewReplayController:adjustPositionOnTouch(touch)
	end
end

--------------------------------------------------------------------------------
-- The touch listener.
--------------------------------------------------------------------------------
local function createTouchListener(self)
	local touchListener = cc.EventListenerTouchOneByOne:create()

	local function onTouchBegan(touch, event)
		adjustPositionForSubViews(self, touch)

		return true
	end

	local function onTouchMoved(touch, event)
		adjustPositionForSubViews(self, touch)
	end

	local function onTouchCancelled(touch, event)
	end

	local function onTouchEnded(touch, event)
		adjustPositionForSubViews(self, touch)
	end

	touchListener:registerScriptHandler(onTouchBegan,	 cc.Handler.EVENT_TOUCH_BEGAN)
	touchListener:registerScriptHandler(onTouchMoved,	 cc.Handler.EVENT_TOUCH_MOVED)
	touchListener:registerScriptHandler(onTouchCancelled, cc.Handler.EVENT_TOUCH_CANCELLED)
	touchListener:registerScriptHandler(onTouchEnded,	 cc.Handler.EVENT_TOUCH_ENDED)

	return touchListener
end

local function initWithTouchListener(self, listener)
	self.m_TouchListener = listener
	self:getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewWarHud:ctor(param)
	initWithTouchListener(self, createTouchListener(self))

	return self
end

function ViewWarHud:setViewMoneyEnergyInfo(view)
	assert(self.m_ViewMoneyEnergyInfo == nil, "ViewWarHud:setViewMoneyEnergyInfo() the view has been set.")

	self.m_ViewMoneyEnergyInfo = view
	self:addChild(view)

	return self
end

function ViewWarHud:setViewWarCommandMenu(view)
	assert(self.m_ViewWarCommandMenu == nil, "ViewWarHud:setViewWarCommandMenu() the view has been set.")

	self.m_ViewWarCommandMenu = view
	self:addChild(view, WAR_COMMAND_MENU_Z_ORDER)

	return self
end

function ViewWarHud:setViewActionMenu(view)
	assert(self.m_ViewActionMenu == nil, "ViewWarHud:setViewActionMenu() the view has been set.")

	self.m_ViewActionMenu = view
	self:addChild(view, ACTION_MENU_Z_ORDER)

	return self
end

function ViewWarHud:setViewTileInfo(view)
	assert(self.m_ViewTileInfo == nil, "ViewWarHud:setViewTileInfo() the view has been set.")

	self.m_ViewTileInfo = view
	self:addChild(view)

	return self
end

function ViewWarHud:setViewTileDetail(view)
	assert(self.m_ViewTileDetail == nil, "ViewWarHud:setViewTileDetail() the view has been set.")

	view:setEnabled(false)
	self.m_ViewTileDetail = view
	self:addChild(view, TILE_DETAIL_Z_ORDER)

	return self
end

function ViewWarHud:setViewUnitInfo(view)
	assert(self.m_ViewUnitInfo == nil, "ViewWarHud:setViewUnitInfo() the view has been set.")

	self.m_ViewUnitInfo = view
	self:addChild(view)

	return self
end

function ViewWarHud:setViewUnitDetail(view)
	assert(self.m_ViewUnitDetail == nil, "ViewWarHud:setViewUnitDetail() the view has been set.")

	view:setEnabled(false)
	self.m_ViewUnitDetail = view
	self:addChild(view, UNIT_DETAIL_Z_ORDER)

	return self
end

function ViewWarHud:setViewBattleInfo(view)
	assert(self.m_ViewBattleInfo == nil, "ViewWarHud:setViewBattleInfo() the view has been set.")

	self.m_ViewBattleInfo = view
	self:addChild(view, BATTLE_INFO_Z_ORDER)

	return self
end

function ViewWarHud:setViewReplayController(view)
	assert(self.m_ViewReplayController == nil, "ViewWarHud:setViewReplayController() the view has been set already.")

	self.m_ViewReplayController = view
	self:addChild(view, REPLAY_CONTROLLER_Z_ORDER)

	return self
end

return ViewWarHud
