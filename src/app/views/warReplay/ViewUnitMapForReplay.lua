
local ViewUnitMapForReplay = class("ViewUnitMapForReplay", cc.Node)

local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")

local isTypeInCategory = GameConstantFunctions.isTypeInCategory
local toErrorMessage   = SerializationFunctions.toErrorMessage

local CATEGORY_AIR_UNITS    = "AirUnits"
local CATEGORY_GROUND_UNITS = "GroundUnits"
local CATEGORY_NAVAL_UNITS  = "NavalUnits"

local AIR_UNIT_Z_ORDER    = 2
local GROUND_UNIT_Z_ORDER = 1
local NAVAL_UNIT_Z_ORDER  = 0

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getUnitCategoryType(modelUnit)
    local unitType = modelUnit:getUnitType()
    if     (isTypeInCategory(unitType, CATEGORY_AIR_UNITS))    then return CATEGORY_AIR_UNITS
    elseif (isTypeInCategory(unitType, CATEGORY_GROUND_UNITS)) then return CATEGORY_GROUND_UNITS
    elseif (isTypeInCategory(unitType, CATEGORY_NAVAL_UNITS))  then return CATEGORY_NAVAL_UNITS
    else   error("ViewUnitMapForReplay-getUnitCategoryType() no category matched unitType: " .. toErrorMessage(unitType))
    end
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initLayerAir(self)
    local layer = cc.Node:create()

    self.m_Layers[CATEGORY_AIR_UNITS] = layer
    self:addChild(layer, AIR_UNIT_Z_ORDER)
end

local function initLayerGround(self)
    local layer = cc.Node:create()

    self.m_Layers[CATEGORY_GROUND_UNITS] = layer
    self:addChild(layer, GROUND_UNIT_Z_ORDER)
end

local function initLayerNaval(self)
    local layer = cc.Node:create()

    self.m_Layers[CATEGORY_NAVAL_UNITS] = layer
    self:addChild(layer, NAVAL_UNIT_Z_ORDER)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewUnitMapForReplay:ctor(param)
    self.m_Layers = {}
    initLayerAir(   self)
    initLayerGround(self)
    initLayerNaval( self)

    return self
end

function ViewUnitMapForReplay:setMapSize(size)
    self.m_MapHeight = size.height

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewUnitMapForReplay:addViewUnit(viewUnit, modelUnit)
    local gridIndex = modelUnit:getGridIndex()
    local category  = getUnitCategoryType(modelUnit)
    self.m_Layers[category]:addChild(viewUnit, self.m_MapHeight - gridIndex.y)

    local unitID = modelUnit:getUnitId()
    if (self.m_Model:getLoadedModelUnitWithUnitId(unitID)) then
        viewUnit:setVisible(false)
    end

    return self
end

function ViewUnitMapForReplay:removeAllViewUnits()
    for _, layer in pairs(self.m_Layers) do
        layer:removeAllChildren()
    end

    return self
end

return ViewUnitMapForReplay
