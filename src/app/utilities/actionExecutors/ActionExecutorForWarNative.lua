
local ActionExecutorForWarNative = {}

local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions     = requireFW("src.app.utilities.AuxiliaryFunctions")
local Destroyers             = requireFW("src.app.utilities.Destroyers")
local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local InstantSkillExecutor   = requireFW("src.app.utilities.InstantSkillExecutor")
local LocalizationFunctions  = requireFW("src.app.utilities.LocalizationFunctions")
local NativeWarManager       = requireFW("src.app.utilities.NativeWarManager")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")
local SupplyFunctions        = requireFW("src.app.utilities.SupplyFunctions")
local VisibilityFunctions    = requireFW("src.app.utilities.VisibilityFunctions")
local WebSocketManager       = requireFW("src.app.utilities.WebSocketManager")
local Actor                  = requireFW("src.global.actors.Actor")
local ActorManager           = requireFW("src.global.actors.ActorManager")

local getAdjacentGrids              = GridIndexFunctions.getAdjacentGrids
local getGridsWithinDistance        = GridIndexFunctions.getGridsWithinDistance
local getLocalizedText              = LocalizationFunctions.getLocalizedText
local getLoggedInAccountAndPassword = WebSocketManager.getLoggedInAccountAndPassword
local getModelFogMap                = SingletonGetters.getModelFogMap
local getModelGridEffect            = SingletonGetters.getModelGridEffect
local getModelMessageIndicator      = SingletonGetters.getModelMessageIndicator
local getModelPlayerManager         = SingletonGetters.getModelPlayerManager
local getModelTileMap               = SingletonGetters.getModelTileMap
local getModelTurnManager           = SingletonGetters.getModelTurnManager
local getModelUnitMap               = SingletonGetters.getModelUnitMap
local getModelWarField              = SingletonGetters.getModelWarField
local getScriptEventDispatcher      = SingletonGetters.getScriptEventDispatcher
local isUnitVisible                 = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local supplyWithAmmoAndFuel         = SupplyFunctions.supplyWithAmmoAndFuel
local math, string                  = math, string
local next, pairs, ipairs, unpack   = next, pairs, ipairs, unpack

local ACTION_CODES = ActionCodeFunctions.getFullList()
local UNIT_MAX_HP  = GameConstantFunctions.getUnitMaxHP()

--------------------------------------------------------------------------------
-- The functions for dispatching events.
--------------------------------------------------------------------------------
local function dispatchEvtModelPlayerUpdated(modelWarNative, playerIndex)
    getScriptEventDispatcher(modelWarNative):dispatchEvent({
        name        = "EvtModelPlayerUpdated",
        modelPlayer = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndex),
        playerIndex = playerIndex,
    })
end

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function runSceneMain(isPlayerLoggedIn, confirmText)
    local modelSceneMain = Actor.createModel("sceneMain.ModelSceneMain", {
        isPlayerLoggedIn = isPlayerLoggedIn,
        confirmText      = confirmText,
    })
    local viewSceneMain  = Actor.createView( "sceneMain.ViewSceneMain")

    ActorManager.setAndRunRootActor(Actor.createWithModelAndViewInstance(modelSceneMain, viewSceneMain), "FADE", 1)
end

local function isModelUnitDiving(modelUnit)
    return (modelUnit.isDiving) and (modelUnit:isDiving())
end

local function updateFundWithCost(modelWarNative, playerIndex, cost)
    local modelPlayer = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndex)
    modelPlayer:setFund(modelPlayer:getFund() - cost)

    if (playerIndex == getModelPlayerManager(modelWarNative):getPlayerIndexForHuman()) then
        modelWarNative:setTotalBuiltUnitValueForPlayer(modelWarNative:getTotalBuiltUnitValueForPlayer() + cost)
    else
        modelWarNative:setTotalBuiltUnitValueForAi(modelWarNative:getTotalBuiltUnitValueForAi() + cost)
    end

    dispatchEvtModelPlayerUpdated(modelWarNative, playerIndex)
end

local function promoteModelUnitOnProduce(modelUnit, modelWarNative)
    local modelPlayer = getModelPlayerManager(modelWarNative):getModelPlayer(modelUnit:getPlayerIndex())
    local modifier    = 0 -- SkillModifierFunctions.getPassivePromotionModifier(modelPlayer:getModelSkillConfiguration())
    if ((modifier > 0) and (modelUnit.setCurrentPromotion)) then
        modelUnit:setCurrentPromotion(modifier)
    end
end

local function produceActorUnit(modelWarNative, tiledID, unitID, gridIndex)
    local actorData = {
        tiledID       = tiledID,
        unitID        = unitID,
        GridIndexable = {x = gridIndex.x, y = gridIndex.y},
    }
    local actorUnit = Actor.createWithModelAndViewName("warReplay.ModelUnitForReplay", actorData, "common.ViewUnit")
    local modelUnit = actorUnit:getModel()
    promoteModelUnitOnProduce(modelUnit, modelWarNative)
    modelUnit:setStateActioned()
        :onStartRunning(modelWarNative)

    return actorUnit
end

