
local ActionExecutorForWarReplay = {}

local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions     = requireFW("src.app.utilities.AuxiliaryFunctions")
local Destroyers             = requireFW("src.app.utilities.Destroyers")
local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local InstantSkillExecutor   = requireFW("src.app.utilities.InstantSkillExecutor")
local LocalizationFunctions  = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")
local SupplyFunctions        = requireFW("src.app.utilities.SupplyFunctions")
local WebSocketManager       = requireFW("src.app.utilities.WebSocketManager")
local Actor                  = requireFW("src.global.actors.Actor")
local ActorManager           = requireFW("src.global.actors.ActorManager")

local destroyActorUnitOnMap         = Destroyers.destroyActorUnitOnMap
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
local getScriptEventDispatcher      = SingletonGetters.getScriptEventDispatcher
local supplyWithAmmoAndFuel         = SupplyFunctions.supplyWithAmmoAndFuel
local math, string                  = math, string
local next, pairs, ipairs, unpack   = next, pairs, ipairs, unpack

local ACTION_CODES = ActionCodeFunctions.getFullList()
local UNIT_MAX_HP  = GameConstantFunctions.getUnitMaxHP()

--------------------------------------------------------------------------------
-- The functions for dispatching events.
--------------------------------------------------------------------------------
local function dispatchEvtModelPlayerUpdated(modelWarReplay, playerIndex)
    getScriptEventDispatcher(modelWarReplay):dispatchEvent({
        name        = "EvtModelPlayerUpdated",
        modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex),
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

local function updateFundWithCost(modelWarReplay, playerIndex, cost)
    local modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex)
    modelPlayer:setFund(modelPlayer:getFund() - cost)
    dispatchEvtModelPlayerUpdated(modelWarReplay, playerIndex)
end

local function promoteModelUnitOnProduce(modelUnit, modelWarReplay)
    local modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(modelUnit:getPlayerIndex())
    local modifier    = 0 -- SkillModifierFunctions.getPassivePromotionModifier(modelPlayer:getModelSkillConfiguration())
    if ((modifier > 0) and (modelUnit.setCurrentPromotion)) then
        modelUnit:setCurrentPromotion(modifier)
    end
end

local function produceActorUnit(modelWarReplay, tiledID, unitID, gridIndex)
    local actorData = {
        tiledID       = tiledID,
        unitID        = unitID,
        GridIndexable = {x = gridIndex.x, y = gridIndex.y},
    }
    local actorUnit = Actor.createWithModelAndViewName("warReplay.ModelUnitForReplay", actorData, "common.ViewUnit")
    local modelUnit = actorUnit:getModel()
    promoteModelUnitOnProduce(modelUnit, modelWarReplay)
    modelUnit:setStateActioned()
        :onStartRunning(modelWarReplay)

    return actorUnit
end

local function getAndSupplyAdjacentModelUnits(modelWarReplay, supplierGridIndex, playerIndex)
    assert(type(playerIndex) == "number", "ActionExecutorForWarReplay-getAndSupplyAdjacentModelUnits() invalid playerIndex: " .. (playerIndex or ""))

    local modelUnitMap = getModelUnitMap(modelWarReplay)
    local targets      = {}
    for _, adjacentGridIndex in pairs(getAdjacentGrids(supplierGridIndex, modelUnitMap:getMapSize())) do
        local target = modelUnitMap:getModelUnit(adjacentGridIndex)
        if ((target) and (target:getPlayerIndex() == playerIndex) and (supplyWithAmmoAndFuel(target))) then
            targets[#targets + 1] = target
        end
    end

    return targets
end

local function moveModelUnitWithAction(action, modelWarReplay)
    local path               = action.path
    local pathNodes          = path.pathNodes
    local beginningGridIndex = pathNodes[1]
    local modelFogMap        = getModelFogMap(modelWarReplay)
    local modelUnitMap       = getModelUnitMap(modelWarReplay)
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

        local modelTile = getModelTileMap(modelWarReplay):getModelTile(beginningGridIndex)
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

local function getEnergyModifierWithTargetAndDamage(target, damage, energyGainModifier)
    return math.floor((target:getNormalizedCurrentHP() - math.ceil(math.max(0, target:getCurrentHP() - (damage or 0)) / 10)) * energyGainModifier)
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

--------------------------------------------------------------------------------
-- The executors for web actions.
--------------------------------------------------------------------------------
local function executeWebChat(action, modelWarReplay)
    SingletonGetters.getModelMessageIndicator(modelWarReplay):showMessage(string.format("%s[%s]%s: %s",
        getLocalizedText(65, "War"),
        AuxiliaryFunctions.getWarNameWithWarId(action.warID),
        getLocalizedText(65, "ReceiveChatText"),
        action.chatText
    ))
end

local function executeWebLogin(action, modelWarReplay)
    local account, password = action.loginAccount, action.loginPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(26, account))
        runSceneMain(true)
    end
