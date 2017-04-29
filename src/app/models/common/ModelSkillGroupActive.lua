
local ModelSkillGroupActive = requireFW("src.global.functions.class")("ModelSkillGroupActive")

local TableFunctions = requireFW("src.app.utilities.TableFunctions")

local pairs = pairs

local MAX_SLOTS_COUNT = 4

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
    local slots = self.m_Slots
    for i = 1, MAX_SLOTS_COUNT - 1 do
        if (not slots[i]) then
            for j = i + 1, MAX_SLOTS_COUNT do
                if (slots[j]) then
                    slots[i], slots[j] = slots[j], slots[i]
                    break
                end
            end
        end
        if (not slots[i]) then
            break
        end
    end

    return TableFunctions.deepClone(slots)
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

function ModelSkillGroupActive.getMaxSlotsCount()
    return MAX_SLOTS_COUNT
end

function ModelSkillGroupActive:getModelSkillDataManager()
    return self.m_ModelSkillDataManager
end

function ModelSkillGroupActive:isEmpty()
    return #self.m_Slots == 0
end

function ModelSkillGroupActive:getAllSkills()
    return self.m_Slots
end

function ModelSkillGroupActive:getTotalEnergyCost()
    local energyCost = 0
    for _, skill in pairs(self.m_Slots) do
        energyCost = energyCost + self.m_ModelSkillDataManager:getSkillPoints(skill.id, skill.level, true)
    end

    return energyCost
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
