
local InstantSkillExecutor = {}

local AuxiliaryFunctions    = requireFW("src.app.utilities.AuxiliaryFunctions")
local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")

local math = math

local s_Executors = {}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function modifyModelUnitHp(modelUnit, modifier)
    local newHP     = math.min(100, modelUnit:getCurrentHP() + modifier)
    newHP           = math.max(1, newHP)
    modelUnit:setCurrentHP(newHP)
        :updateView()
end

--------------------------------------------------------------------------------
-- The functions for executing instant skills.
--------------------------------------------------------------------------------
s_Executors.execute3 = function(modelWar, level)
    local modifier     = modelWar:getModelSkillDataManager():getSkillModifier(3, level, true) * 10
    local playerIndex  = modelWar:getModelTurnManager():getPlayerIndex()
    local func         = function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            modifyModelUnitHp(modelUnit, modifier)
        end
    end

    modelWar:getModelWarField():getModelUnitMap():forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    modelWar:getScriptEventDispatcher():dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

s_Executors.execute4 = function(modelWar, level)
    local modifier     = modelWar:getModelSkillDataManager():getSkillModifier(4, level, true) * 10
    local playerIndex  = modelWar:getModelTurnManager():getPlayerIndex()
    local func         = function(modelUnit)
        if (modelUnit:getPlayerIndex() ~= playerIndex) then
            modifyModelUnitHp(modelUnit, modifier)
        end
    end

    modelWar:getModelWarField():getModelUnitMap():forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    modelWar:getScriptEventDispatcher():dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

s_Executors.execute7 = function(modelWar, level)
    local playerIndex = modelWar:getModelTurnManager():getPlayerIndex()
    local func        = function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndex)                                             and
            (not GameConstantFunctions.isTypeInCategory(modelUnit:getUnitType(), "InfantryUnits"))) then
            modelUnit:setStateIdle()
                :updateView()
        end
    end

    modelWar:getModelWarField():getModelUnitMap():forEachModelUnitOnMap(func)
        :forEachModelUnitLoaded(func)

    modelWar:getScriptEventDispatcher():dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

s_Executors.execute9 = function(modelWar, level)
    local playerIndex = modelWar:getModelTurnManager():getPlayerIndex()
    local fund        = 0
    SingletonGetters.getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == playerIndex) and (modelTile.getIncomeAmount)) then
            fund = fund + modelTile:getIncomeAmount()
        end
    end)

    local modelPlayer = SingletonGetters.getModelPlayerManager(modelWar):getModelPlayer(playerIndex)
    modelPlayer:setFund(AuxiliaryFunctions.round(modelPlayer:getFund() + fund * modelWar:getModelSkillDataManager():getSkillModifier(9, level, true) / 100))
end

s_Executors.execute10 = function(modelWar, level)
    local playerIndex = modelWar:getModelTurnManager():getPlayerIndex()
    local modifier    = modelWar:getModelSkillDataManager():getSkillModifier(10, level, true)
    SingletonGetters.getModelPlayerManager(modelWar):forEachModelPlayer(function(modelPlayer, index)
        if ((index ~= playerIndex) and (modelPlayer:isAlive())) then
            modelPlayer:setEnergy(math.max(0, modelPlayer:getEnergy() + modifier))
        end
    end)
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function InstantSkillExecutor.activateSkillGroup(modelWar, skillGroupID)
    local modelSkillConfiguration = modelWar:getModelPlayerManager():getModelPlayer(modelWar:getModelTurnManager():getPlayerIndex()):getModelSkillConfiguration()
    for _, skill in pairs(modelSkillConfiguration:getAllSkillsInGroup(skillGroupID)) do
        local id, level  = skill.id, skill.level
        local methodName = "execute" .. id
        if (s_Executors[methodName]) then
            s_Executors[methodName](modelWar, skill.level)
        end
    end

    return InstantSkillExecutor
end

function InstantSkillExecutor.executeInstantSkill(modelWar, skillID, skillLevel)
    local methodName = "execute" .. skillID
    if (s_Executors[methodName]) then
        s_Executors[methodName](modelWar, skillLevel)
    end

    return InstantSkillExecutor
end

return InstantSkillExecutor
