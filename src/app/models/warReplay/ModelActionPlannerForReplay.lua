
local ModelActionPlannerForReplay = class("ModelActionPlannerForReplay")

local AttackableGridListFunctions = requireFW("src.app.utilities.AttackableGridListFunctions")
local GridIndexFunctions          = requireFW("src.app.utilities.GridIndexFunctions")
local ReachableAreaFunctions      = requireFW("src.app.utilities.ReachableAreaFunctions")
local SingletonGetters            = requireFW("src.app.utilities.SingletonGetters")

local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getMoveCost(gridIndex, modelUnit, modelUnitMap, modelTileMap)
    if (not GridIndexFunctions.isWithinMap(gridIndex, modelUnitMap:getMapSize())) then
        return nil
    else
        local existingModelUnit = modelUnitMap:getModelUnit(gridIndex)
        if ((existingModelUnit) and (existingModelUnit:getTeamIndex() ~= modelUnit:getTeamIndex())) then
            return nil
        else
            return modelTileMap:getModelTile(gridIndex):getMoveCostWithModelUnit(modelUnit)
        end
    end
end

--------------------------------------------------------------------------------
-- The set state functions.
--------------------------------------------------------------------------------
local function canSetStatePreviewingAttackableArea(self, gridIndex)
    local modelUnit = getModelUnitMap(self.m_ModelWar):getModelUnit(gridIndex)
    return (modelUnit) and (modelUnit.getAttackRangeMinMax)
end

local function setStatePreviewingAttackableArea(self, gridIndex)
    self.m_State = "previewingAttackableArea"
    local modelUnit = getModelUnitMap(self.m_ModelWar):getModelUnit(gridIndex)
    for _, existingModelUnit in pairs(self.m_PreviewAttackModelUnits) do
        if (modelUnit == existingModelUnit) then
            return
        end
    end

    self.m_PreviewAttackModelUnits[#self.m_PreviewAttackModelUnits + 1] = modelUnit
    self.m_PreviewAttackableArea = AttackableGridListFunctions.createAttackableArea(modelUnit, getModelTileMap(self.m_ModelWar), getModelUnitMap(self.m_ModelWar), self.m_PreviewAttackableArea)

    if (self.m_View) then
        self.m_View:setPreviewAttackableArea(self.m_PreviewAttackableArea)
            :setPreviewAttackableAreaVisible(true)
        modelUnit:showMovingAnimation()
    end
end

local function canSetStatePreviewingReachableArea(self, gridIndex)
    local modelUnit = getModelUnitMap(self.m_ModelWar):getModelUnit(gridIndex)
    return (modelUnit) and (not modelUnit.getAttackRangeMinMax)
end

local function setStatePreviewingReachableArea(self, gridIndex)
    self.m_State = "previewingReachableArea"

    local modelUnit              = getModelUnitMap(self.m_ModelWar):getModelUnit(gridIndex)
    self.m_PreviewReachModelUnit = modelUnit
    self.m_PreviewReachableArea  = ReachableAreaFunctions.createArea(
        gridIndex,
        math.min(modelUnit:getMoveRange(), modelUnit:getCurrentFuel()),
        function(gridIndex)
            return getMoveCost(gridIndex, modelUnit, getModelUnitMap(self.m_ModelWar), getModelTileMap(self.m_ModelWar))
        end
    )

    if (self.m_View) then
        self.m_View:setPreviewReachableArea(self.m_PreviewReachableArea)
            :setPreviewReachableAreaVisible(true)
        modelUnit:showMovingAnimation()
    end
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtPlayerIndexUpdated(self, event)
    self:setStateIdle(true)
end

local function onEvtWarCommandMenuUpdated(self, event)
    if (event.modelWarCommandMenu:isEnabled()) then
        self:setStateIdle(true)
    end
end

local function onEvtMapCursorMoved(self, event)
end

local function onEvtGridSelected(self, event)
    local state     = self.m_State
    local gridIndex = event.gridIndex
    if (state == "idle") then
        if     (canSetStatePreviewingAttackableArea(self, gridIndex)) then setStatePreviewingAttackableArea(self, gridIndex)
        elseif (canSetStatePreviewingReachableArea( self, gridIndex)) then setStatePreviewingReachableArea( self, gridIndex)
        end
    elseif (state == "previewingAttackableArea") then
        if (canSetStatePreviewingAttackableArea(self, gridIndex)) then
            setStatePreviewingAttackableArea(self, gridIndex)
        else
            self:setStateIdle(true)
        end
    elseif (state == "previewingReachableArea") then
        self:setStateIdle(true)
    else
        error("ModelActionPlannerForReplay-onEvtGridSelected() the state of the planner is invalid.")
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelActionPlannerForReplay:ctor(param)
    self.m_State                      = "idle"
    self.m_PreviewAttackModelUnits    = {}

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelActionPlannerForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWar = modelWarReplay
    getScriptEventDispatcher(modelWarReplay)
        :addEventListener("EvtGridSelected",          self)
        :addEventListener("EvtMapCursorMoved",        self)
        :addEventListener("EvtPlayerIndexUpdated",    self)
        :addEventListener("EvtWarCommandMenuUpdated", self)

    self.m_View:setMapSize(getModelTileMap(modelWarReplay):getMapSize())
    self:setStateIdle(true)

    return self
end

function ModelActionPlannerForReplay:onEvent(event)
    local name = event.name
    if     (name == "EvtGridSelected")          then onEvtGridSelected(         self, event)
    elseif (name == "EvtPlayerIndexUpdated")    then onEvtPlayerIndexUpdated(   self, event)
    elseif (name == "EvtMapCursorMoved")        then onEvtMapCursorMoved(       self, event)
    elseif (name == "EvtWarCommandMenuUpdated") then onEvtWarCommandMenuUpdated(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelActionPlannerForReplay:setStateIdle(resetUnitAnimation)
    for _, modelUnit in pairs(self.m_PreviewAttackModelUnits) do
        modelUnit:showNormalAnimation()
    end
    if (self.m_PreviewReachModelUnit) then
        self.m_PreviewReachModelUnit:showNormalAnimation()
    end

    self.m_State                    = "idle"
    self.m_PreviewAttackModelUnits  = {}
    self.m_PreviewAttackableArea    = {}
    self.m_PreviewReachModelUnit    = nil

    self.m_View:setPreviewAttackableAreaVisible( false)
        :setPreviewReachableAreaVisible(  false)

    getScriptEventDispatcher(self.m_ModelWar):dispatchEvent({name = "EvtActionPlannerIdle"})

    return self
end

return ModelActionPlannerForReplay