local function getAndSupplyAdjacentModelUnits(modelWarNative, supplierGridIndex, playerIndex)
    assert(type(playerIndex) == "number", "ActionExecutorForWarNative-getAndSupplyAdjacentModelUnits() invalid playerIndex: " .. (playerIndex or ""))

    local modelUnitMap = getModelUnitMap(modelWarNative)
    local targets      = {}
    for _, adjacentGridIndex in pairs(getAdjacentGrids(supplierGridIndex, modelUnitMap:getMapSize())) do
        local target = modelUnitMap:getModelUnit(adjacentGridIndex)
        if ((target) and (target:getPlayerIndex() == playerIndex) and (supplyWithAmmoAndFuel(target))) then
            targets[#targets + 1] = target
        end
    end

    return targets
end

local function moveModelUnitWithAction(action, modelWarNative)
    local path               = action.path
    local pathNodes          = path.pathNodes
    local beginningGridIndex = pathNodes[1]
    local modelFogMap        = getModelFogMap(modelWarNative)
    local modelUnitMap       = getModelUnitMap(modelWarNative)
    local launchUnitID       = action.launchUnitID
    local focusModelUnit     = modelUnitMap:getFocusModelUnit(beginningGridIndex, launchUnitID)
    modelFogMap:updateMapForPathsWithModelUnitAndPath(focusModelUnit, pathNodes)

    local pathLength = #pathNodes
    if (pathLength <= 1) then
        return
    end

    local playerIndex     = focusModelUnit:getPlayerIndex()
    local actionCode      = action.actionCode
    local endingGridIndex = pathNodes[pathLength]
    if (focusModelUnit.setCapturingModelTile) then
        focusModelUnit:setCapturingModelTile(false)
    end
    if (focusModelUnit.setCurrentFuel) then
        focusModelUnit:setCurrentFuel(focusModelUnit:getCurrentFuel() - path.fuelConsumption)
    end
    if (focusModelUnit.setBuildingModelTile) then
        focusModelUnit:setBuildingModelTile(false)
    end
    if (focusModelUnit.getLoadUnitIdList) then
        for _, loadedModelUnit in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(focusModelUnit, true)) do
            loadedModelUnit:setGridIndex(endingGridIndex, false)
        end
    end
    if (not launchUnitID) then
        modelFogMap:updateMapForUnitsForPlayerIndexOnUnitLeave(playerIndex, beginningGridIndex, focusModelUnit:getVisionForPlayerIndex(playerIndex))
    end
    focusModelUnit:setGridIndex(endingGridIndex, false)
    if (actionCode ~= ACTION_CODES.ActionLoadModelUnit) then
        modelFogMap:updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, endingGridIndex, focusModelUnit:getVisionForPlayerIndex(playerIndex))
    end

    if (launchUnitID) then
        modelUnitMap:getModelUnit(beginningGridIndex):removeLoadUnitId(launchUnitID)
            :updateView()
            :showNormalAnimation()

        if (actionCode ~= ACTION_CODES.ActionLoadModelUnit) then
            modelUnitMap:setActorUnitUnloaded(launchUnitID, endingGridIndex)
        end
    else
        if (actionCode == ACTION_CODES.ActionLoadModelUnit) then
            modelUnitMap:setActorUnitLoaded(beginningGridIndex)
        else
            modelUnitMap:swapActorUnit(beginningGridIndex, endingGridIndex)
        end

        local modelTile = getModelTileMap(modelWarNative):getModelTile(beginningGridIndex)
        if (modelTile.setCurrentBuildPoint) then
            modelTile:setCurrentBuildPoint(modelTile:getMaxBuildPoint())
        end
        if (modelTile.setCurrentCapturePoint) then
            modelTile:setCurrentCapturePoint(modelTile:getMaxCapturePoint())
        end
    end
end

local function getBaseDamageCostWithTargetAndDamage(target, damage)
    if (not target.getBaseProductionCost) then
        return 0
    else
        local normalizedRemainingHP = math.ceil(math.max(0, target:getCurrentHP() - damage) / 10)
        return math.floor(target:getBaseProductionCost() * (target:getNormalizedCurrentHP() - normalizedRemainingHP) / 10)
    end
end

local function getLostValueWithModelUnitAndDamage(modelUnitMap, modelUnit, damage)
    local newNormalizedHP  = math.ceil(math.max(0, modelUnit:getCurrentHP() - (damage or 0)) / 10)
    local value            = modelUnit:getProductionCost() * (modelUnit:getNormalizedCurrentHP() - newNormalizedHP) / 10
    if (newNormalizedHP == 0) then
        for _, loadedModelUnit in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(modelUnit, true) or {}) do
            value = value + loadedModelUnit:getProductionCost() * loadedModelUnit:getNormalizedCurrentHP() / 10
        end
    end

    return value
end

local function getEnergyWithTargetAndDamage(target, damage, energyGainModifier)
    return math.floor((target:getNormalizedCurrentHP() - math.ceil(math.max(0, target:getCurrentHP() - (damage or 0)) / 10)) * energyGainModifier)
end

local function getEnergyGainModifierForModelPlayer(modelWarNative, modelPlayer)
    local skillConfiguration = modelPlayer:getModelSkillConfiguration()
    local modifier           = modelWarNative:getEnergyGainModifier() + SkillModifierFunctions.getEnergyGainModifierForSkillConfiguration(skillConfiguration)
    return modifier * (SkillModifierFunctions.getEnergyGainMultiplierForSkillConfiguration(skillConfiguration) / 100 + 1)
end

