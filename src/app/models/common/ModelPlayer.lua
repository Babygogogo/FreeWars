
--[[--------------------------------------------------------------------------------
-- ModelPlayer就是玩家。本类维护关于玩家在战局上的信息，如金钱、技能、能量值等。
--
-- 主要职责及使用场景举例：
--   同上
--
-- 其他：
--  - 玩家、co与技能
--    原版中有co的概念，而本作将取消co的概念，以技能的概念作为代替。
--    技能的概念源于AWDS中的co技能槽。原作中每个co有4个技能槽，允许玩家自由搭配技能。
--    本作中没有co，但同样存在技能的概念，且可用的技能将比原作的更多。这些技能同样由玩家自行搭配，并在战局上发挥作用。
--
--    为维持平衡性及避免玩家全部采取同一种搭配，本作将对技能搭配做出限制。
--    举例而言，每个可用技能都将消耗特定的技能点数，玩家可以任意组合技能，但技能总点数不能超过100点。
--    通过响应玩家的反馈，不断调整技能消耗点数，应该能够使得技能系统达到相对平衡的状态。这样一来，玩家的自由度也会得到提升，而不是局限于数量固定的、而且实力不平衡的co。
--
--  - 本类目前没有对应的view，因为暂时还不用显示。
--]]--------------------------------------------------------------------------------

local ModelPlayer = requireFW("src.global.functions.class")("ModelPlayer")

local ModelSkillConfiguration = requireFW("src.app.models.common.ModelSkillConfiguration")
local SerializationFunctions  = requireFW("src.app.utilities.SerializationFunctions")

local math = math

--------------------------------------------------------------------------------
-- The constructor.
--------------------------------------------------------------------------------
function ModelPlayer:ctor(param)
    self.m_Account                 = param.account
    self.m_CanActivateSkill        = param.canActivateSkill
    self.m_Energy                  = param.energy
    self.m_Fund                    = param.fund
    self.m_HasVotedForDraw         = param.hasVotedForDraw
    self.m_IsActivatingSkill       = param.isActivatingSkill
    self.m_IsAlive                 = param.isAlive
    self.m_IsSkillDeclared         = param.isSkillDeclared
    self.m_Nickname                = param.nickname
    self.m_ModelSkillConfiguration = ModelSkillConfiguration:create(param.skillConfiguration)
    self.m_PlayerIndex             = param.playerIndex

    return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelPlayer:toSerializableTable()
    return {
        account             = self:getAccount(),
        canActivateSkill    = self.m_CanActivateSkill,
        energy              = self.m_Energy,
        fund                = self:getFund(),
        hasVotedForDraw     = self:hasVotedForDraw(),
        isActivatingSkill   = self.m_IsActivatingSkill,
        isAlive             = self:isAlive(),
        isSkillDeclared     = self.m_IsSkillDeclared,
        nickname            = self:getNickname(),
        skillConfiguration  = self:getModelSkillConfiguration():toSerializableTable(),
        playerIndex         = self.m_PlayerIndex,
    }
end

function ModelPlayer:toSerializableReplayData()
    return {
        account             = self:getAccount(),
        canActivateSkill    = false,
        energy              = self.m_ModelSceneWar:getStartingEnergy(),
        fund                = self.m_ModelSceneWar:getStartingFund(),
        hasVotedForDraw     = nil,
        isActivatingSkill   = false,
        isAlive             = true,
        isSkillDeclared     = false,
        nickname            = self:getNickname(),
        skillConfiguration  = self:getModelSkillConfiguration():toSerializableReplayData(),
        playerIndex         = self.m_PlayerIndex,
    }
end

function ModelPlayer:onStartRunning(modelSceneWar)
    self.m_ModelSceneWar = modelSceneWar

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelPlayer:getAccount()
    return self.m_Account
end

function ModelPlayer:getNickname()
    return self.m_Nickname
end

function ModelPlayer:isAlive()
    return self.m_IsAlive
end

function ModelPlayer:setAlive(isAlive)
    self.m_IsAlive = isAlive

    return self
end

function ModelPlayer:getFund()
    return self.m_Fund
end

function ModelPlayer:setFund(fund)
    assert((fund >= 0) and (math.floor(fund) == fund),
        "ModelPlayer:setFund() the param is invalid. " .. SerializationFunctions.toErrorMessage(fund))
    self.m_Fund = fund

    return self
end

function ModelPlayer:hasVotedForDraw()
    return self.m_HasVotedForDraw
end

function ModelPlayer:setVotedForDraw(hasVoted)
    self.m_HasVotedForDraw = hasVoted

    return self
end

function ModelPlayer:getEnergy()
    return self.m_Energy
end

function ModelPlayer:setEnergy(energy)
    assert((energy >= 0) and (math.floor(energy) == energy),
        "ModelPlayer:setEnergy() the energy is invalid: " .. SerializationFunctions.toErrorMessage(energy))
    self.m_Energy = energy

    return self
end

function ModelPlayer:getModelSkillConfiguration()
    return self.m_ModelSkillConfiguration
end

function ModelPlayer:isActivatingSkill()
    return self.m_IsActivatingSkill
end

function ModelPlayer:setActivatingSkill(isActivating)
    self.m_IsActivatingSkill = isActivating
    if (not isActivating) then
        self.m_ModelSkillConfiguration:getModelSkillGroupActive():clearAllSkills()
    end

    return self
end

function ModelPlayer:isSkillDeclared()
    return self.m_IsSkillDeclared
end

function ModelPlayer:setSkillDeclared(isSkillDeclared)
    self.m_IsSkillDeclared = isSkillDeclared

    return self
end

function ModelPlayer:canActivateSkill()
    return self.m_CanActivateSkill
end

function ModelPlayer:setCanActivateSkill(canActivate)
    self.m_CanActivateSkill = canActivate

    return self
end

return ModelPlayer
