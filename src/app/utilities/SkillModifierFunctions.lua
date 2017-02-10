
local SkillModifierFunctions = {}

local SkillDataAccessors = requireFW("src.app.utilities.SkillDataAccessors")

local getSkillModifier = SkillDataAccessors.getSkillModifier
local isTypeInCategory = requireFW("src.app.utilities.GameConstantFunctions").isTypeInCategory

local ipairs = ipairs

local PASSIVE_SLOTS_COUNT = SkillDataAccessors.getPassiveSkillSlotsCount()
local ACTIVE_SLOTS_COUNT  = SkillDataAccessors.getActiveSkillSlotsCount()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getSlotsCount(isActive)
    return (isActive) and (ACTIVE_SLOTS_COUNT) or (PASSIVE_SLOTS_COUNT)
end

local function getAttackModifierForSkillGroup(modelSkillGroup, isActive,
    attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)

    local modifier = 0
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 1) then
            modifier = modifier + getSkillModifier(skillID, skill.level, isActive)
        end
    end

    return modifier
end

local function getDefenseModifierForSkillGroup(modelSkillGroup, isActive,
    attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)

    local modifier = 0
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 2) then
            modifier = modifier + getSkillModifier(skillID, skill.level, isActive)
        end
    end

    return modifier
end

local function getMoveRangeModifierForSkillGroup(modelSkillGroup, isActive, modelUnit)
    local modifier = 0
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 5) then
            modifier = modifier + getSkillModifier(skillID, skill.level, isActive)
        end
    end

    return modifier
end

local function getAttackRangeModifierForSkillGroup(modelSkillGroup, isActive)
    local modifier = 0
    for _, skill in ipairs(modelSkillGroup:getAllSkills()) do
        local skillID = skill.id
        if (skillID == 6) then
            modifier = modifier + getSkillModifier(skill.id, skill.level, isActive)
        end
    end

    return modifier
end

local function getIncomeModifierForSkillGroup(modelSkillGroup, isActive)
    if (not modelSkillGroup) then
        return 0
    end

    local modifier = 0
    local skills   = modelSkillGroup:getAllSkills()
    for i = 1, getSlotsCount(isActive) do
        local skill = skills[i]
        if ((skill)          and
            (skill.id == 17)) then
            modifier = modifier + getSkillModifier(skill.id, skill.level, isActive)
        end
    end

    return modifier
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillModifierFunctions.getAttackModifier(attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
    local configuration = modelSceneWar:getModelPlayerManager():getModelPlayer(attacker:getPlayerIndex()):getModelSkillConfiguration()
    return getAttackModifierForSkillGroup(configuration:getModelSkillGroupPassive(), false,
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar) +
        getAttackModifierForSkillGroup(configuration:getModelSkillGroupActive(), true,
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
end

function SkillModifierFunctions.getDefenseModifier(attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
    local configuration = modelSceneWar:getModelPlayerManager():getModelPlayer(target:getPlayerIndex()):getModelSkillConfiguration()
    return getDefenseModifierForSkillGroup(configuration:getModelSkillGroupPassive(), false,
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar) +
        getDefenseModifierForSkillGroup(configuration:getModelSkillGroupActive(), true,
            attacker, attackerGridIndex, target, targetGridIndex, modelSceneWar)
end

function SkillModifierFunctions.getMoveRangeModifier(configuration, modelUnit)
    return getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive(), false, modelUnit) +
        getMoveRangeModifierForSkillGroup(configuration:getModelSkillGroupActive(), true, modelUnit)
end

function SkillModifierFunctions.getAttackRangeModifier(configuration)
    return getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupPassive(), false) +
        getAttackRangeModifierForSkillGroup(configuration:getModelSkillGroupActive(), true)
end

function SkillModifierFunctions.getIncomeModifier(configuration)
    return getIncomeModifierForSkillGroup(configuration:getModelSkillGroupPassive(), false)
end

return SkillModifierFunctions
