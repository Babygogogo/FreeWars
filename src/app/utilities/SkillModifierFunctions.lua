
local SkillModifierFunctions = {}

local SkillDataAccessors = requireFW("src.app.utilities.SkillDataAccessors")

local getSkillModifier = SkillDataAccessors.getSkillModifier

local ipairs = ipairs

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getSkillModifierWithSkillData(skillData, isActiveSkill)
    if (isActiveSkill) then
        return getSkillModifier(skillData.id, skillData.level, true)
    else
        return skillData.modifier
    end
end

local function getAttackModifierForSkillGroup(modelSkillGroup,
    attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)

    local modifier      = 0
    local isActiveSkill = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 1) then
            modifier = modifier + getSkillModifierWithSkillData(skill, isActiveSkill)
        end
    end

    return modifier
end

local function getDefenseModifierForSkillGroup(modelSkillGroup,
    attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)

    local modifier      = 0
    local isActiveSkill = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 2) then
            modifier = modifier + getSkillModifierWithSkillData(skill, isActiveSkill)
        end
    end

    return modifier
end

local function getMoveRangeModifierForSkillGroup(modelSkillGroup, modelUnit)
    local modifier      = 0
    local isActiveSkill = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 5) then
            modifier = modifier + getSkillModifierWithSkillData(skill, isActiveSkill)
        end
    end

    return modifier
end

local function getAttackRangeModifierForSkillGroup(modelSkillGroup)
    local modifier      = 0
    local isActiveSkill = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 6) then
            modifier = modifier + getSkillModifierWithSkillData(skill, isActiveSkill)
        end
    end

    return modifier
end

local function getIncomeModifierForSkillGroup(modelSkillGroup)
    local modifier      = 0
    local isActiveSkill = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 8) then
            modifier = modifier + getSkillModifierWithSkillData(skill, isActiveSkill)
        end
    end

    return modifier
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillModifierFunctions.getAttackModifier(attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
    local configuration = modelSceneWar:getModelPlayerManager():getModelPlayer(attacker:getPlayerIndex()):getModelSkillConfiguration()
    return getAttackModifierForSkillGroup(configuration:getModelSkillGroupPassive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar) +
        getAttackModifierForSkillGroup(configuration:getModelSkillGroupActive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
end

function SkillModifierFunctions.getDefenseModifier(attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
    local configuration = modelSceneWar:getModelPlayerManager():getModelPlayer(target:getPlayerIndex()):getModelSkillConfiguration()
    return getDefenseModifierForSkillGroup(configuration:getModelSkillGroupPassive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar) +
        getDefenseModifierForSkillGroup(configuration:getModelSkillGroupActive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
end

function SkillModifierFunctions.getMoveRangeModifier(configuration, modelUnit)
    return getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive(), modelUnit) +
        getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupActive(), modelUnit)
end

function SkillModifierFunctions.getAttackRangeModifier(configuration)
    return getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive()) +
        getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getIncomeModifier(configuration)
    return getIncomeModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

return SkillModifierFunctions
