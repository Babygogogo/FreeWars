
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

local function getSkillModifierForDisplay(id, modifier)
    local modifierUnit = getSkillModifierUnit(id)
    if     (id == 1)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 2)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 3)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 4)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 5)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 6)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 7)  then return ""
    elseif (id == 8)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 9)  then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 10) then return transformModifier3(modifier,  modifierUnit)
    else                   error("SkillDescriptionFunctions-getSkillModifierForDisplay() invalid skill id: " .. (id or ""))
    end
end

local function getBriefDescriptionForSingleSkill(id, modifier)
    return string.format("%s\n%s %s",
        getLocalizedText(5, id),
        getLocalizedText(4, id), getSkillModifierForDisplay(id, modifier)
    )
end

local function getBriefDescriptionForSkillGroup(skillGroup, skillGroupType)
    local prefix = getLocalizedText(3, skillGroupType) .. ":"
    if (skillGroup:isEmpty()) then
        return prefix .. " " .. getLocalizedText(3, "None")
    end

    local isActiveSkill = skillGroupType == SKILL_ACTIVE
    local descriptions  = {prefix}
    for i, skill in ipairs(skillGroup:getAllSkills()) do
        local skillID  = skill.id
        local modifier = (isActiveSkill) and (getSkillModifier(skillID, skill.level, true)) or (skill.modifier)
        descriptions[#descriptions + 1] = string.format("%d. %s", i, getBriefDescriptionForSingleSkill(skillID, modifier))
    end

    return table.concat(descriptions, "\n")
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
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