end

local function executeWebLogout(action, modelWarReplay)
    WebSocketManager.setLoggedInAccountAndPassword(nil, nil)
    runSceneMain(false, getLocalizedText(action.messageCode, unpack(action.messageParams or {})))
end

local function executeWebMessage(action, modelWarReplay)
    local message = getLocalizedText(action.messageCode, unpack(action.messageParams or {}))
    getModelMessageIndicator(modelWarReplay):showMessage(message)
end

local function executeWebRegister(action, modelWarReplay)
    local account, password = action.registerAccount, action.registerPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(27, account))
        runSceneMain(true)
    end
end

--------------------------------------------------------------------------------
-- The executors for war actions.
--------------------------------------------------------------------------------
local function executeActivateSkill(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local skillID                 = action.skillID
    local skillLevel              = action.skillLevel
    local isActiveSkill           = action.isActiveSkill
    local playerIndex             = getModelTurnManager(modelWarReplay):getPlayerIndex()
    local modelPlayer             = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex)
    local modelSkillConfiguration = modelPlayer:getModelSkillConfiguration()
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelWarReplay:getModelSkillDataManager():getSkillPoints(skillID, skillLevel, isActiveSkill))
    if (not isActiveSkill) then
        modelSkillConfiguration:getModelSkillGroupResearching():pushBackSkill(skillID, skillLevel)
    else
        modelPlayer:setActivatingSkill(true)
        InstantSkillExecutor.executeInstantSkill(modelWarReplay, skillID, skillLevel)
        modelSkillConfiguration:getModelSkillGroupActive():pushBackSkill(skillID, skillLevel)
    end

    if (not modelWarReplay:isFastExecutingActions()) then
        local modelGridEffect = getModelGridEffect(modelWarReplay)
        local func            = function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndex) then
                modelGridEffect:showAnimationSkillActivation(modelUnit:getGridIndex())
                modelUnit:updateView()
            end
        end
        getModelUnitMap(modelWarReplay):forEachModelUnitOnMap(func)
            :forEachModelUnitLoaded(func)

        getModelFogMap(modelWarReplay):updateView()
        dispatchEvtModelPlayerUpdated(modelWarReplay, playerIndex)
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeAttack(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes           = action.path.pathNodes
    local attackDamage        = action.attackDamage
    local counterDamage       = action.counterDamage
    local attackerGridIndex   = pathNodes[#pathNodes]
    local targetGridIndex     = action.targetGridIndex
    local modelUnitMap        = getModelUnitMap(modelWarReplay)
    local modelTileMap        = getModelTileMap(modelWarReplay)
    local attacker            = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local attackTarget        = modelUnitMap:getModelUnit(targetGridIndex) or modelTileMap:getModelTile(targetGridIndex)
    local attackerPlayerIndex = attacker:getPlayerIndex()
    local targetPlayerIndex   = attackTarget:getPlayerIndex()
    moveModelUnitWithAction(action, modelWarReplay)
    attacker:setStateActioned()

    if (attacker:getPrimaryWeaponBaseDamage(attackTarget:getDefenseType())) then
        attacker:setPrimaryWeaponCurrentAmmo(attacker:getPrimaryWeaponCurrentAmmo() - 1)
    end
    if ((counterDamage) and (attackTarget:getPrimaryWeaponBaseDamage(attacker:getDefenseType()))) then
        attackTarget:setPrimaryWeaponCurrentAmmo(attackTarget:getPrimaryWeaponCurrentAmmo() - 1)
    end

    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    if (attackTarget.getUnitType) then
        local attackerDamageCost  = getBaseDamageCostWithTargetAndDamage(attacker,     counterDamage or 0)
        local targetDamageCost    = getBaseDamageCostWithTargetAndDamage(attackTarget, attackDamage)
        local attackerModelPlayer = modelPlayerManager:getModelPlayer(attackerPlayerIndex)
        local targetModelPlayer   = modelPlayerManager:getModelPlayer(targetPlayerIndex)
        local energyGainModifier  = modelWarReplay:getEnergyGainModifier()
        local attackEnergy        = getEnergyModifierWithTargetAndDamage(attackTarget, attackDamage,  energyGainModifier)
        local counterEnergy       = getEnergyModifierWithTargetAndDamage(attacker,     counterDamage, energyGainModifier)

        if (not attackerModelPlayer:isActivatingSkill()) then
            attackerModelPlayer:setEnergy(attackerModelPlayer:getEnergy() + attackEnergy + counterEnergy)
        end
        if (not targetModelPlayer:isActivatingSkill()) then
            targetModelPlayer  :setEnergy(targetModelPlayer:getEnergy()   + attackEnergy + counterEnergy)
        end

        dispatchEvtModelPlayerUpdated(modelWarReplay, attackerPlayerIndex)
    end

    local attackerNewHP = math.max(0, attacker:getCurrentHP() - (counterDamage or 0))
    attacker:setCurrentHP(attackerNewHP)
    if (attackerNewHP == 0) then
        attackTarget:setCurrentPromotion(math.min(attackTarget:getMaxPromotion(), attackTarget:getCurrentPromotion() + 1))
        destroyActorUnitOnMap(modelWarReplay, attackerGridIndex, false)
    end

    local targetNewHP = math.max(0, attackTarget:getCurrentHP() - attackDamage)
    local targetVision, plasmaGridIndexes
    attackTarget:setCurrentHP(targetNewHP)
    if (targetNewHP == 0) then
        if (attackTarget.getUnitType) then
            targetVision = attackTarget:getVisionForPlayerIndex(targetPlayerIndex)

            attacker:setCurrentPromotion(math.min(attacker:getMaxPromotion(), attacker:getCurrentPromotion() + 1))
            destroyActorUnitOnMap(modelWarReplay, targetGridIndex, false, true)
        else
            attackTarget:updateWithObjectAndBaseId(0)

            plasmaGridIndexes = getAdjacentPlasmaGridIndexes(targetGridIndex, modelTileMap)
            for _, gridIndex in ipairs(plasmaGridIndexes) do
                modelTileMap:getModelTile(gridIndex):updateWithObjectAndBaseId(0)
            end
        end
    end

    local modelTurnManager   = getModelTurnManager(modelWarReplay)
    local lostPlayerIndex    = action.lostPlayerIndex
    local isInTurnPlayerLost = (lostPlayerIndex == attackerPlayerIndex)
    if (lostPlayerIndex) then
        modelWarReplay:setRemainingVotesForDraw(nil)
    end

    if (modelWarReplay:isFastExecutingActions()) then
        if (targetVision) then
            getModelFogMap(modelWarReplay):updateMapForUnitsForPlayerIndexOnUnitLeave(targetPlayerIndex, targetGridIndex, targetVision)
        end
        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
            if (modelPlayerManager:getAliveTeamsCount() <= 1) then
                modelWarReplay:setEnded(true)
            elseif (isInTurnPlayerLost) then
                modelTurnManager:endTurnPhaseMain()
            end
        end
        modelWarReplay:setExecutingAction(false)

    else
        if ((lostPlayerIndex) and (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)) then
            modelWarReplay:setEnded(true)
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

            local modelGridEffect = getModelGridEffect(modelWarReplay)
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
                getModelFogMap(modelWarReplay):updateMapForUnitsForPlayerIndexOnUnitLeave(targetPlayerIndex, targetGridIndex, targetVision)
            end
            if (lostPlayerIndex) then
                Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
                getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
            end

            getModelFogMap(modelWarReplay):updateView()

            if (modelWarReplay:isEnded()) then
                modelWarReplay:showEffectReplayEnd(callbackOnWarEndedForClient)
            elseif (isInTurnPlayerLost) then
                modelTurnManager:endTurnPhaseMain()
            end

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeBeginTurn(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local modelTurnManager   = getModelTurnManager(modelWarReplay)
    local lostPlayerIndex    = action.lostPlayerIndex
    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    if (lostPlayerIndex) then
        modelWarReplay:setRemainingVotesForDraw(nil)
    end

    if (modelWarReplay:isFastExecutingActions()) then
        if (not lostPlayerIndex) then
            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                modelWarReplay:setExecutingAction(false)
            end)
        else
            modelWarReplay:setEnded(modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)
            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
                if (not modelWarReplay:isEnded()) then
                    modelTurnManager:endTurnPhaseMain()
                end
                modelWarReplay:setExecutingAction(false)
            end)
        end

    else
        if (not lostPlayerIndex) then
            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                modelWarReplay:setExecutingAction(false)
            end)
        else
            modelWarReplay:setEnded(modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)

            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                local lostModelPlayer = modelPlayerManager:getModelPlayer(lostPlayerIndex)
                getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(74, "Lose", lostModelPlayer:getNickname()))
                Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
                getModelFogMap(modelWarReplay):updateView()

                if (not modelWarReplay:isEnded()) then
                    modelTurnManager:endTurnPhaseMain()
                else
                    modelWarReplay:showEffectReplayEnd(callbackOnWarEndedForClient)
                end

                modelWarReplay:setExecutingAction(false)
            end)
        end
    end
