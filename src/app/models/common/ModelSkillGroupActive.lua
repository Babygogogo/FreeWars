
local ModelSkillGroupActive = requireFW("src.global.functions.class")("ModelSkillGroupActive")

local TableFunctions = requireFW("src.app.utilities.TableFunctions")

--------------------------------------------------------------------------------
-- The constructor and initializer.
--------------------------------------------------------------------------------
function ModelSkillGroupActive:ctor(param)
    self.m_Slots = TableFunctions.deepClone(param) or {}

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillGroupActive:toSerializableTable()
    return TableFunctions.deepClone(self.m_Slots)
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelSkillGroupActive:onStartRunning(modelWar)
    self.m_ModelSkillDataManager = modelWar:getModelSkillDataManager()

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
ModelSkillGroupActive.isSkillGroupActive = true

function ModelSkillGroupActive:getModelSkillDataManager()
    return self.m_ModelSkillDataManager
end

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
