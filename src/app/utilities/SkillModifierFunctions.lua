
local SkillModifierFunctions = {}

local ipairs = ipairs

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getSkillModifierWithSkillData(modelSkillDataManager, skillData, isActiveSkill)
    if (isActiveSkill) then
        return modelSkillDataManager:getSkillModifier(skillData.id, skillData.level, true)
    else
        return skillData.modifier
    end
end

local function getAttackModifierForSkillGroup(modelSkillGroup,
    attacker, attackerGridIndex, target, targetGridIndex, modelWar)

    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 1) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getDefenseModifierForSkillGroup(modelSkillGroup,
    attacker, attackerGridIndex, target, targetGridIndex, modelWar)

    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 2) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getMoveRangeModifierForSkillGroup(modelSkillGroup, modelUnit)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 5) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getAttackRangeModifierForSkillGroup(modelSkillGroup)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 6) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getIncomeModifierForSkillGroup(modelSkillGroup)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 8) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getRepairAmountModifierForSkillGroup(modelSkillGroup)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 11) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillModifierFunctions.getAttackModifier(attacker, attackerGridIndex, target, targetGridIndex, modelWar)
    local configuration = modelWar:getModelPlayerManager():getModelPlayer(attacker:getPlayerIndex()):getModelSkillConfiguration()
    return getAttackModifierForSkillGroup(configuration:getModelSkillGroupPassive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelWar) +
        getAttackModifierForSkillGroup(configuration:getModelSkillGroupActive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelWar)
end

function SkillModifierFunctions.getDefenseModifier(attacker, attackerGridIndex, target, targetGridIndex, modelWar)
    local configuration = modelWar:getModelPlayerManager():getModelPlayer(target:getPlayerIndex()):getModelSkillConfiguration()
    return getDefenseModifierForSkillGroup(configuration:getModelSkillGroupPassive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelWar) +
        getDefenseModifierForSkillGroup(configuration:getModelSkillGroupActive(),
            attacker, attackerGridIndex, target, targetGridIndex, modelWar)
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

function SkillModifierFunctions.getRepairAmountModifier(configuration)
    return getRepairAmountModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

return SkillModifierFunctions
