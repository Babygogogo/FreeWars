
--[[--------------------------------------------------------------------------------
-- IncomeProvider是ModelTile可用的组件。只有绑定了本组件，宿主才具有“收入”的属性。
-- 主要职责：
--   维护相关数值并提供必要接口给外界访问
-- 使用场景举例：
--   初始化单位时，根据单位属性来绑定和初始化本组件（所有ModelUnit/ModelTile都需要绑定，但具体由GameConstant决定）
--   回合初计算玩家收入时会用到本组件
--]]--------------------------------------------------------------------------------

local IncomeProvider = requireFW("src.global.functions.class")("IncomeProvider")

local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")
local ComponentManager       = requireFW("src.global.components.ComponentManager")

local math = math

IncomeProvider.EXPORTED_METHODS = {
    "getIncomeAmount",
}

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function IncomeProvider:ctor(param)
    self:loadTemplate(param.template)

    return self
end

function IncomeProvider:loadTemplate(template)
    assert(template.amount, "IncomeProvider:loadTemplate() the param template.amount is invalid.")
    self.m_Template = template

    return self
end

--------------------------------------------------------------------------------
-- The public callback function on start running.
--------------------------------------------------------------------------------
function IncomeProvider:onStartRunning(modelWar)
    self.m_ModelWar = modelWar

    return self
end

--------------------------------------------------------------------------------
-- The exported functions.
--------------------------------------------------------------------------------
function IncomeProvider:getIncomeAmount()
    local modelWar    = self.m_ModelWar
    local playerIndex = self.m_Owner:getPlayerIndex()
    local baseAmount  = self.m_Template.amount * modelWar:getIncomeModifier() / 100
    if (playerIndex == 0) then
        return math.floor(baseAmount)
    else
        local modelSkillConfiguration = SingletonGetters.getModelPlayerManager(modelWar):getModelPlayer(playerIndex):getModelSkillConfiguration()
        local modifier                = SkillModifierFunctions.getIncomeModifierForSkillConfiguration(modelSkillConfiguration)
        return math.floor(baseAmount * (100 + modifier) / 100)
    end
end

return IncomeProvider
