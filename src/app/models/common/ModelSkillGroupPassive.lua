
local ModelSkillGroupPassive = requireFW("src.global.functions.class")("ModelSkillGroupPassive")

local TableFunctions = requireFW("src.app.utilities.TableFunctions")

local ipairs = ipairs

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function mergeSingleSkill(self, skillID, skillModifier)
    for _, skill in ipairs(self:getAllSkills()) do
        if (skill.id == skillID) then
            skill.modifier = skill.modifier + skillModifier
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- The constructor and initializer.
--------------------------------------------------------------------------------
function ModelSkillGroupPassive:ctor(param)
    self.m_Slots = TableFunctions.deepClone(param) or {}

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillGroupPassive:toSerializableTable()
    return TableFunctions.deepClone(self.m_Slots)
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelSkillGroupPassive:onStartRunning(modelWar)
    self.m_ModelSkillDataManager = modelWar:getModelSkillDataManager()

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
ModelSkillGroupPassive.isSkillGroupPassive = true

function ModelSkillGroupPassive:getModelSkillDataManager()
    return self.m_ModelSkillDataManager
end

function ModelSkillGroupPassive:isEmpty()
    return #self.m_Slots == 0
end

function ModelSkillGroupPassive:getAllSkills()
    return self.m_Slots
end

function ModelSkillGroupPassive:pushBackSkill(skillID, skillLevel)
    self.m_Slots[#self.m_Slots + 1] = {
        id       = skillID,
        modifier = self.m_ModelSkillDataManager:getSkillModifier(skillID, skillLevel, false),
    }

    return self
end

function ModelSkillGroupPassive:mergeSkillGroup(modelSkillGroup)
    local slots = self.m_Slots
    for _, mergingSkill in ipairs(modelSkillGroup:getAllSkills()) do
        if (not mergeSingleSkill(self, mergingSkill.id, mergingSkill.modifier)) then
            slots[#slots + 1] = mergingSkill
        end
    end

    return self
end

function ModelSkillGroupPassive:clearAllSkills()
    self.m_Slots = {}

    return self
end

return ModelSkillGroupPassive
