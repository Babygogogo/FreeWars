
local ModelSkillConfiguration = requireFW("src.global.functions.class")("ModelSkillConfiguration")

local ModelSkillGroupActive  = requireFW("src.app.models.common.ModelSkillGroupActive")
local ModelSkillGroupPassive = requireFW("src.app.models.common.ModelSkillGroupPassive")

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelSkillConfiguration:ctor(param)
    self.m_ModelSkillGroupPassive     = self.m_ModelSkillGroupPassive     or ModelSkillGroupPassive:create()
    self.m_ModelSkillGroupResearching = self.m_ModelSkillGroupResearching or ModelSkillGroupPassive:create()
    self.m_ModelSkillGroupActive      = self.m_ModelSkillGroupActive      or ModelSkillGroupActive :create()
    self.m_ModelSkillGroupReserve     = self.m_ModelSkillGroupReserve     or ModelSkillGroupActive :create()

    param = param or {}
    self.m_ModelSkillGroupPassive    :ctor(param.passiveSkills)
    self.m_ModelSkillGroupResearching:ctor(param.researchingSkills)
    self.m_ModelSkillGroupActive     :ctor(param.activeSkills)
    self.m_ModelSkillGroupReserve    :ctor(param.reserveSkills)

    return self
end

--------------------------------------------------------------------------------
-- The functions for serialization.
--------------------------------------------------------------------------------
function ModelSkillConfiguration:toSerializableTable()
    return {
        passiveSkills     = self.m_ModelSkillGroupPassive    :toSerializableTable(),
        researchingSkills = self.m_ModelSkillGroupResearching:toSerializableTable(),
        activeSkills      = self.m_ModelSkillGroupActive     :toSerializableTable(),
        reserveSkills     = self.m_ModelSkillGroupReserve    :toSerializableTable(),
    }
end

function ModelSkillConfiguration:toSerializableReplayData()
    return nil
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelSkillConfiguration:onStartRunning(modelWar)
    self.m_ModelSkillGroupPassive    :onStartRunning(modelWar)
    self.m_ModelSkillGroupResearching:onStartRunning(modelWar)
    self.m_ModelSkillGroupActive     :onStartRunning(modelWar)
    self.m_ModelSkillGroupReserve    :onStartRunning(modelWar)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelSkillConfiguration:getModelSkillGroupPassive()
    return self.m_ModelSkillGroupPassive
end

function ModelSkillConfiguration:getModelSkillGroupResearching()
    return self.m_ModelSkillGroupResearching
end

function ModelSkillConfiguration:getModelSkillGroupActive()
    return self.m_ModelSkillGroupActive
end

function ModelSkillConfiguration:getModelSkillGroupReserve()
    return self.m_ModelSkillGroupReserve
end

function ModelSkillConfiguration:mergePassiveAndResearchingSkills()
    self.m_ModelSkillGroupPassive:mergeSkillGroup(self.m_ModelSkillGroupResearching)
    self.m_ModelSkillGroupResearching:clearAllSkills()

    return self
end

function ModelSkillConfiguration:updateActiveAndReserveSkills()
    self.m_ModelSkillGroupActive:ctor(self.m_ModelSkillGroupReserve:getAllSkills())
    self.m_ModelSkillGroupReserve:clearAllSkills()

    return self
end

return ModelSkillConfiguration
