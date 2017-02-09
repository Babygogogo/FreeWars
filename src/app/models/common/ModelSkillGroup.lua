
local ModelSkillGroup = requireFW("src.global.functions.class")("ModelSkillGroup")

local SkillDataAccessors    = requireFW("src.app.utilities.SkillDataAccessors")

local SLOTS_COUNT = SkillDataAccessors.getPassiveSkillSlotsCount()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function initSlots(self, param)
    local slots = {}
    if (param) then
        for i = 1, SLOTS_COUNT do
            slots[#slots + 1] = param[i]
        end
    end

    self.m_Slots = slots
end

--------------------------------------------------------------------------------
-- The constructor and initializer.
--------------------------------------------------------------------------------
function ModelSkillGroup:ctor(param)
    initSlots(self, param)

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillGroup:toSerializableTable()
    local t     = {}
    local slots = self.m_Slots

    for i = 1, SLOTS_COUNT do
        local skill = slots[i]
        if (skill) then
            t[#t + 1] = {
                id    = skill.id,
                level = skill.level,
            }
        end
    end

    return t
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillGroup:isEmpty()
    local slots = self.m_Slots
    for i = 1, SLOTS_COUNT do
        if (slots[i]) then
            return false
        end
    end

    return true
end

function ModelSkillGroup:getAllSkills()
    return self.m_Slots
end

function ModelSkillGroup:setSkill(slotIndex, skillID, skillLevel)
    assert((slotIndex > 0) and (slotIndex <= SLOTS_COUNT) and (slotIndex == math.floor(slotIndex)),
        "ModelSkillGroup:setSkill() the param slotIndex is invalid.")
    self.m_Slots[slotIndex] = {
        id    = skillID,
        level = skillLevel,
    }

    return self
end

function ModelSkillGroup:clearAllSkills()
    self.m_Slots = {}

    return self
end

return ModelSkillGroup
