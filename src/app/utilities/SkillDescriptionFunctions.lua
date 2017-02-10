
local SkillDescriptionFunctions = {}

local ModelSkillConfiguration = requireFW("src.app.models.common.ModelSkillConfiguration")
local LocalizationFunctions   = requireFW("src.app.utilities.LocalizationFunctions")
local SkillDataAccessors      = requireFW("src.app.utilities.SkillDataAccessors")

local getSkillPoints            = SkillDataAccessors.getSkillPoints
local getSkillEnergyRequirement = SkillDataAccessors.getSkillEnergyRequirement
local getSkillModifier          = SkillDataAccessors.getSkillModifier
local getSkillModifierUnit      = SkillDataAccessors.getSkillModifierUnit
local getLocalizedText          = LocalizationFunctions.getLocalizedText
local string                    = string

local PASSIVE_SLOTS_COUNT = SkillDataAccessors.getPassiveSkillSlotsCount()
local ACTIVE_SLOTS_COUNT  = SkillDataAccessors.getActiveSkillSlotsCount()
local SKILL_PASSIVE       = "SkillPassive"
local SKILL_RESEARCHING   = "SkillResearching"
local SKILL_ACTIVE        = "SkillActive"

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function transformModifier1(modifier, unit)
    return string.format("%.2f%s", 100 + modifier, unit)
end

local function transformModifier2(modifier, unit)
    if (modifier >= 0) then
        return string.format("%.2f%s", 10000 / (100 + modifier), unit)
    else
        return string.format("%.2f%s", 100 - modifier,           unit)
    end
end

local function transformModifier3(modifier, unit)
    unit = unit or ""
    if (modifier == math.floor(modifier)) then
        if (modifier > 0) then return string.format("+%d%s", modifier, unit)
        else                   return string.format("%d%s",  modifier, unit)
        end
    else
        if (modifier > 0) then return string.format("+%.2f%s", modifier, unit)
        else                   return string.format("%.2f%s",  modifier, unit)
        end
    end
end

local function getSkillModifierForDisplay(id, level, isActive)
    local modifier = getSkillModifier(id, level, isActive)
    if (not modifier) then
        return ""
    end

    local modifierUnit = getSkillModifierUnit(id)
    if     (id == 1)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 2)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 3)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 4)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 5)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 6)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 8)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 9)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 10) then return transformModifier3(modifier,  modifierUnit)
    end
end

local function getFullDescriptionForBaseSkillPoints(points)
    return string.format("%s: %d", getLocalizedText(3, "BasePoints"), points)
end

local function getFullDescriptionForSingleSkill(id, level, isActive)
    if (not isActive) then
        return string.format("%s      %s: %d      %s: %.2f\n%s %s",
            getLocalizedText(5, id),
            getLocalizedText(3, "Level"),       level,
            getLocalizedText(3, "SkillPoints"), getSkillPoints(id, level, false),
            getLocalizedText(4, id),            getSkillModifierForDisplay(id, level, false)
        )
    else
        return string.format("%s      %s: %d      %s: %.2f      %s: %d\n%s %s",
            getLocalizedText(5, id),
            getLocalizedText(3, "Level"),       level,
            getLocalizedText(3, "SkillPoints"), getSkillPoints(id, level, true),
            getLocalizedText(3, "MinEnergy"),   getSkillEnergyRequirement(id, level),
            getLocalizedText(4, id),            getSkillModifierForDisplay(id, level, true)
        )
    end
end

local function getBriefDescriptionForSingleSkill(id, level, isActive)
    return string.format("%s\n%s %s",
        getLocalizedText(5, id),
        getLocalizedText(4, id), getSkillModifierForDisplay(id, level, isActive)
    )
end

local function getFullDescriptionForSkillGroup(skillGroup, skillGroupType)
    local isPassive = skillGroupType == SKILL_PASSIVE
    local prefix    = (isPassive)                                                     and
        (string.format("%s : ",    getLocalizedText(3, "PassiveSkill")))              or
        (string.format("%s %d : ", getLocalizedText(3, "ActiveSkill"), skillGroupType))

    if ((not isPassive) and (not skillGroup:isEnabled())) then
        return prefix .. getLocalizedText(3, "Disabled")
    end

    local descriptions = {
        string.format("%s    (%s: %.2f      %s: %.2f)",
            prefix,
            getLocalizedText(3, "TotalPoints"), skillGroup:getSkillPoints(),
            getLocalizedText(3, "MaxPoints"),   skillGroup:getMaxSkillPoints()
        )
    }
    if (not isPassive) then
        descriptions[#descriptions + 1] = string.format("%s:   %d",
            getLocalizedText(3, "EnergyRequirement"), skillGroup:getEnergyRequirement())
    end

    local slotsCount = (isPassive) and (PASSIVE_SLOTS_COUNT) or (ACTIVE_SLOTS_COUNT)
    local skills     = skillGroup:getAllSkills()
    for i = 1, slotsCount do
        local skill = skills[i]
        if (skill) then
            descriptions[#descriptions + 1] = string.format("%d. %s", i, getFullDescriptionForSingleSkill(skill.id, skill.level, not isPassive))
        else
            descriptions[#descriptions + 1] = string.format("%d. %s", i, getLocalizedText(3, "None"))
        end
    end

    return table.concat(descriptions, "\n")
end

local function getBriefDescriptionForSkillGroup(skillGroup, skillGroupType)
    local prefix    = getLocalizedText(3, skillGroupType) .. ":"
    if (skillGroup:isEmpty()) then
        return prefix .. " " .. getLocalizedText(3, "None")
    end

    local isActiveSkill = skillGroupType == SKILL_ACTIVE
    local descriptions  = {prefix}
    for i, skill in ipairs(skillGroup:getAllSkills()) do
        descriptions[#descriptions + 1] = string.format("%d. %s", i, getBriefDescriptionForSingleSkill(skill.id, skill.level, isActiveSkill))
    end

    return table.concat(descriptions, "\n")
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillDescriptionFunctions.getFullDescription(modelSkillConfiguration)
    return string.format("%s\n%s\n\n%s\n\n%s",
        getFullDescriptionForBaseSkillPoints(modelSkillConfiguration:getBaseSkillPoints()),
        getFullDescriptionForSkillGroup(modelSkillConfiguration:getModelSkillGroupPassive(),     SKILL_PASSIVE),
        getFullDescriptionForSkillGroup(modelSkillConfiguration:getModelSkillGroupResearching(), SKILL_RESEARCHING),
        getFullDescriptionForSkillGroup(modelSkillConfiguration:getModelSkillGroupActive(),      SKILL_ACTIVE)
    )
end

function SkillDescriptionFunctions.getBriefDescription(modelSkillConfiguration)
    local skillGroupPassive     = modelSkillConfiguration:getModelSkillGroupPassive()
    local skillGroupResearching = modelSkillConfiguration:getModelSkillGroupResearching()
    local skillGroupActive      = modelSkillConfiguration:getModelSkillGroupActive()
    if ((skillGroupPassive    :isEmpty())  and
        (skillGroupResearching:isEmpty())  and
        (skillGroupActive     :isEmpty())) then
        return getLocalizedText(3, "NoSkills")
    end

    return string.format("%s\n\n%s\n\n%s",
        getBriefDescriptionForSkillGroup(skillGroupPassive,     SKILL_PASSIVE),
        getBriefDescriptionForSkillGroup(skillGroupResearching, SKILL_RESEARCHING),
        getBriefDescriptionForSkillGroup(skillGroupActive,      SKILL_ACTIVE)
    )
end

return SkillDescriptionFunctions
