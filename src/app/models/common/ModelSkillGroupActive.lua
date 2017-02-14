
local ModelSkillGroupActive = requireFW("src.global.functions.class")("ModelSkillGroupActive")

--------------------------------------------------------------------------------
-- The constructor and initializer.
--------------------------------------------------------------------------------
function ModelSkillGroupActive:ctor(param)
    self.m_Slots = param or {}

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillGroupActive:toSerializableTable()
    return self.m_Slots
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
ModelSkillGroupActive.isSkillGroupActive = true

function ModelSkillGroupActive:isEmpty()
    return #self.m_Slots == 0
end

function ModelSkillGroupActive:getAllSkills()
    return self.m_Slots
end

function ModelSkillGroupActive:pushBackSkill(skillID, skillLevel)
    self.m_Slots[#self.m_Slots + 1] = {
        id    = skillID,
        level = skillLevel,
    }

    return self
end

function ModelSkillGroupActive:clearAllSkills()
    self.m_Slots = {}

    return self
end

return ModelSkillGroupActive
