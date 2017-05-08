
local SkillDescriptionFunctions = {}

local ModelSkillConfiguration = requireFW("src.app.models.common.ModelSkillConfiguration")
local LocalizationFunctions   = requireFW("src.app.utilities.LocalizationFunctions")

local getLocalizedText = LocalizationFunctions.getLocalizedText
local string           = string

local SKILL_PASSIVE       = "SkillPassive"
local SKILL_RESEARCHING   = "SkillResearching"
local SKILL_ACTIVE        = "SkillActive"
local SKILL_RESERVE       = "SkillReserve"

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

local function getSkillModifierForDisplay(modelSkillDataManager, id, modifier)
    local modifierUnit = modelSkillDataManager:getSkillModifierUnit(id)
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
    elseif (id == 11) then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 12) then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 13) then return transformModifier3(modifier,  modifierUnit)
    elseif (id == 14) then return transformModifier3(modifier,  modifierUnit)
    else                   error("SkillDescriptionFunctions-getSkillModifierForDisplay() invalid skill id: " .. (id or ""))
    end
end

local function getBriefDescriptionForSingleSkill(modelSkillDataManager, id, modifier)
    return string.format("%s\n%s %s",
        getLocalizedText(5, id),
        getLocalizedText(4, id), getSkillModifierForDisplay(modelSkillDataManager, id, modifier)
    )
end

local function getBriefDescriptionForSkillGroup(modelSkillDataManager, skillGroup, skillGroupType)
    local prefix = getLocalizedText(3, skillGroupType) .. ":"
    if (skillGroup:isEmpty()) then
        return prefix .. " " .. getLocalizedText(3, "None")
    end

    local isActiveSkill = (skillGroupType == SKILL_ACTIVE) or (skillGroupType == SKILL_RESERVE)
    local descriptions  = (isActiveSkill)                                                                            and
        {string.format("%s    %s: %d", prefix, getLocalizedText(3, "EnergyCost"), skillGroup:getTotalEnergyCost())} or
        {prefix}
    for i, skill in ipairs(skillGroup:getAllSkills()) do
        local skillID  = skill.id
        local modifier = (isActiveSkill) and (modelSkillDataManager:getSkillModifier(skillID, skill.level, true)) or (skill.modifier)
        descriptions[#descriptions + 1] = string.format("%d. %s", i, getBriefDescriptionForSingleSkill(modelSkillDataManager, skillID, modifier))
    end

    return table.concat(descriptions, "\n")
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function SkillDescriptionFunctions.getBriefDescription(modelWar, modelSkillConfiguration)
    local skillGroupPassive     = modelSkillConfiguration:getModelSkillGroupPassive()
    local skillGroupResearching = modelSkillConfiguration:getModelSkillGroupResearching()
    local skillGroupActive      = modelSkillConfiguration:getModelSkillGroupActive()
    local skillGroupReserve     = modelSkillConfiguration:getModelSkillGroupReserve()
    if ((skillGroupPassive    :isEmpty())  and
        (skillGroupResearching:isEmpty())  and
        (skillGroupActive     :isEmpty())  and
        (skillGroupReserve    :isEmpty())) then
        return getLocalizedText(3, "NoSkills")
    end

    local modelSkillDataManager = modelWar:getModelSkillDataManager()
    return string.format("%s\n\n%s\n\n%s\n\n%s",
        getBriefDescriptionForSkillGroup(modelSkillDataManager, skillGroupPassive,     SKILL_PASSIVE),
        getBriefDescriptionForSkillGroup(modelSkillDataManager, skillGroupResearching, SKILL_RESEARCHING),
        getBriefDescriptionForSkillGroup(modelSkillDataManager, skillGroupActive,      SKILL_ACTIVE),
        getBriefDescriptionForSkillGroup(modelSkillDataManager, skillGroupReserve,     SKILL_RESERVE)
    )
end

function SkillDescriptionFunctions.getDescriptionForSkillGroupReserve(modelWar, modelSkillGroupReserve)
    return getBriefDescriptionForSkillGroup(modelWar:getModelSkillDataManager(), modelSkillGroupReserve, SKILL_RESERVE)
end

return SkillDescriptionFunctions
