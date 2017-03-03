
local ModelSkillDataManager = requireFW("src.global.functions.class")("ModelSkillDataManager")

local GLOBAL_SKILL_DATA = requireFW("res.data.SkillData")

local assert, type = assert, type

--------------------------------------------------------------------------------
-- The constructor.
--------------------------------------------------------------------------------
function ModelSkillDataManager:ctor(skillData)
    self.m_SkillData = skillData or GLOBAL_SKILL_DATA

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillDataManager:toSerializableTable()
    return self.m_SkillData
end

function ModelSkillDataManager:toSerializableTableForPlayerIndex(playerIndex)
    return self.m_SkillData
end

function ModelSkillDataManager:toSerializableReplayData()
    return self.m_SkillData
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillDataManager:getSkillDeclarationCost()
    return self.m_SkillData.skillDeclarationCost
end

function ModelSkillDataManager:getSkillPoints(id, level, isActive)
    assert(type(isActive) == "boolean", "ModelSkillDataManager.getSkillPoints() invalid param isActive. Boolean expected.")
    if (isActive) then
        return self.m_SkillData.skills[id].levels[level].pointsActive
    else
        return self.m_SkillData.skills[id].levels[level].pointsPassive
    end
end

function ModelSkillDataManager:getSkillModifier(id, level, isActive)
    assert(type(isActive) == "boolean", "ModelSkillDataManager.getSkillModifier() invalid param isActive. Boolean expected.")
    if (isActive) then
        return self.m_SkillData.skills[id].levels[level].modifierActive
    else
        return self.m_SkillData.skills[id].levels[level].modifierPassive
    end
end

function ModelSkillDataManager:getSkillModifierUnit(id)
    return self.m_SkillData.skills[id].modifierUnit
end

function ModelSkillDataManager:getSkillLevelMinMax(id, isActive)
    local skill = self.m_SkillData.skills[id]
    if (isActive) then
        return skill.minLevelActive, skill.maxLevelActive
    else
        return skill.minLevelPassive, skill.maxLevelPassive
    end
end

function ModelSkillDataManager:getSkillCategory(categoryName)
    return self.m_SkillData.categories[categoryName]
end

function ModelSkillDataManager:getSkillData(skillID)
    return self.m_SkillData.skills[skillID]
end

return ModelSkillDataManager
