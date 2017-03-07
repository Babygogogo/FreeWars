
local ModelUnitForReplay = requireFW("src.global.functions.class")("ModelUnitForReplay")

local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")
local ComponentManager      = requireFW("src.global.components.ComponentManager")

local assert = assert

local UNIT_STATE_CODE = {
    Idle     = 1,
    Actioned = 2,
}

--------------------------------------------------------------------------------
-- The functions that loads the data for the model from a TiledID/lua table.
--------------------------------------------------------------------------------
local function initWithTiledID(self, tiledID)
    self.m_TiledID = tiledID

    local template = GameConstantFunctions.getTemplateModelUnitWithTiledId(tiledID)
    assert(template, "ModelUnitForReplay-initWithTiledID() failed to get the template model unit with param tiledID." .. tiledID)

    if (template ~= self.m_Template) then
        self.m_Template  = template
        self.m_StateCode = UNIT_STATE_CODE.Idle

        ComponentManager.unbindAllComponents(self)
        for name, data in pairs(template) do
            if (string.byte(name) > string.byte("z")) or (string.byte(name) < string.byte("a")) then
                ComponentManager.bindComponent(self, name, {template = data, instantialData = data})
            end
        end
    end
end

local function loadInstantialData(self, param)
    self.m_StateCode = param.stateCode or self.m_StateCode
    self.m_UnitID    = param.unitID    or self.m_UnitID

    for name, data in pairs(param) do
        if (string.byte(name) > string.byte("z")) or (string.byte(name) < string.byte("a")) then
            ComponentManager.getComponent(self, name):loadInstantialData(data)
        end
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelUnitForReplay:ctor(param)
    initWithTiledID(   self, param.tiledID)
    loadInstantialData(self, param)

    if (self.m_View) then
        self:initView()
    end

    return self
end

function ModelUnitForReplay:initView()
    local view = self.m_View
    assert(view, "ModelUnitForReplay:initView() no view is attached to the actor of the model.")

    self:setViewPositionWithGridIndex()

    return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelUnitForReplay:toSerializableTable()
    local t = {}
    for name, component in pairs(ComponentManager.getAllComponents(self)) do
        if (component.toSerializableTable) then
            t[name] = component:toSerializableTable()
        end
    end

    t.tiledID = self:getTiledId()
    t.unitID  = self:getUnitId()
    local stateCode = self.m_StateCode
    if (stateCode ~= UNIT_STATE_CODE.Idle) then
        t.stateCode = stateCode
    end

    return t
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelUnitForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay = modelWarReplay
    self.m_TeamIndex      = SingletonGetters.getModelPlayerManager(modelWarReplay):getModelPlayer(self:getPlayerIndex()):getTeamIndex()

    ComponentManager.callMethodForAllComponents(self, "onStartRunning", modelWarReplay)
    self:updateView()

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelUnitForReplay:moveViewAlongPath(path, isDiving, callbackAfterMove)
    self.m_View:moveAlongPath(path, isDiving, callbackAfterMove)

    return self
end

function ModelUnitForReplay:moveViewAlongPathAndFocusOnTarget(path, isDiving, targetGridIndex, callbackAfterMove)
    self.m_View:moveAlongPathAndFocusOnTarget(path, isDiving, targetGridIndex, callbackAfterMove)

    return self
end

function ModelUnitForReplay:setViewVisible(visible)
    self.m_View:setVisible(visible)

    return self
end

function ModelUnitForReplay:updateView()
    self.m_View:updateWithModelUnit(self)

    return self
end

function ModelUnitForReplay:removeViewFromParent()
    self.m_View:removeFromParent()
    self.m_View = nil

    return self
end

function ModelUnitForReplay:showNormalAnimation()
    self.m_View:showNormalAnimation()

    return self
end

function ModelUnitForReplay:showMovingAnimation()
    self.m_View:showMovingAnimation()

    return self
end

function ModelUnitForReplay:getModelWar()
    assert(self.m_ModelWarReplay, "ModelUnitForReplay:getModelWar() the model hasn't been set yet.")
    return self.m_ModelWarReplay
end

function ModelUnitForReplay:getTiledId()
    return self.m_TiledID
end

function ModelUnitForReplay:getUnitId()
    return self.m_UnitID
end

function ModelUnitForReplay:getPlayerIndex()
    return GameConstantFunctions.getPlayerIndexWithTiledId(self.m_TiledID)
end

function ModelUnitForReplay:getTeamIndex()
    assert(self.m_TeamIndex, "ModelUnitForReplay:getTeamIndex() the index hasn't been initialized yet.")
    return self.m_TeamIndex
end

function ModelUnitForReplay:isStateIdle()
    return self.m_StateCode == UNIT_STATE_CODE.Idle
end

function ModelUnitForReplay:setStateIdle()
    self.m_StateCode = UNIT_STATE_CODE.Idle

    return self
end

function ModelUnitForReplay:setStateActioned()
    self.m_StateCode = UNIT_STATE_CODE.Actioned

    return self
end

function ModelUnitForReplay:getUnitType()
    return GameConstantFunctions.getUnitTypeWithTiledId(self:getTiledId())
end

function ModelUnitForReplay:getDescription()
    return LocalizationFunctions.getLocalizedText(114, self:getUnitType())
end

function ModelUnitForReplay:getUnitTypeFullName()
    return LocalizationFunctions.getLocalizedText(113, self:getUnitType())
end

return ModelUnitForReplay
