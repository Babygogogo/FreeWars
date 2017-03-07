
local VisionOwner = requireFW("src.global.functions.class")("VisionOwner")

local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")

local getModelTileMap = SingletonGetters.getModelTileMap
local math            = math

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
function VisionOwner:onStartRunning(modelWar)
    self.m_ModelWar = modelWar

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
        local modelWar   = self.m_ModelWar
        local baseVision = template.vision + modelWar:getVisionModifier()
        if (owner.getTileType) then
            return math.max(1, baseVision)
        else
            local tileType = getModelTileMap(modelWar):getModelTile(gridIndex or owner:getGridIndex()):getTileType()
            local bonus    = (template.bonusOnTiles) and (template.bonusOnTiles[tileType] or 0) or (0)
            return math.max(1, baseVision + bonus)
        end
    end
end

return VisionOwner