local function updateEnergyOnActionAttack(modelWarNative, attacker, target, attackDamage, counterDamage)
    if (not target.getUnitType) then
        return
    end

    local modelPlayerManager  = modelWarNative:getModelPlayerManager()
    local attackerModelPlayer = modelPlayerManager:getModelPlayer(attacker:getPlayerIndex())
    if (not attackerModelPlayer:isActivatingSkill()) then
        local modifier = getEnergyGainModifierForModelPlayer(modelWarNative, attackerModelPlayer)
        attackerModelPlayer:setEnergy(attackerModelPlayer:getEnergy()
            + getEnergyWithTargetAndDamage(target,   attackDamage,  modifier)
            + getEnergyWithTargetAndDamage(attacker, counterDamage, modifier)
        )
    end

    local targetModelPlayer = modelPlayerManager:getModelPlayer(target:getPlayerIndex())
    if (not targetModelPlayer:isActivatingSkill()) then
        local modifier = getEnergyGainModifierForModelPlayer(modelWarNative, targetModelPlayer)
        targetModelPlayer:setEnergy(targetModelPlayer:getEnergy()
            + getEnergyWithTargetAndDamage(target,   attackDamage,  modifier)
            + getEnergyWithTargetAndDamage(attacker, counterDamage, modifier)
        )
    end

    local modelUnitMap = SingletonGetters.getModelUnitMap(modelWarNative)
    if (target:getPlayerIndex() == modelPlayerManager:getPlayerIndexForHuman()) then
        modelWarNative:setTotalLostUnitValueForPlayer(modelWarNative:getTotalLostUnitValueForPlayer() + getLostValueWithModelUnitAndDamage(modelUnitMap, target,   attackDamage))
    else
        modelWarNative:setTotalLostUnitValueForPlayer(modelWarNative:getTotalLostUnitValueForPlayer() + getLostValueWithModelUnitAndDamage(modelUnitMap, attacker, counterDamage))
    end

    dispatchEvtModelPlayerUpdated(modelWarNative, attacker:getPlayerIndex())
end

local function getAdjacentPlasmaGridIndexes(gridIndex, modelTileMap)
    local mapSize     = modelTileMap:getMapSize()
    local indexes     = {[0] = gridIndex}
    local searchedMap = {[gridIndex.x] = {[gridIndex.y] = true}}

    local i = 0
    while (i <= #indexes) do
        for _, adjacentGridIndex in ipairs(getAdjacentGrids(indexes[i], mapSize)) do
            if (modelTileMap:getModelTile(adjacentGridIndex):getTileType() == "Plasma") then
                local x, y = adjacentGridIndex.x, adjacentGridIndex.y
                searchedMap[x] = searchedMap[x] or {}
                if (not searchedMap[x][y]) then
                    indexes[#indexes + 1] = adjacentGridIndex
                    searchedMap[x][y] = true
                end
            end
        end
        i = i + 1
    end

    indexes[0] = nil
    return indexes
end

local function callbackOnWarEndedForClient()
    runSceneMain(getLoggedInAccountAndPassword() ~= nil)
end

local function updateTileAndUnitMapOnVisibilityChanged(modelWarNative)
    local playerIndex = getModelPlayerManager(modelWarNative):getPlayerIndexForHuman()
    getModelTileMap(modelWarNative):forEachModelTile(function(modelTile)
        modelTile:updateView()
    end)
    getModelUnitMap(modelWarNative):forEachModelUnitOnMap(function(modelUnit)
        modelUnit:setViewVisible(isUnitVisible(modelWarNative, modelUnit:getGridIndex(), modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), playerIndex))
    end)

    getScriptEventDispatcher(modelWarNative)
        :dispatchEvent({name = "EvtModelTileMapUpdated"})
        :dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

--------------------------------------------------------------------------------
-- The executors for web actions.
--------------------------------------------------------------------------------
local function executeWebChat(action, modelWarNative)
    SingletonGetters.getModelMessageIndicator(modelWarNative):showMessage(string.format("%s[%s]%s: %s",
        getLocalizedText(65, "War"),
        AuxiliaryFunctions.getWarNameWithWarId(action.warID),
        getLocalizedText(65, "ReceiveChatText"),
        action.chatText
    ))
end

local function executeWebLogin(action, modelWarNative)
    local account, password = action.loginAccount, action.loginPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(26, account))
    end
end

local function executeWebLogout(action, modelWarNative)
    WebSocketManager.setLoggedInAccountAndPassword(nil, nil)
end

local function executeWebMessage(action, modelWarNative)
    local message = getLocalizedText(action.messageCode, unpack(action.messageParams or {}))
    getModelMessageIndicator(modelWarNative):showMessage(message)
end

local function executeWebRegister(action, modelWarNative)
    local account, password = action.registerAccount, action.registerPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(27, account))
    end
end

--------------------------------------------------------------------------------
-- The executors for war actions.
--------------------------------------------------------------------------------
local function executeActivateSkill(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local playerIndexInTurn     = getModelTurnManager(modelWarNative):getPlayerIndex()
    local modelPlayer           = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndexInTurn)
    local modelSkillGroupActive = modelPlayer:getModelSkillConfiguration():getModelSkillGroupActive()
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelSkillGroupActive:getTotalEnergyCost())
        :setActivatingSkill(true)
    for _, skill in ipairs(modelSkillGroupActive:getAllSkills()) do
        InstantSkillExecutor.executeInstantSkill(modelWarNative, skill.id, skill.level)
    end

    local modelGridEffect     = getModelGridEffect(modelWarNative)
    local playerIndexForHuman = getModelPlayerManager(modelWarNative):getPlayerIndexForHuman(modelWarNative)
    getModelUnitMap(modelWarNative):forEachModelUnitOnMap(function(modelUnit)
            local playerIndex = modelUnit:getPlayerIndex()
            if (playerIndex == playerIndexInTurn) then
                modelUnit:updateView()
                local gridIndex = modelUnit:getGridIndex()
                if (isUnitVisible(modelWarNative, gridIndex, modelUnit:getUnitType(), isModelUnitDiving(modelUnit), playerIndex, playerIndexForHuman)) then
                    modelGridEffect:showAnimationSkillActivation(gridIndex)
                end
            end
        end)
        :forEachModelUnitLoaded(function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndexInTurn) then
                modelUnit:updateView()
            end
        end)

    dispatchEvtModelPlayerUpdated(modelWarNative, playerIndexInTurn)

    modelWarNative:setExecutingAction(false)