end

local function executeBuildModelTile(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local focusModelUnit  = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile       = getModelTileMap(modelWarReplay):getModelTile(endingGridIndex)
    local buildPoint      = modelTile:getCurrentBuildPoint() - focusModelUnit:getBuildAmount()
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    if (buildPoint > 0) then
        focusModelUnit:setBuildingModelTile(true)
        modelTile:setCurrentBuildPoint(buildPoint)
    else
        focusModelUnit:setBuildingModelTile(false)
            :setCurrentMaterial(focusModelUnit:getCurrentMaterial() - 1)
        modelTile:updateWithObjectAndBaseId(focusModelUnit:getBuildTiledIdWithTileType(modelTile:getTileType()))

        local playerIndex = focusModelUnit:getPlayerIndex()
        getModelFogMap(modelWarReplay):updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndex, endingGridIndex, modelTile:getVisionForPlayerIndex(playerIndex))
    end

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeCaptureModelTile(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local modelTile       = getModelTileMap(modelWarReplay):getModelTile(endingGridIndex)
    local focusModelUnit  = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    local modelFogMap  = getModelFogMap(modelWarReplay)
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

    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    local lostPlayerIndex    = action.lostPlayerIndex
    if (lostPlayerIndex) then
        modelWarReplay:setRemainingVotesForDraw(nil)
    end

    if (modelWarReplay:isFastExecutingActions()) then
        if (capturePoint <= 0) then
            modelFogMap:updateMapForTilesForPlayerIndexOnLosingOwnership(previousPlayerIndex, endingGridIndex, previousVision)
        end
        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
            modelWarReplay:setEnded(modelPlayerManager:getAliveTeamsCount() <= 1)
        end
        modelWarReplay:setExecutingAction(false)

    else
        if (not lostPlayerIndex) then
            focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
                focusModelUnit:updateView()
                    :showNormalAnimation()
                modelTile:updateView()

                if (capturePoint <= 0) then
                    modelFogMap:updateMapForTilesForPlayerIndexOnLosingOwnership(previousPlayerIndex, endingGridIndex, previousVision)
                end
                getModelFogMap(modelWarReplay):updateView()

                modelWarReplay:setExecutingAction(false)
            end)
        else
            modelWarReplay:setEnded(modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)

            focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
                focusModelUnit:updateView()
                    :showNormalAnimation()
                modelTile:updateView()

                getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
                Destroyers.destroyPlayerForce(modelWarReplay, lostPlayerIndex)
                getModelFogMap(modelWarReplay):updateView()

                if (modelWarReplay:isEnded()) then
                    modelWarReplay:showEffectReplayEnd(callbackOnWarEndedForClient)
                end

                modelWarReplay:setExecutingAction(false)
            end)
        end
    end
