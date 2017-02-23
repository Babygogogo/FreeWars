
local ModelMapCursorForReplay = class("ModelMapCursorForReplay")

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters   = requireFW("src.app.utilities.SingletonGetters")
local ComponentManager   = requireFW("src.global.components.ComponentManager")

local DRAG_FIELD_TRIGGER_DISTANCE_SQUARED = 400

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function dispatchEvtMapCursorMoved(self, gridIndex)
    self.m_ScriptEventDispatcher:dispatchEvent({
        name      = "EvtMapCursorMoved",
        gridIndex = gridIndex,
    })
end

local function dispatchEvtGridSelected(self, gridIndex)
    self.m_ScriptEventDispatcher:dispatchEvent({
        name      = "EvtGridSelected",
        gridIndex = gridIndex,
    })
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtGridSelected(self, event)
    self:setGridIndex(event.gridIndex)
end

local function onEvtMapCursorMoved(self, event)
    self:setGridIndex(event.gridIndex)
end

local function onEvtWarStarted(self, event)
    dispatchEvtMapCursorMoved(self, self:getGridIndex())
end

local function setCursorAppearance(self, normalVisible, targetVisible, siloVisible)
    self.m_View:setNormalCursorVisible(normalVisible)
        :setTargetCursorVisible(targetVisible)
        :setSiloCursorVisible(siloVisible)
end

--------------------------------------------------------------------------------
-- The touch/scroll event listeners.
--------------------------------------------------------------------------------
local function createTouchListener(self)
    local isTouchBegan, isTouchMoved, isTouchingCursor
    local initialTouchPosition, initialTouchGridIndex
    local touchListener = cc.EventListenerTouchAllAtOnce:create()

    local function onTouchesBegan(touches, event)
        if (self.m_ModelWarCommandMenu:isEnabled()) then
            return
        end

        isTouchBegan = true
        isTouchMoved = false
        initialTouchPosition = touches[1]:getLocation()
        initialTouchGridIndex = GridIndexFunctions.worldPosToGridIndexInNode(initialTouchPosition, self.m_View)
        isTouchingCursor = GridIndexFunctions.isEqual(initialTouchGridIndex, self:getGridIndex())
    end

    local function onTouchesMoved(touches, event)
        if ((not isTouchBegan)                        or --Sometimes this function is invoked without the onTouchesBegan() being invoked first, so we must do the manual check here.
            (self.m_ModelWarCommandMenu:isEnabled())) then
            return
        end

        local touchesCount = #touches
        isTouchMoved = (isTouchMoved) or
            (touchesCount > 1) or
            (cc.pDistanceSQ(touches[1]:getLocation(), initialTouchPosition) > DRAG_FIELD_TRIGGER_DISTANCE_SQUARED)

        if (touchesCount >= 2) then
            self.m_ScriptEventDispatcher:dispatchEvent({
                name    = "EvtZoomFieldWithTouches",
                touches = touches,
            })
        else
            if (isTouchingCursor) then
                local gridIndex = GridIndexFunctions.worldPosToGridIndexInNode(touches[1]:getLocation(), self.m_View)
                if ((self:isMovableByPlayer())                                        and
                    (GridIndexFunctions.isWithinMap(gridIndex, self.m_MapSize))       and
                    (not GridIndexFunctions.isEqual(gridIndex, self:getGridIndex()))) then
                    dispatchEvtMapCursorMoved(self, gridIndex)
                    isTouchMoved = true
                end
            else
                if (isTouchMoved) then
                    self.m_ScriptEventDispatcher:dispatchEvent({
                        name             = "EvtDragField",
                        previousPosition = touches[1]:getPreviousLocation(),
                        currentPosition  = touches[1]:getLocation()
                    })
                end
            end
        end
    end

    local function onTouchesCancelled(touch, event)
    end

    local function onTouchesEnded(touches, event)
        if ((not isTouchBegan)                        or --Sometimes this function is invoked without the onTouchesBegan() being invoked first, so we must do the manual check here.
            (self.m_ModelWarCommandMenu:isEnabled())) then
            return
        end

        local gridIndex = GridIndexFunctions.worldPosToGridIndexInNode(touches[1]:getLocation(), self.m_View)
        if ((self:isMovableByPlayer()) and (GridIndexFunctions.isWithinMap(gridIndex, self.m_MapSize))) then
            if (not isTouchMoved) then
                dispatchEvtGridSelected(self, gridIndex)
            elseif ((isTouchingCursor) and (not GridIndexFunctions.isEqual(gridIndex, self:getGridIndex()))) then
                dispatchEvtMapCursorMoved(self, gridIndex)
            end
        end
    end

    touchListener:registerScriptHandler(onTouchesBegan,     cc.Handler.EVENT_TOUCHES_BEGAN)
    touchListener:registerScriptHandler(onTouchesMoved,     cc.Handler.EVENT_TOUCHES_MOVED)
    touchListener:registerScriptHandler(onTouchesCancelled, cc.Handler.EVENT_TOUCHES_CANCELLED)
    touchListener:registerScriptHandler(onTouchesEnded,     cc.Handler.EVENT_TOUCHES_ENDED)

    return touchListener
