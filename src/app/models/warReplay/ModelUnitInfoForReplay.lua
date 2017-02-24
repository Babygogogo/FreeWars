
local ModelUnitInfoForReplay = class("ModelUnitInfoForReplay")

local GridIndexFunctions  = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters    = requireFW("src.app.utilities.SingletonGetters")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function updateWithModelUnitMap(self)
    local modelWarReplay       = self.m_ModelWarReplay
    local modelUnitMap        = SingletonGetters.getModelUnitMap(modelWarReplay)
    local modelUnit           = modelUnitMap:getModelUnit(self.m_CursorGridIndex)
    local modelWarCommandMenu = self.m_ModelWarCommandMenu
    if ((modelWarCommandMenu:isEnabled())                   or
        (modelWarCommandMenu:isHiddenWithHideUI())          or
        (not modelUnit))                                    then
        self.m_View:setVisible(false)
    else
        local loadedModelUnits = modelUnitMap:getLoadedModelUnitsWithLoader(modelUnit)
        self.m_ModelUnitList = {modelUnit, unpack(loadedModelUnits or {})}

        self.m_View:updateWithModelUnit(modelUnit, loadedModelUnits)
            :setVisible(true)
    end
end

--------------------------------------------------------------------------------
-- The callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtModelUnitMapUpdated(self, event)
    updateWithModelUnitMap(self)
end

local function onEvtGridSelected(self, event)
    self.m_CursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    updateWithModelUnitMap(self)
end

local function onEvtMapCursorMoved(self, event)
    self.m_CursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    updateWithModelUnitMap(self)
end

local function onEvtWarCommandMenuUpdated(self, event)
    updateWithModelUnitMap(self)
end

local function onEvtPlayerIndexUpdated(self, event)
    self.m_View:updateWithPlayerIndex(event.playerIndex)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelUnitInfoForReplay:ctor(param)
    self.m_CursorGridIndex = {x = 1, y = 1}

    return self
end

function ModelUnitInfoForReplay:setModelUnitDetail(model)
    assert(self.m_ModelUnitDetail == nil, "ModelUnitInfoForReplay:setModelUnitDetail() the model has been set.")
    self.m_ModelUnitDetail = model

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelUnitInfoForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay      = modelWarReplay
    self.m_ModelWarCommandMenu = SingletonGetters.getModelWarCommandMenu(modelWarReplay)

    SingletonGetters.getScriptEventDispatcher(modelWarReplay)
        :addEventListener("EvtGridSelected",          self)
        :addEventListener("EvtMapCursorMoved",        self)
        :addEventListener("EvtModelUnitMapUpdated",   self)
        :addEventListener("EvtPlayerIndexUpdated",    self)
        :addEventListener("EvtWarCommandMenuUpdated", self)

    self.m_View:updateWithPlayerIndex(SingletonGetters.getModelTurnManager(modelWarReplay):getPlayerIndex())

    updateWithModelUnitMap(self)

    return self
end

function ModelUnitInfoForReplay:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtGridSelected")          then onEvtGridSelected(         self, event)
    elseif (eventName == "EvtMapCursorMoved")        then onEvtMapCursorMoved(       self, event)
    elseif (eventName == "EvtModelUnitMapUpdated")   then onEvtModelUnitMapUpdated(  self, event)
    elseif (eventName == "EvtPlayerIndexUpdated")    then onEvtPlayerIndexUpdated(   self, event)
    elseif (eventName == "EvtWarCommandMenuUpdated") then onEvtWarCommandMenuUpdated(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelUnitInfoForReplay:onPlayerTouch(index)
    if (self.m_ModelUnitDetail) then
        self.m_ModelUnitDetail:updateWithModelUnit(self.m_ModelUnitList[index])
            :setEnabled(true)
    end

    return self
end

return ModelUnitInfoForReplay