end

local function executeDeclareSkill(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local playerIndex = getModelTurnManager(modelWarReplay):getPlayerIndex()
    local modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex)
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelWarReplay:getModelSkillDataManager():getSkillDeclarationCost())
        :setSkillDeclared(true)

    if (not modelWarReplay:isFastExecutingActions()) then
        SingletonGetters.getModelMessageIndicator(modelWarReplay):showMessage(string.format("[%s]%s!", modelPlayer:getNickname(), getLocalizedText(22, "HasDeclaredSkill")))
        dispatchEvtModelPlayerUpdated(modelWarReplay, playerIndex)
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeDestroyOwnedModelUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local gridIndex = action.gridIndex
    getModelFogMap(modelWarReplay):updateMapForPathsWithModelUnitAndPath(getModelUnitMap(modelWarReplay):getModelUnit(gridIndex), {gridIndex})
    destroyActorUnitOnMap(modelWarReplay, gridIndex, true)

    if (not modelWarReplay:isFastExecutingActions()) then
        getModelGridEffect(modelWarReplay):showAnimationExplosion(gridIndex)
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeDive(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()
        :setDiving(true)

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, false, function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            getModelGridEffect(modelWarReplay):showAnimationDive(pathNodes[#pathNodes])
            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeDropModelUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes        = action.path.pathNodes
    local modelUnitMap     = getModelUnitMap(modelWarReplay)
    local endingGridIndex  = pathNodes[#pathNodes]
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    local playerIndex    = focusModelUnit:getPlayerIndex()
    local modelFogMap    = getModelFogMap(modelWarReplay)
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

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            if (action.isDropBlocked) then
                getModelGridEffect(modelWarReplay):showAnimationBlock(endingGridIndex)
            end

            for _, dropModelUnit in ipairs(dropModelUnits) do
                dropModelUnit:moveViewAlongPath({endingGridIndex, dropModelUnit:getGridIndex()}, isModelUnitDiving(dropModelUnit), function()
                    dropModelUnit:updateView()
                        :showNormalAnimation()
                end)
            end

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeEndTurn(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    getModelTurnManager(modelWarReplay):endTurnPhaseMain()
    modelWarReplay:setExecutingAction(false)
end

local function executeJoinModelUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local endingGridIndex  = pathNodes[#pathNodes]
    local modelUnitMap     = getModelUnitMap(modelWarReplay)
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], launchUnitID)
    local targetModelUnit  = modelUnitMap:getModelUnit(endingGridIndex)
    modelUnitMap:removeActorUnitOnMap(endingGridIndex)
    moveModelUnitWithAction(action, modelWarReplay)
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
            local modelPlayer = getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex)
            modelPlayer:setFund(modelPlayer:getFund() + joinIncome)
            dispatchEvtModelPlayerUpdated(modelWarReplay, playerIndex)
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

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            targetModelUnit:removeViewFromParent()

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeLaunchFlare(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes         = action.path.pathNodes
    local targetGridIndex   = action.targetGridIndex
    local modelUnitMap      = getModelUnitMap(modelWarReplay)
    local focusModelUnit    = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local playerIndexActing = focusModelUnit:getPlayerIndex()
    local flareAreaRadius   = focusModelUnit:getFlareAreaRadius()
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()
        :setCurrentFlareAmmo(focusModelUnit:getCurrentFlareAmmo() - 1)
    getModelFogMap(modelWarReplay):updateMapForPathsForPlayerIndexWithFlare(playerIndexActing, targetGridIndex, flareAreaRadius)

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            local modelGridEffect = getModelGridEffect(modelWarReplay)
            for _, gridIndex in pairs(getGridsWithinDistance(targetGridIndex, 0, flareAreaRadius, modelUnitMap:getMapSize())) do
                modelGridEffect:showAnimationFlare(gridIndex)
            end

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeLaunchSilo(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarReplay)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile      = getModelTileMap(modelWarReplay):getModelTile(pathNodes[#pathNodes])
    moveModelUnitWithAction(action, modelWarReplay)
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

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()
            for _, modelUnit in ipairs(targetModelUnits) do
                modelUnit:updateView()
            end

            local modelGridEffect = getModelGridEffect(modelWarReplay)
            for _, gridIndex in ipairs(targetGridIndexes) do
                modelGridEffect:showAnimationSiloAttack(gridIndex)
            end

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeLoadModelUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarReplay)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    local loaderModelUnit = modelUnitMap:getModelUnit(pathNodes[#pathNodes])
    loaderModelUnit:addLoadUnitId(focusModelUnit:getUnitId())

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
                :setViewVisible(false)
            loaderModelUnit:updateView()

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeProduceModelUnitOnTile(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local modelUnitMap      = getModelUnitMap(modelWarReplay)
    local producedUnitID    = modelUnitMap:getAvailableUnitId()
    local playerIndex       = getModelTurnManager(modelWarReplay):getPlayerIndex()
    local gridIndex         = action.gridIndex
    local producedActorUnit = produceActorUnit(modelWarReplay, action.tiledID, producedUnitID, gridIndex)
    modelUnitMap:addActorUnitOnMap(producedActorUnit)
        :setAvailableUnitId(producedUnitID + 1)
    getModelFogMap(modelWarReplay):updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, producedActorUnit:getModel():getVisionForPlayerIndex(playerIndex))
    updateFundWithCost(modelWarReplay, playerIndex, action.cost)

    if (not modelWarReplay:isFastExecutingActions()) then
        getModelFogMap(modelWarReplay):updateView()
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeProduceModelUnitOnUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local pathNodes    = action.path.pathNodes
    local modelUnitMap = getModelUnitMap(modelWarReplay)
    local producer     = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    producer:setStateActioned()

    local producedUnitID    = modelUnitMap:getAvailableUnitId()
    local producedActorUnit = produceActorUnit(modelWarReplay, producer:getMovableProductionTiledId(), producedUnitID, pathNodes[#pathNodes])
    modelUnitMap:addActorUnitLoaded(producedActorUnit)
        :setAvailableUnitId(producedUnitID + 1)
    producer:addLoadUnitId(producedUnitID)
    if (producer.setCurrentMaterial) then
        producer:setCurrentMaterial(producer:getCurrentMaterial() - 1)
    end
    updateFundWithCost(modelWarReplay, producer:getPlayerIndex(), action.cost)

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        producer:moveViewAlongPath(pathNodes, isModelUnitDiving(producer), function()
            producer:updateView()
                :showNormalAnimation()

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeSupplyModelUnit(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            local modelGridEffect = getModelGridEffect(modelWarReplay)
            for _, targetModelUnit in pairs(getAndSupplyAdjacentModelUnits(modelWarReplay, pathNodes[#pathNodes], focusModelUnit:getPlayerIndex())) do
                targetModelUnit:updateView()
                modelGridEffect:showAnimationSupply(targetModelUnit:getGridIndex())
            end

            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeSurface(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()
        :setDiving(false)

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, true, function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            getModelGridEffect(modelWarReplay):showAnimationSurface(pathNodes[#pathNodes])
            getModelFogMap(modelWarReplay):updateView()

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

local function executeSurrender(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    local modelTurnManager   = getModelTurnManager(modelWarReplay)
    local playerIndex        = modelTurnManager:getPlayerIndex()
    local modelPlayer        = modelPlayerManager:getModelPlayer(playerIndex)
    modelWarReplay:setRemainingVotesForDraw(nil)
    Destroyers.destroyPlayerForce(modelWarReplay, playerIndex)

    if (modelWarReplay:isFastExecutingActions()) then
        if (modelPlayerManager:getAliveTeamsCount() <= 1) then
            modelWarReplay:setEnded(true)
        else
            modelTurnManager:endTurnPhaseMain()
        end
    else
        modelWarReplay:setEnded(modelPlayerManager:getAliveTeamsCount() <= 1)

        getModelFogMap(modelWarReplay):updateView()
        getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(74, "Surrender", modelPlayer:getNickname()))

        if (not modelWarReplay:isEnded()) then
            modelTurnManager:endTurnPhaseMain()
        else
            modelWarReplay:showEffectReplayEnd(callbackOnWarEndedForClient)
        end
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeVoteForDraw(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local doesAgree          = action.doesAgree
    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    local modelPlayer        = modelPlayerManager:getModelPlayer(getModelTurnManager(modelWarReplay):getPlayerIndex())
    if (not doesAgree) then
        modelWarReplay:setRemainingVotesForDraw(nil)
    else
        local remainingVotes = (modelWarReplay:getRemainingVotesForDraw() or modelPlayerManager:getAlivePlayersCount()) - 1
        modelWarReplay:setRemainingVotesForDraw(remainingVotes)
        if (remainingVotes == 0) then
            modelWarReplay:setEnded(true)
        end
    end
    modelPlayer:setVotedForDraw(true)

    if (not modelWarReplay:isFastExecutingActions()) then
        if (not doesAgree) then
            getModelMessageIndicator(modelWarReplay):showMessage(getLocalizedText(74, "DisagreeDraw", modelPlayer:getNickname()))
        else
            local modelMessageIndicator = getModelMessageIndicator(modelWarReplay)
            modelMessageIndicator:showMessage(getLocalizedText(74, "AgreeDraw", modelPlayer:getNickname()))
            if (modelWarReplay:isEnded()) then
                modelMessageIndicator:showMessage(getLocalizedText(74, "EndWithDraw"))
            end
        end

        if (modelWarReplay:isEnded()) then
            modelWarReplay:showEffectReplayEnd(callbackOnWarEndedForClient)
        end
    end

    modelWarReplay:setExecutingAction(false)
end

local function executeWait(action, modelWarReplay)
    modelWarReplay:setExecutingAction(true)

    local path           = action.path
    local pathNodes      = path.pathNodes
    local focusModelUnit = getModelUnitMap(modelWarReplay):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarReplay)
    focusModelUnit:setStateActioned()

    if (modelWarReplay:isFastExecutingActions()) then
        modelWarReplay:setExecutingAction(false)
    else
        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            getModelFogMap(modelWarReplay):updateView()

            if (path.isBlocked) then
                getModelGridEffect(modelWarReplay):showAnimationBlock(pathNodes[#pathNodes])
            end

            modelWarReplay:setExecutingAction(false)
        end)
    end
end

--------------------------------------------------------------------------------
-- The public function.
--------------------------------------------------------------------------------
function ActionExecutorForWarReplay.executeReplayAction(action, modelWarReplay)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionExecutorForWarReplay.executeReplayAction() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionActivateSkill)          then executeActivateSkill(         action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionAttack)                 then executeAttack(                action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionBeginTurn)              then executeBeginTurn(             action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionBuildModelTile)         then executeBuildModelTile(        action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionCaptureModelTile)       then executeCaptureModelTile(      action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionDeclareSkill)           then executeDeclareSkill(          action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionDestroyOwnedModelUnit)  then executeDestroyOwnedModelUnit( action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionDive)                   then executeDive(                  action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionDropModelUnit)          then executeDropModelUnit(         action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionEndTurn)                then executeEndTurn(               action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionJoinModelUnit)          then executeJoinModelUnit(         action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionLaunchFlare)            then executeLaunchFlare(           action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionLaunchSilo)             then executeLaunchSilo(            action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionLoadModelUnit)          then executeLoadModelUnit(         action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnTile) then executeProduceModelUnitOnTile(action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnUnit) then executeProduceModelUnitOnUnit(action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionSupplyModelUnit)        then executeSupplyModelUnit(       action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionSurface)                then executeSurface(               action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionSurrender)              then executeSurrender(             action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionVoteForDraw)            then executeVoteForDraw(           action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionWait)                   then executeWait(                  action, modelWarReplay)
    else                                                                  error("ActionExecutorForWarReplay.executeReplayAction() invalid action: " .. SerializationFunctions.toString(action))
    end

    return ActionExecutorForWarReplay
end

function ActionExecutorForWarReplay.executeWebAction(action, modelWarReplay)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionExecutorForWarReplay.executeWebAction() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionChat)     then executeWebChat(    action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionLogin)    then executeWebLogin(   action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionLogout)   then executeWebLogout(  action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionMessage)  then executeWebMessage( action, modelWarReplay)
    elseif (actionCode == ACTION_CODES.ActionRegister) then executeWebRegister(action, modelWarReplay)
    end

    return ActionExecutorForWarReplay
end

return ActionExecutorForWarReplay
