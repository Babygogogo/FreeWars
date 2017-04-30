
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
function SkillModifierFunctions.getAttackModifierForSkillConfiguration(configuration, isActivatingSkill)
    local modifier = getAttackModifierForSkillGroup(configuration:getModelSkillGroupPassive())
    if (isActivatingSkill) then
        modifier = modifier + getAttackModifierForSkillGroup(configuration:getModelSkillGroupActive())
    end

    return modifier
end

function SkillModifierFunctions.getDefenseModifierForSkillConfiguration(configuration, isActivatingSkill)
    local modifier = getDefenseModifierForSkillGroup(configuration:getModelSkillGroupPassive())
    if (isActivatingSkill) then
        modifier = modifier + getDefenseModifierForSkillGroup(configuration:getModelSkillGroupActive())
    end

    return modifier
end

function SkillModifierFunctions.getMoveRangeModifierForSkillConfiguration(configuration, isActivatingSkill)
    local modifier = getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive())
    if (isActivatingSkill) then
        modifier = modifier + getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupActive())
    end

    return modifier
end

function SkillModifierFunctions.getAttackRangeModifierForSkillConfiguration(configuration, isActivatingSkill)
    local modifier = getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive())
    if (isActivatingSkill) then
        modifier = modifier + getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupActive())
    end

    return modifier
end

function SkillModifierFunctions.getIncomeModifierForSkillConfiguration(configuration)
    return getIncomeModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

function SkillModifierFunctions.getRepairAmountModifierForSkillConfiguration(configuration)
    return getRepairAmountModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

function SkillModifierFunctions.getCaptureAmountModifierForSkillConfiguration(configuration, isActivatingSkill)
    local modifier = getCaptureAmountModifierForSkillGroup(configuration:getModelSkillGroupPassive())
    if (isActivatingSkill) then
        modifier = modifier + getCaptureAmountModifierForSkillGroup(configuration:getModelSkillGroupActive())
    end

    return modifier
end

function SkillModifierFunctions.getEnergyGainModifierForSkillConfiguration(configuration)
    return getEnergyGainModifierForSkillGroup(configuration:getModelSkillGroupPassive())
end

return SkillModifierFunctions
