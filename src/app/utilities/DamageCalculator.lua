
local DamageCalculator = {}

local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")
local VisibilityFunctions    = requireFW("src.app.utilities.VisibilityFunctions")
local ComponentManager       = requireFW("src.global.components.ComponentManager")

local isUnitVisible = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local math          = math

local COMMAND_TOWER_ATTACK_BONUS  = GameConstantFunctions.getCommandTowerAttackBonus()
local COMMAND_TOWER_DEFENSE_BONUS = GameConstantFunctions.getCommandTowerDefenseBonus()

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getNormalizedHP(hp)
    return math.ceil(hp / 10)
end

local function isInAttackRange(attackerGridIndex, targetGridIndex, minRange, maxRange)
    local distance = GridIndexFunctions.getDistance(attackerGridIndex, targetGridIndex)
    return (distance >= minRange) and (distance <= maxRange)
end

local function getEndingGridIndex(movePath)
    return movePath[#movePath]
end

local function getLuckValue(playerIndex, modelWar)
    return math.random(0, 10)
end

local function getAttackBonusMultiplier(attacker, modelWar)
    local modelTileMap = modelWar:getModelWarField():getModelTileMap()
    local playerIndex  = attacker:getPlayerIndex()
    local bonus        = modelWar:getAttackModifier()

    bonus = bonus + ((attacker.getPromotionAttackBonus) and (attacker:getPromotionAttackBonus()) or 0)
    modelTileMap:forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == playerIndex) and
            (modelTile:getTileType() == "CommandTower")) then
            bonus = bonus + COMMAND_TOWER_ATTACK_BONUS
        end
    end)

    local modelPlayer = modelWar:getModelPlayerManager():getModelPlayer(playerIndex)
    bonus = bonus + SkillModifierFunctions.getAttackModifierForSkillConfiguration(modelPlayer:getModelSkillConfiguration(), modelPlayer:isActivatingSkill())

    return math.max(1 + bonus / 100, 0)
end

local function getDefenseBonusMultiplier(attacker, attackerGridIndex, target, targetGridIndex, modelWar)
    if (not target.getUnitType) then
        return 1
    end

    local targetTile  = modelWar:getModelWarField():getModelTileMap():getModelTile(targetGridIndex)
    local playerIndex = target:getPlayerIndex()
    local bonus       = 0

    modelWar:getModelWarField():getModelTileMap():forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == playerIndex) and (modelTile:getTileType() == "CommandTower")) then
            bonus = bonus + COMMAND_TOWER_DEFENSE_BONUS
        end
    end)
    bonus = bonus + ((targetTile.getDefenseBonusAmount)                                                 and
        (targetTile:getDefenseBonusAmount(target:getUnitType()) * target:getNormalizedCurrentHP() / 10) or
        (0))
    bonus = bonus + ((target.getPromotionDefenseBonus) and
        (target:getPromotionDefenseBonus())            or
        (0))

    local modelPlayer = modelWar:getModelPlayerManager():getModelPlayer(playerIndex)
    bonus = bonus + SkillModifierFunctions.getDefenseModifierForSkillConfiguration(modelPlayer:getModelSkillConfiguration(), modelPlayer:isActivatingSkill())

    if (bonus >= 0) then
        return 1 / (1 + bonus / 100)
    else
        return 1 - bonus / 100
    end
end

local function canAttack(modelWar, attacker, attackerMovePath, target, targetMovePath)
    if ((not attacker)                                      or
        (not target)                                        or
        (attacker:getTeamIndex() == target:getTeamIndex())) then
        return false
    end

    local attackDoer  = ComponentManager.getComponent(attacker, "AttackDoer")
    local attackTaker = ComponentManager.getComponent(target,   "AttackTaker")
    if ((not attackDoer) or (not attackTaker)) then
        return false
    end

    local attackerGridIndex = (attackerMovePath) and (getEndingGridIndex(attackerMovePath)) or (attacker:getGridIndex())
    local targetGridIndex   = (targetMovePath)   and (getEndingGridIndex(targetMovePath))   or (target:getGridIndex())
    local isTargetDiving    = (target.isDiving) and (target:isDiving())
    if (((not attackDoer:canAttackAfterMove()) and (attackerMovePath) and (#attackerMovePath > 1))                                                                           or
        (not isInAttackRange(attackerGridIndex, targetGridIndex, attackDoer:getAttackRangeMinMax()))                                                                         or
        ((isTargetDiving) and (not attackDoer:canAttackDivingTarget()))                                                                                                      or
        ((target.getUnitType) and (not isUnitVisible(modelWar, targetGridIndex, target:getUnitType(), isTargetDiving, target:getPlayerIndex(), attacker:getPlayerIndex())))) then
        return false
    end

    return attackDoer:getBaseDamage(attackTaker:getDefenseType())
end

local function getBattleDamage(attackerMovePath, launchUnitID, targetGridIndex, modelWar, isWithLuck)
    local modelWarField = modelWar:getModelWarField()
    local modelUnitMap  = modelWarField:getModelUnitMap()
    local attacker      = modelUnitMap:getFocusModelUnit(attackerMovePath[1], launchUnitID)
    local target        = (modelUnitMap:getModelUnit(targetGridIndex)) or (modelWarField:getModelTileMap():getModelTile(targetGridIndex))

    if (not canAttack(modelWar, attacker, attackerMovePath, target, nil)) then
        return nil, nil
    end

    local attackerGridIndex = getEndingGridIndex(attackerMovePath)
    local attackDamage      = DamageCalculator.getAttackDamage(attacker, attackerGridIndex, attacker:getCurrentHP(), target, targetGridIndex, modelWar, isWithLuck)
    assert(attackDamage >= 0)

    if ((GridIndexFunctions.getDistance(attackerGridIndex, targetGridIndex) > 1) or
        (not canAttack(modelWar, target, nil, attacker, attackerMovePath)))      then
        return attackDamage, nil
    else
        return attackDamage, DamageCalculator.getAttackDamage(target, targetGridIndex, target:getCurrentHP() - attackDamage, attacker, attackerGridIndex, modelWar, isWithLuck)
    end
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function DamageCalculator.getAttackDamage(attacker, attackerGridIndex, attackerHP, target, targetGridIndex, modelWar, isWithLuck)
    local baseAttackDamage = ComponentManager.getComponent(attacker, "AttackDoer"):getBaseDamage(target:getDefenseType())
    if (not baseAttackDamage) then
        return nil
    elseif (attackerHP <= 0) then
        return 0
    else
        local luckValue = ((isWithLuck) and (target:isAffectedByLuck())) and
            (getLuckValue(attacker:getPlayerIndex(), modelWar))     or
            (0)

        return math.floor(
            (baseAttackDamage * getAttackBonusMultiplier(attacker, modelWar) + luckValue)
            * (getNormalizedHP(attackerHP) / 10)
            * getDefenseBonusMultiplier(attacker, attackerGridIndex, target, targetGridIndex, modelWar)
        )
    end
end

function DamageCalculator.getEstimatedBattleDamage(attackerMovePath, launchUnitID, targetGridIndex, modelWar)
    return getBattleDamage(attackerMovePath, launchUnitID, targetGridIndex, modelWar, false)
end

function DamageCalculator.getUltimateBattleDamage(attackerMovePath, launchUnitID, targetGridIndex, modelWar)
    return getBattleDamage(attackerMovePath, launchUnitID, targetGridIndex, modelWar, true)
end

return DamageCalculator