end

local function createMouseListener(self)
    local function onMouseScroll(event)
        self.m_ScriptEventDispatcher:dispatchEvent({
            name        = "EvtZoomFieldWithScroll",
            scrollEvent = event
        })
    end

    local mouseListener = cc.EventListenerMouse:create()
    mouseListener:registerScriptHandler(onMouseScroll, cc.Handler.EVENT_MOUSE_SCROLL)

    return mouseListener
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelMapCursorForReplay:ctor()
    if (not ComponentManager:getComponent(self, "GridIndexable")) then
        ComponentManager.bindComponent(self, "GridIndexable", {instantialData = {x = 1, y = 1}})
    end

    self:setMovableByPlayer(true)

    return self
end

function ModelMapCursorForReplay:initView()
    local view = self.m_View
    assert(view, "ModelMapCursorForReplay:initView() no view is attached to the owner actor of the model.")

    self:setViewPositionWithGridIndex()
    view:setTouchListener(createTouchListener(self))
        :setMouseListener(createMouseListener(self))

        :setNormalCursorVisible(true)
        :setTargetCursorVisible(false)
        :setSiloCursorVisible(  false)

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on script events.
--------------------------------------------------------------------------------
function ModelMapCursorForReplay:onStartRunning(modelWarReplay)
    self.m_MapSize               = SingletonGetters.getModelTileMap(modelWarReplay):getMapSize()
    self.m_ModelWarCommandMenu   = SingletonGetters.getModelWarCommandMenu(modelWarReplay)
    self.m_ScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher(modelWarReplay)

    self.m_ScriptEventDispatcher
        :addEventListener("EvtGridSelected",      self)
        :addEventListener("EvtMapCursorMoved",    self)
        :addEventListener("EvtActionPlannerIdle", self)
        :addEventListener("EvtWarStarted",        self)

    return self
end

function ModelMapCursorForReplay:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtGridSelected")      then onEvtGridSelected(   self, event)
    elseif (eventName == "EvtMapCursorMoved")    then onEvtMapCursorMoved( self, event)
    elseif (eventName == "EvtWarStarted")        then onEvtWarStarted(     self, event)
    elseif (eventName == "EvtActionPlannerIdle") then setCursorAppearance(self, true,  false, false)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelMapCursorForReplay:isMovableByPlayer()
    return self.m_IsMovableByPlayer
end

function ModelMapCursorForReplay:setMovableByPlayer(movable)
    self.m_IsMovableByPlayer = movable

    return self
end

function ModelMapCursorForReplay:setNormalCursorVisible(visible)
    self.m_View:setNormalCursorVisible(visible)

    return self
end

function ModelMapCursorForReplay:setTargetCursorVisible(visible)
    self.m_View:setTargetCursorVisible(visible)

    return self
end

function ModelMapCursorForReplay:setSiloCursorVisible(visible)
    self.m_View:setSiloCursorVisible(visible)

    return self
end

return ModelMapCursorForReplay
