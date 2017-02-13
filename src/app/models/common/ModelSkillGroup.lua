
local ModelSkillGroup = requireFW("src.global.functions.class")("ModelSkillGroup")

local SkillDataAccessors    = requireFW("src.app.utilities.SkillDataAccessors")

local ipairs = ipairs

--------------------------------------------------------------------------------
-- The constructor and initializer.
--------------------------------------------------------------------------------
function ModelSkillGroup:ctor(param)
    self.m_Slots = param or {}

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillGroup:toSerializableTable()
    return self.m_Slots
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillGroup:isEmpty()
    return #self.m_Slots == 0
end

function ModelSkillGroup:getAllSkills()
    return self.m_Slots
end

function ModelSkillGroup:setSkill(slotIndex, skillID, skillLevel)
    assert((slotIndex > 0) and (slotIndex == math.floor(slotIndex)), "ModelSkillGroup:setSkill() the param slotIndex is invalid.")
    self.m_Slots[slotIndex] = {
        id    = skillID,
        level = skillLevel,
    }

    return self
end

function ModelSkillGroup:pushBackSkill(skillID, skillLevel)
    self.m_Slots[#self.m_Slots + 1] = {
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
