
local Producible = requireFW("src.global.functions.class")("Producible")

local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")

Producible.EXPORTED_METHODS = {
    "getProductionCost",
    "getBaseProductionCost",
}

--------------------------------------------------------------------------------
-- The static functions.
--------------------------------------------------------------------------------
function Producible.getProductionCostWithTiledId(tiledID, modelPlayerManager)
    return GameConstantFunctions.getTemplateModelUnitWithTiledId(tiledID).Producible.productionCost
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function Producible:ctor(param)
    self:loadTemplate(param.template)

    return self
end

function Producible:loadTemplate(template)
    self.m_Template = template

    return self
end

--------------------------------------------------------------------------------
-- The exported functions.
--------------------------------------------------------------------------------
function Producible:getProductionCost()
    return self.m_Template.productionCost
end

function Producible:getBaseProductionCost()
    return self.m_Template.productionCost
end

return Producible
