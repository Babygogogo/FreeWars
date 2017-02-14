
local SkillDataAccessors = {}

local SKILL_DATA = requireFW("res.data.SkillData")

function SkillDataAccessors.getSkillDeclarationCost()
    return SKILL_DATA.skillDeclarationCost
end

function SkillDataAccessors.getSkillPoints(id, level, isActive)
    assert(type(isActive) == "boolean", "SkillDataAccessors.getSkillPoints() invalid param isActive. Boolean expected.")
    if (isActive) then
        return SKILL_DATA.skills[id].levels[level].pointsActive
    else
        return SKILL_DATA.skills[id].levels[level].pointsPassive
    end
end

function SkillDataAccessors.getSkillModifier(id, level, isActive)
    assert(type(isActive) == "boolean", "SkillDataAccessors.getSkillModifier() invalid param isActive. Boolean expected.")
    if (isActive) then
        return SKILL_DATA.skills[id].levels[level].modifierActive
    else
        return SKILL_DATA.skills[id].levels[level].modifierPassive
    end
end

function SkillDataAccessors.getSkillModifierUnit(id)
    return SKILL_DATA.skills[id].modifierUnit
end

function SkillDataAccessors.getSkillLevelMinMax(id, isActive)
    local skill = SKILL_DATA.skills[id]
    if (isActive) then
        return skill.minLevelActive, skill.maxLevelActive
    else
        return skill.minLevelPassive, skill.maxLevelPassive
    end
end

function SkillDataAccessors.getSkillCategory(categoryName)
    return SKILL_DATA.categories[categoryName]
end

function SkillDataAccessors.getSkillData(skillID)
    return SKILL_DATA.skills[skillID]
end

return SkillDataAccessors