end

local function executeAttack(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes           = action.path.pathNodes
    local attackDamage        = action.attackDamage
    local counterDamage       = action.counterDamage
    local attackerGridIndex   = pathNodes[#pathNodes]
    local targetGridIndex     = action.targetGridIndex
    local modelUnitMap        = getModelUnitMap(modelWarNative)
    local modelTileMap        = getModelTileMap(modelWarNative)
    local attacker            = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local attackTarget        = modelUnitMap:getModelUnit(targetGridIndex) or modelTileMap:getModelTile(targetGridIndex)
    local attackerPlayerIndex = attacker:getPlayerIndex()
    local targetPlayerIndex   = attackTarget:getPlayerIndex()
    moveModelUnitWithAction(action, modelWarNative)
    attacker:setStateActioned()

    updateEnergyOnActionAttack(modelWarNative, attacker, attackTarget, attackDamage, counterDamage)
    if (attacker:getPrimaryWeaponBaseDamage(attackTarget:getDefenseType())) then
        attacker:setPrimaryWeaponCurrentAmmo(attacker:getPrimaryWeaponCurrentAmmo() - 1)
    end
    if ((counterDamage) and (attackTarget:getPrimaryWeaponBaseDamage(attacker:getDefenseType()))) then
        attackTarget:setPrimaryWeaponCurrentAmmo(attackTarget:getPrimaryWeaponCurrentAmmo() - 1)
    end

    local attackerNewHP = math.max(0, attacker:getCurrentHP() - (counterDamage or 0))
    attacker:setCurrentHP(attackerNewHP)
    if (attackerNewHP == 0) then
        attackTarget:setCurrentPromotion(math.min(attackTarget:getMaxPromotion(), attackTarget:getCurrentPromotion() + 1))
        Destroyers.destroyActorUnitOnMap(modelWarNative, attackerGridIndex, false)
    end

    local modelPlayerManager = getModelPlayerManager(modelWarNative)
    if ((attackTarget.getUnitType)                                                                             and
        (modelPlayerManager:getPlayerIndexForHuman() == getModelTurnManager(modelWarNative):getPlayerIndex())) then
        modelWarNative:setTotalAttacksCount(modelWarNative:getTotalAttacksCount() + 1)
            :setTotalAttackDamage(modelWarNative:getTotalAttackDamage() + attackDamage)
        if (attackTarget:getCurrentHP() <= attackDamage) then
            modelWarNative:setTotalKillsCount(modelWarNative:getTotalKillsCount() + 1)
        end
    end

    local targetNewHP = math.max(0, attackTarget:getCurrentHP() - attackDamage)
    local targetVision, plasmaGridIndexes
    attackTarget:setCurrentHP(targetNewHP)
    if (targetNewHP == 0) then
        if (attackTarget.getUnitType) then
            targetVision = attackTarget:getVisionForPlayerIndex(targetPlayerIndex)

            attacker:setCurrentPromotion(math.min(attacker:getMaxPromotion(), attacker:getCurrentPromotion() + 1))
            Destroyers.destroyActorUnitOnMap(modelWarNative, targetGridIndex, false, true)
        else
            attackTarget:updateWithObjectAndBaseId(0)

            plasmaGridIndexes = getAdjacentPlasmaGridIndexes(targetGridIndex, modelTileMap)
            for _, gridIndex in ipairs(plasmaGridIndexes) do
                modelTileMap:getModelTile(gridIndex):updateWithObjectAndBaseId(0)
            end
        end
    end

    local modelTurnManager = getModelTurnManager(modelWarNative)
    local lostPlayerIndex  = action.lostPlayerIndex
    local isHumanLost      = (lostPlayerIndex == modelPlayerManager:getPlayerIndexForHuman())
    if ((isHumanLost) or (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)) then
        modelWarNative:setEnded(true)
    end

    attacker:moveViewAlongPathAndFocusOnTarget(pathNodes, isModelUnitDiving(attacker), targetGridIndex, function()
        attacker:updateView()
            :showNormalAnimation()
        attackTarget:updateView()
        if (attackerNewHP == 0) then
            attacker:removeViewFromParent()
        elseif ((targetNewHP == 0) and (attackTarget.getUnitType)) then
            attackTarget:removeViewFromParent()
        end

        local modelGridEffect = getModelGridEffect(modelWarNative)
        if (attackerNewHP == 0) then
            modelGridEffect:showAnimationExplosion(attackerGridIndex)
        elseif ((counterDamage) and (targetNewHP > 0)) then
            modelGridEffect:showAnimationDamage(attackerGridIndex)
        end

        if (targetNewHP > 0) then
            modelGridEffect:showAnimationDamage(targetGridIndex)
        else
            modelGridEffect:showAnimationExplosion(targetGridIndex)
            if (not attackTarget.getUnitType) then
                for _, gridIndex in ipairs(plasmaGridIndexes) do
                    modelTileMap:getModelTile(gridIndex):updateView()
                end
            end
        end

        if (targetVision) then
            getModelFogMap(modelWarNative):updateMapForUnitsForPlayerIndexOnUnitLeave(targetPlayerIndex, targetGridIndex, targetVision)
        end
        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarNative, lostPlayerIndex)
            getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        if (modelWarNative:isEnded()) then
            if (isHumanLost) then
                modelWarNative:showEffectLose(callbackOnWarEndedForClient)
            else
                if (modelWarNative:isCampaign()) then
                    NativeWarManager.updateCampaignHighScore(getModelWarField(modelWarNative):getWarFieldFileName(), modelWarNative:getTotalScoreForCampaign())
                end
                modelWarNative:showEffectWin(callbackOnWarEndedForClient)
            end
        elseif (lostPlayerIndex == modelTurnManager:getPlayerIndex()) then
            modelTurnManager:endTurnPhaseMain()
        end

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeBeginTurn(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local modelTurnManager   = getModelTurnManager(modelWarNative)
    local lostPlayerIndex    = action.lostPlayerIndex
    local modelPlayerManager = getModelPlayerManager(modelWarNative)
    if (not lostPlayerIndex) then
        modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
            modelWarNative:setExecutingAction(false)
        end)
    else
        local isHumanLost = (lostPlayerIndex == modelPlayerManager:getPlayerIndexForHuman())
        modelWarNative:setEnded((isHumanLost) or (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1))

        modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
            getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
            Destroyers.destroyPlayerForce(modelWarNative, lostPlayerIndex)

            if (not modelWarNative:isEnded()) then
                modelTurnManager:endTurnPhaseMain()
            elseif (lostPlayerIndex == modelPlayerManager:getPlayerIndexForHuman()) then
                modelWarNative:showEffectLose(callbackOnWarEndedForClient)
            else
                if (modelWarNative:isCampaign()) then
                    NativeWarManager.updateCampaignHighScore(getModelWarField(modelWarNative):getWarFieldFileName(), modelWarNative:getTotalScoreForCampaign())
                end
                modelWarNative:showEffectWin(callbackOnWarEndedForClient)
            end

            modelWarNative:setExecutingAction(false)
        end)
    end
end

local function executeBuildModelTile(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local focusModelUnit  = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile       = getModelTileMap(modelWarNative):getModelTile(endingGridIndex)
    local buildPoint      = modelTile:getCurrentBuildPoint() - focusModelUnit:getBuildAmount()
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    if (buildPoint > 0) then
        focusModelUnit:setBuildingModelTile(true)
        modelTile:setCurrentBuildPoint(buildPoint)
    else
        focusModelUnit:setBuildingModelTile(false)
            :setCurrentMaterial(focusModelUnit:getCurrentMaterial() - 1)
        modelTile:updateWithObjectAndBaseId(focusModelUnit:getBuildTiledIdWithTileType(modelTile:getTileType()))

        local playerIndex = focusModelUnit:getPlayerIndex()
        getModelFogMap(modelWarNative):updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndex, endingGridIndex, modelTile:getVisionForPlayerIndex(playerIndex))
    end

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()
        modelTile:updateView()

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeCaptureModelTile(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local modelTile       = getModelTileMap(modelWarNative):getModelTile(endingGridIndex)
    local focusModelUnit  = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    local modelFogMap  = getModelFogMap(modelWarNative)
    local capturePoint = modelTile:getCurrentCapturePoint() - focusModelUnit:getCaptureAmount()
    local previousVision, previousPlayerIndex
    if (capturePoint > 0) then
        focusModelUnit:setCapturingModelTile(true)
        modelTile:setCurrentCapturePoint(capturePoint)
    else
        previousPlayerIndex = modelTile:getPlayerIndex()
        previousVision      = (previousPlayerIndex > 0) and (modelTile:getVisionForPlayerIndex(previousPlayerIndex)) or (nil)

        local playerIndexActing = focusModelUnit:getPlayerIndex()
        focusModelUnit:setCapturingModelTile(false)
        modelTile:setCurrentCapturePoint(modelTile:getMaxCapturePoint())
            :updateWithPlayerIndex(playerIndexActing)

        modelFogMap:updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndexActing, endingGridIndex, modelTile:getVisionForPlayerIndex(playerIndexActing))
    end

    local modelPlayerManager = getModelPlayerManager(modelWarNative)
    local lostPlayerIndex    = action.lostPlayerIndex
    if (not lostPlayerIndex) then
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()

            if (capturePoint <= 0) then
                modelFogMap:updateMapForTilesForPlayerIndexOnLosingOwnership(previousPlayerIndex, endingGridIndex, previousVision)
            end
            updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

            modelWarNative:setExecutingAction(false)
        end)
    else
        local isHumanLost = (lostPlayerIndex == modelPlayerManager:getPlayerIndexForHuman())
        modelWarNative:setEnded((isHumanLost) or (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1))

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()

            getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
            Destroyers.destroyPlayerForce(modelWarNative, lostPlayerIndex)
            updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

            if (modelWarNative:isEnded()) then
                if (isHumanLost) then
                    modelWarNative:showEffectLose(callbackOnWarEndedForClient)
                else
                    if (modelWarNative:isCampaign()) then
                        NativeWarManager.updateCampaignHighScore(getModelWarField(modelWarNative):getWarFieldFileName(), modelWarNative:getTotalScoreForCampaign())
                    end
                    modelWarNative:showEffectWin(callbackOnWarEndedForClient)
                end
            end

            modelWarNative:setExecutingAction(false)
        end)
    end
