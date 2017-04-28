
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

local function getAttackModifierForSkillGroup(modelSkillGroup)
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

local function getDefenseModifierForSkillGroup(modelSkillGroup)
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

local function getMoveRangeModifierForSkillGroup(modelSkillGroup)
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

local function getCaptureAmountModifierForSkillGroup(modelSkillGroup)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 12) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

local function getEnergyGainModifierForSkillGroup(modelSkillGroup)
    local modelSkillDataManager = modelSkillGroup:getModelSkillDataManager()
    local modifier              = 0
    local isActiveSkill         = modelSkillGroup.isSkillGroupActive
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 13) then
            modifier = modifier + getSkillModifierWithSkillData(modelSkillDataManager, skill, isActiveSkill)
        end
    end

    return modifier
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillModifierFunctions.getAttackModifierForSkillConfiguration(configuration)
    return getAttackModifierForSkillGroup(configuration:getModelSkillGroupPassive()) + getAttackModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getDefenseModifierForSkillConfiguration(configuration)
    return getDefenseModifierForSkillGroup(configuration:getModelSkillGroupPassive()) + getDefenseModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getMoveRangeModifierForSkillConfiguration(configuration)
    return getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive()) + getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getAttackRangeModifierForSkillConfiguration(configuration)
    return getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive()) + getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getIncomeModifierForSkillConfiguration(configuration)
    return getIncomeModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

function SkillModifierFunctions.getRepairAmountModifierForSkillConfiguration(configuration)
    return getRepairAmountModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

function SkillModifierFunctions.getCaptureAmountModifierForSkillConfiguration(configuration)
    return getCaptureAmountModifierForSkillGroup(configuration:getModelSkillGroupPassive()) + getCaptureAmountModifierForSkillGroup(configuration:getModelSkillGroupActive())
end

function SkillModifierFunctions.getEnergyGainModifierForSkillConfiguration(configuration)
    return getEnergyGainModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

return SkillModifierFunctions
