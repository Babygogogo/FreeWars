
local VisionOwner = requireFW("src.global.functions.class")("VisionOwner")

local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")

local getModelTileMap = SingletonGetters.getModelTileMap

VisionOwner.EXPORTED_METHODS = {
    "getVisionForPlayerIndex",
}

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function VisionOwner:ctor(param)
    self:loadTemplate(param.template)

    return self
end

function VisionOwner:loadTemplate(template)
    self.m_Template = template

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function VisionOwner:onStartRunning(modelSceneWar)
    self.m_ModelSceneWar = modelSceneWar

    return self
end

--------------------------------------------------------------------------------
-- The exported functions.
--------------------------------------------------------------------------------
function VisionOwner:getVisionForPlayerIndex(playerIndex, gridIndex)
    local template         = self.m_Template
    local owner            = self.m_Owner
    local ownerPlayerIndex = owner:getPlayerIndex()
    if ((not template.isEnabledForAllPlayers) and (ownerPlayerIndex ~= playerIndex)) then
        return nil
    else
        return template.vision
    end
end

return VisionOwner