end

local function executeDestroyOwnedModelUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local gridIndex    = action.gridIndex
    local modelUnitMap = getModelUnitMap(modelWarNative)
    local modelUnit    = modelUnitMap:getModelUnit(gridIndex)
    getModelFogMap(modelWarNative):updateMapForPathsWithModelUnitAndPath(modelUnit, {gridIndex})
    modelWarNative:setTotalLostUnitValueForPlayer(modelWarNative:getTotalLostUnitValueForPlayer() + getLostValueWithModelUnitAndDamage(modelUnitMap, modelUnit, 100))
    Destroyers.destroyActorUnitOnMap(modelWarNative, gridIndex, true)

    getModelGridEffect(modelWarNative):showAnimationExplosion(gridIndex)

    modelWarNative:setExecutingAction(false)
end

local function executeDive(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()
        :setDiving(true)

    focusModelUnit:moveViewAlongPath(pathNodes, false, function()
        focusModelUnit:updateView()
            :showNormalAnimation()

        if (isUnitVisible(modelWarNative, pathNodes[#pathNodes], focusModelUnit:getUnitType(), false, focusModelUnit:getPlayerIndex(), getModelPlayerManager(modelWarNative):getPlayerIndexForHuman())) then
            getModelGridEffect(modelWarNative):showAnimationDive(pathNodes[#pathNodes])
        end
        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeDropModelUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes        = action.path.pathNodes
    local modelUnitMap     = getModelUnitMap(modelWarNative)
    local endingGridIndex  = pathNodes[#pathNodes]
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    local playerIndex    = focusModelUnit:getPlayerIndex()
    local modelFogMap    = getModelFogMap(modelWarNative)
    local dropModelUnits = {}
    for _, dropDestination in ipairs(action.dropDestinations) do
        local gridIndex     = dropDestination.gridIndex
        local unitID        = dropDestination.unitID
        local dropModelUnit = modelUnitMap:getLoadedModelUnitWithUnitId(unitID)
        modelUnitMap:setActorUnitUnloaded(unitID, gridIndex)
        focusModelUnit:removeLoadUnitId(unitID)

        dropModelUnits[#dropModelUnits + 1] = dropModelUnit
        dropModelUnit:setGridIndex(gridIndex, false)
            :setStateActioned()
        if (dropModelUnit.getLoadUnitIdList) then
            for _, loadedModelUnit in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(dropModelUnit, true)) do
                loadedModelUnit:setGridIndex(gridIndex, false)
            end
        end

        modelFogMap:updateMapForPathsWithModelUnitAndPath(dropModelUnit, {endingGridIndex, gridIndex})
            :updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, dropModelUnit:getVisionForPlayerIndex(playerIndex))
    end

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()
        if (action.isDropBlocked) then
            getModelGridEffect(modelWarNative):showAnimationBlock(endingGridIndex)
        end

        for _, dropModelUnit in ipairs(dropModelUnits) do
            dropModelUnit:moveViewAlongPath({endingGridIndex, dropModelUnit:getGridIndex()}, isModelUnitDiving(dropModelUnit), function()
                dropModelUnit:updateView()
                    :showNormalAnimation()
            end)
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeEndTurn(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    getModelTurnManager(modelWarNative):endTurnPhaseMain()
    modelWarNative:setExecutingAction(false)
end

local function executeJoinModelUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local endingGridIndex  = pathNodes[#pathNodes]
    local modelUnitMap     = getModelUnitMap(modelWarNative)
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], launchUnitID)
    local targetModelUnit  = modelUnitMap:getModelUnit(endingGridIndex)
    modelUnitMap:removeActorUnitOnMap(endingGridIndex)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    if ((focusModelUnit.hasPrimaryWeapon) and (focusModelUnit:hasPrimaryWeapon())) then
        focusModelUnit:setPrimaryWeaponCurrentAmmo(math.min(
            focusModelUnit:getPrimaryWeaponMaxAmmo(),
            focusModelUnit:getPrimaryWeaponCurrentAmmo() + targetModelUnit:getPrimaryWeaponCurrentAmmo()
        ))
    end
    if (focusModelUnit.getJoinIncome) then
        local joinIncome = focusModelUnit:getJoinIncome(targetModelUnit)
        if (joinIncome ~= 0) then
            local playerIndex = focusModelUnit:getPlayerIndex()
            local modelPlayer = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndex)
            modelPlayer:setFund(modelPlayer:getFund() + joinIncome)
            dispatchEvtModelPlayerUpdated(modelWarNative, playerIndex)
        end
    end
    if (focusModelUnit.setCurrentHP) then
        local joinedNormalizedHP = math.min(10, focusModelUnit:getNormalizedCurrentHP() + targetModelUnit:getNormalizedCurrentHP())
        focusModelUnit:setCurrentHP(math.max(
            (joinedNormalizedHP - 1) * 10 + 1,
            math.min(
                focusModelUnit:getCurrentHP() + targetModelUnit:getCurrentHP(),
                UNIT_MAX_HP
            )
        ))
    end
    if (focusModelUnit.setCurrentFuel) then
        focusModelUnit:setCurrentFuel(math.min(
            targetModelUnit:getMaxFuel(),
            focusModelUnit:getCurrentFuel() + targetModelUnit:getCurrentFuel()
        ))
    end
    if (focusModelUnit.setCurrentMaterial) then
        focusModelUnit:setCurrentMaterial(math.min(
            focusModelUnit:getMaxMaterial(),
            focusModelUnit:getCurrentMaterial() + targetModelUnit:getCurrentMaterial()
        ))
    end
    if (focusModelUnit.setCurrentPromotion) then
        focusModelUnit:setCurrentPromotion(math.max(
            focusModelUnit:getCurrentPromotion(),
            targetModelUnit:getCurrentPromotion()
        ))
    end
    if (focusModelUnit.setCapturingModelTile) then
        focusModelUnit:setCapturingModelTile(targetModelUnit:isCapturingModelTile())
    end

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()
        targetModelUnit:removeViewFromParent()

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeLaunchFlare(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes         = action.path.pathNodes
    local targetGridIndex   = action.targetGridIndex
    local modelUnitMap      = getModelUnitMap(modelWarNative)
    local focusModelUnit    = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local playerIndexActing = focusModelUnit:getPlayerIndex()
    local flareAreaRadius   = focusModelUnit:getFlareAreaRadius()
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()
        :setCurrentFlareAmmo(focusModelUnit:getCurrentFlareAmmo() - 1)
    getModelFogMap(modelWarNative):updateMapForPathsForPlayerIndexWithFlare(playerIndexActing, targetGridIndex, flareAreaRadius)

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()

        local modelGridEffect = getModelGridEffect(modelWarNative)
        for _, gridIndex in pairs(getGridsWithinDistance(targetGridIndex, 0, flareAreaRadius, modelUnitMap:getMapSize())) do
            modelGridEffect:showAnimationFlare(gridIndex)
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeLaunchSilo(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarNative)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile      = getModelTileMap(modelWarNative):getModelTile(pathNodes[#pathNodes])
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()
    modelTile:updateWithObjectAndBaseId(focusModelUnit:getTileObjectIdAfterLaunch())

    local targetGridIndexes, targetModelUnits = {}, {}
    for _, gridIndex in pairs(getGridsWithinDistance(action.targetGridIndex, 0, 2, modelUnitMap:getMapSize())) do
        targetGridIndexes[#targetGridIndexes + 1] = gridIndex

        local modelUnit = modelUnitMap:getModelUnit(gridIndex)
        if ((modelUnit) and (modelUnit.setCurrentHP)) then
            modelUnit:setCurrentHP(math.max(1, modelUnit:getCurrentHP() - 30))
            targetModelUnits[#targetModelUnits + 1] = modelUnit
        end
    end

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()
        modelTile:updateView()
        for _, modelUnit in ipairs(targetModelUnits) do
            modelUnit:updateView()
        end

        local modelGridEffect = getModelGridEffect(modelWarNative)
        for _, gridIndex in ipairs(targetGridIndexes) do
            modelGridEffect:showAnimationSiloAttack(gridIndex)
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeLoadModelUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarNative)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    local loaderModelUnit = modelUnitMap:getModelUnit(pathNodes[#pathNodes])
    loaderModelUnit:addLoadUnitId(focusModelUnit:getUnitId())

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()
            :setViewVisible(false)
        loaderModelUnit:updateView()

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeProduceModelUnitOnTile(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local modelUnitMap      = getModelUnitMap(modelWarNative)
    local producedUnitID    = modelUnitMap:getAvailableUnitId()
    local playerIndex       = getModelTurnManager(modelWarNative):getPlayerIndex()
    local gridIndex         = action.gridIndex
    local producedActorUnit = produceActorUnit(modelWarNative, action.tiledID, producedUnitID, gridIndex)
    modelUnitMap:addActorUnitOnMap(producedActorUnit)
        :setAvailableUnitId(producedUnitID + 1)
    getModelFogMap(modelWarNative):updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, producedActorUnit:getModel():getVisionForPlayerIndex(playerIndex))
    updateFundWithCost(modelWarNative, playerIndex, action.cost)

    updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

    modelWarNative:setExecutingAction(false)
end

local function executeProduceModelUnitOnUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local pathNodes    = action.path.pathNodes
    local modelUnitMap = getModelUnitMap(modelWarNative)
    local producer     = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    producer:setStateActioned()

    local producedUnitID    = modelUnitMap:getAvailableUnitId()
    local producedActorUnit = produceActorUnit(modelWarNative, producer:getMovableProductionTiledId(), producedUnitID, pathNodes[#pathNodes])
    modelUnitMap:addActorUnitLoaded(producedActorUnit)
        :setAvailableUnitId(producedUnitID + 1)
    producer:addLoadUnitId(producedUnitID)
    if (producer.setCurrentMaterial) then
        producer:setCurrentMaterial(producer:getCurrentMaterial() - 1)
    end
    updateFundWithCost(modelWarNative, producer:getPlayerIndex(), action.cost)

    producer:moveViewAlongPath(pathNodes, isModelUnitDiving(producer), function()
        producer:updateView()
            :showNormalAnimation()

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeResearchPassiveSkill(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local skillID                 = action.skillID
    local skillLevel              = action.skillLevel
    local playerIndexInTurn       = getModelTurnManager(modelWarNative):getPlayerIndex()
    local modelPlayer             = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndexInTurn)
    local modelSkillConfiguration = modelPlayer:getModelSkillConfiguration()
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelWarNative:getModelSkillDataManager():getSkillPoints(skillID, skillLevel, false))
    modelSkillConfiguration:getModelSkillGroupResearching():pushBackSkill(skillID, skillLevel)

    local modelGridEffect     = getModelGridEffect(modelWarNative)
    local playerIndexForHuman = getModelPlayerManager(modelWarNative):getPlayerIndexForHuman(modelWarNative)
    getModelUnitMap(modelWarNative):forEachModelUnitOnMap(function(modelUnit)
            local playerIndex = modelUnit:getPlayerIndex()
            if (playerIndex == playerIndexInTurn) then
                modelUnit:updateView()
                local gridIndex = modelUnit:getGridIndex()
                if (isUnitVisible(modelWarNative, gridIndex, modelUnit:getUnitType(), isModelUnitDiving(modelUnit), playerIndex, playerIndexForHuman)) then
                    modelGridEffect:showAnimationSkillActivation(gridIndex)
                end
            end
        end)
        :forEachModelUnitLoaded(function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndexInTurn) then
                modelUnit:updateView()
            end
        end)

    dispatchEvtModelPlayerUpdated(modelWarNative, playerIndexInTurn)

    modelWarNative:setExecutingAction(false)
end

local function executeSupplyModelUnit(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()

        local modelGridEffect     = getModelGridEffect(modelWarNative)
        local playerIndexForHuman = getModelPlayerManager(modelWarNative):getPlayerIndexForHuman()
        for _, targetModelUnit in pairs(getAndSupplyAdjacentModelUnits(modelWarNative, pathNodes[#pathNodes], focusModelUnit:getPlayerIndex())) do
            targetModelUnit:updateView()

            local gridIndex = targetModelUnit:getGridIndex()
            if (isUnitVisible(modelWarNative, gridIndex, targetModelUnit:getUnitType(), isModelUnitDiving(targetModelUnit), targetModelUnit:getPlayerIndex(), playerIndexForHuman)) then
                modelGridEffect:showAnimationSupply(gridIndex)
            end
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeSurface(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()
        :setDiving(false)

    focusModelUnit:moveViewAlongPath(pathNodes, true, function()
        focusModelUnit:updateView()
            :showNormalAnimation()

        local gridIndex = pathNodes[#pathNodes]
        if (isUnitVisible(modelWarNative, gridIndex, focusModelUnit:getUnitType(), false, focusModelUnit:getPlayerIndex(), getModelPlayerManager(modelWarNative):getPlayerIndexForHuman())) then
            getModelGridEffect(modelWarNative):showAnimationSurface(gridIndex)
        end
        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        modelWarNative:setExecutingAction(false)
    end)
end

local function executeSurrender(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local modelPlayerManager = getModelPlayerManager(modelWarNative)
    local modelTurnManager   = getModelTurnManager(modelWarNative)
    local playerIndex        = modelTurnManager:getPlayerIndex()
    local modelPlayer        = modelPlayerManager:getModelPlayer(playerIndex)
    local isHumanLost        = (playerIndex == modelPlayerManager:getPlayerIndexForHuman())
    Destroyers.destroyPlayerForce(modelWarNative, playerIndex)
    modelWarNative:setEnded((isHumanLost) or (modelPlayerManager:getAliveTeamsCount() <= 1))

    updateTileAndUnitMapOnVisibilityChanged(modelWarNative)
    getModelMessageIndicator(modelWarNative):showMessage(getLocalizedText(74, "Surrender", modelPlayer:getNickname()))

    if (not modelWarNative:isEnded()) then
        modelTurnManager:endTurnPhaseMain()
    elseif (isHumanLost) then
        modelWarNative:showEffectLose(callbackOnWarEndedForClient)
    else
        if (modelWarNative:isCampaign()) then
            NativeWarManager.updateCampaignHighScore(getModelWarField(modelWarNative):getWarFieldFileName(), modelWarNative:getTotalScoreForCampaign())
        end
        modelWarNative:showEffectWin(callbackOnWarEndedForClient)
    end

    modelWarNative:setExecutingAction(false)
end

local function executeUpdateReserveSkills(action, modelWarNative)
    modelWarNative:setExecutingAction(true)
    local playerIndex = getModelTurnManager(modelWarNative):getPlayerIndex()
    local modelPlayer = getModelPlayerManager(modelWarNative):getModelPlayer(playerIndex)
    modelPlayer:getModelSkillConfiguration():getModelSkillGroupReserve():ctor(action.reserveSkills)

    getModelMessageIndicator(modelWarNative):showMessage(
        string.format("[%s] %s!", modelPlayer:getNickname(), getLocalizedText(22, "HasUpdatedReserveSkills"))
    )
    dispatchEvtModelPlayerUpdated(modelWarNative, playerIndex)

    modelWarNative:setExecutingAction(false)
end

local function executeWait(action, modelWarNative)
    modelWarNative:setExecutingAction(true)

    local path           = action.path
    local pathNodes      = path.pathNodes
    local focusModelUnit = getModelUnitMap(modelWarNative):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarNative)
    focusModelUnit:setStateActioned()

    focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
        focusModelUnit:updateView()
            :showNormalAnimation()

        updateTileAndUnitMapOnVisibilityChanged(modelWarNative)

        if (path.isBlocked) then
            getModelGridEffect(modelWarNative):showAnimationBlock(pathNodes[#pathNodes])
        end

        modelWarNative:setExecutingAction(false)
    end)
end

--------------------------------------------------------------------------------
-- The public function.
--------------------------------------------------------------------------------
function ActionExecutorForWarNative.execute(action, modelWarNative)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionExecutorForWarNative.executeReplayAction() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionChat)                   then executeWebChat(               action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionLogin)                  then executeWebLogin(              action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionLogout)                 then executeWebLogout(             action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionMessage)                then executeWebMessage(            action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionRegister)               then executeWebRegister(           action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionActivateSkill)          then executeActivateSkill(         action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionAttack)                 then executeAttack(                action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionBeginTurn)              then executeBeginTurn(             action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionBuildModelTile)         then executeBuildModelTile(        action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionCaptureModelTile)       then executeCaptureModelTile(      action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionDestroyOwnedModelUnit)  then executeDestroyOwnedModelUnit( action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionDive)                   then executeDive(                  action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionDropModelUnit)          then executeDropModelUnit(         action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionEndTurn)                then executeEndTurn(               action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionJoinModelUnit)          then executeJoinModelUnit(         action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionLaunchFlare)            then executeLaunchFlare(           action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionLaunchSilo)             then executeLaunchSilo(            action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionLoadModelUnit)          then executeLoadModelUnit(         action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnTile) then executeProduceModelUnitOnTile(action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnUnit) then executeProduceModelUnitOnUnit(action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionResearchPassiveSkill)   then executeResearchPassiveSkill(  action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionSupplyModelUnit)        then executeSupplyModelUnit(       action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionSurface)                then executeSurface(               action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionSurrender)              then executeSurrender(             action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionUpdateReserveSkills)    then executeUpdateReserveSkills(   action, modelWarNative)
    elseif (actionCode == ACTION_CODES.ActionWait)                   then executeWait(                  action, modelWarNative)
    end

    return ActionExecutorForWarNative
end

return ActionExecutorForWarNative
