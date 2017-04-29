
local ActionExecutorForWarOnline = {}

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
local VisibilityFunctions    = requireFW("src.app.utilities.VisibilityFunctions")
local Actor                  = requireFW("src.global.actors.Actor")

local ACTION_CODES         = ActionCodeFunctions.getFullList()
local UNIT_MAX_HP          = GameConstantFunctions.getUnitMaxHP()
local IS_SERVER            = GameConstantFunctions.isServer()
local PlayerProfileManager = (    IS_SERVER) and (requireFW("src.app.utilities.PlayerProfileManager")) or (nil)
local OnlineWarManager     = (    IS_SERVER) and (requireFW("src.app.utilities.OnlineWarManager"))      or (nil)
local WebSocketManager     = (not IS_SERVER) and (requireFW("src.app.utilities.WebSocketManager"))     or (nil)
local ActorManager         = (not IS_SERVER) and (requireFW("src.global.actors.ActorManager"))         or (nil)

local destroyActorUnitOnMap         = Destroyers.destroyActorUnitOnMap
local getAdjacentGrids              = GridIndexFunctions.getAdjacentGrids
local getGridsWithinDistance        = GridIndexFunctions.getGridsWithinDistance
local getLocalizedText              = LocalizationFunctions.getLocalizedText
local getLoggedInAccountAndPassword = (WebSocketManager) and (WebSocketManager.getLoggedInAccountAndPassword) or (nil)
local getModelFogMap                = SingletonGetters.getModelFogMap
local getModelGridEffect            = SingletonGetters.getModelGridEffect
local getModelMessageIndicator      = SingletonGetters.getModelMessageIndicator
local getModelPlayerManager         = SingletonGetters.getModelPlayerManager
local getModelTileMap               = SingletonGetters.getModelTileMap
local getModelTurnManager           = SingletonGetters.getModelTurnManager
local getModelUnitMap               = SingletonGetters.getModelUnitMap
local getPlayerIndexLoggedIn        = SingletonGetters.getPlayerIndexLoggedIn
local getScriptEventDispatcher      = SingletonGetters.getScriptEventDispatcher
local isTileVisible                 = VisibilityFunctions.isTileVisibleToPlayerIndex
local isUnitVisible                 = VisibilityFunctions.isUnitOnMapVisibleToPlayerIndex
local supplyWithAmmoAndFuel         = SupplyFunctions.supplyWithAmmoAndFuel

local math, string                  = math, string
local next, pairs, ipairs, unpack   = next, pairs, ipairs, unpack

--------------------------------------------------------------------------------
-- The functions for dispatching events.
--------------------------------------------------------------------------------
local function dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)
    getScriptEventDispatcher(modelWarOnline):dispatchEvent({
        name        = "EvtModelPlayerUpdated",
        modelPlayer = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex),
        playerIndex = playerIndex,
    })
end

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function runSceneMain(isPlayerLoggedIn, confirmText)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-runSceneMain() the main scene can't be run on the server.")

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

local function updateFundWithCost(modelWarOnline, playerIndex, cost)
    local modelPlayer = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex)
    modelPlayer:setFund(modelPlayer:getFund() - cost)
    dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)
end

local function promoteModelUnitOnProduce(modelUnit, modelWarOnline)
    local modelPlayer = getModelPlayerManager(modelWarOnline):getModelPlayer(modelUnit:getPlayerIndex())
    local modifier    = 0 -- SkillModifierFunctions.getPassivePromotionModifier(modelPlayer:getModelSkillConfiguration())
    if ((modifier > 0) and (modelUnit.setCurrentPromotion)) then
        modelUnit:setCurrentPromotion(modifier)
    end
end

local function produceActorUnit(modelWarOnline, tiledID, unitID, gridIndex)
    local actorData = {
        tiledID       = tiledID,
        unitID        = unitID,
        GridIndexable = {x = gridIndex.x, y = gridIndex.y},
    }
    local actorUnit = Actor.createWithModelAndViewName("warOnline.ModelUnitForOnline", actorData, "common.ViewUnit")
    local modelUnit = actorUnit:getModel()
    promoteModelUnitOnProduce(modelUnit, modelWarOnline)
    modelUnit:setStateActioned()
        :onStartRunning(modelWarOnline)

    return actorUnit
end

local function getAndSupplyAdjacentModelUnits(modelWarOnline, supplierGridIndex, playerIndex)
    assert(type(playerIndex) == "number", "ActionExecutorForWarOnline-getAndSupplyAdjacentModelUnits() invalid playerIndex: " .. (playerIndex or ""))

    local modelUnitMap = getModelUnitMap(modelWarOnline)
    local targets      = {}
    for _, adjacentGridIndex in pairs(getAdjacentGrids(supplierGridIndex, modelUnitMap:getMapSize())) do
        local target = modelUnitMap:getModelUnit(adjacentGridIndex)
        if ((target) and (target:getPlayerIndex() == playerIndex) and (supplyWithAmmoAndFuel(target))) then
            targets[#targets + 1] = target
        end
    end

    return targets
end

local function addActorUnitsWithUnitsData(modelWarOnline, unitsData, isViewVisible)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-addActorUnitsWithUnitsData() this should not be called on the server.")

    if (unitsData) then
        local modelUnitMap = getModelUnitMap(modelWarOnline)
        for unitID, unitData in pairs(unitsData) do
            local actorUnit = Actor.createWithModelAndViewName("warOnline.ModelUnitForOnline", unitData, "common.ViewUnit")
            actorUnit:getModel():onStartRunning(modelWarOnline)
                :updateView()
                :setViewVisible(isViewVisible)

            if (unitData.isLoaded) then
                modelUnitMap:addActorUnitLoaded(actorUnit)
            else
                modelUnitMap:addActorUnitOnMap(actorUnit)
            end
        end
    end
end

local function updateModelTilesWithTilesData(modelWarOnline, tilesData)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-updateModelTilesWithTilesData() this shouldn't be called on the server.")

    if (tilesData) then
        local modelTileMap = getModelTileMap(modelWarOnline)
        for _, tileData in pairs(tilesData) do
            local modelTile = modelTileMap:getModelTileWithPositionIndex(tileData.positionIndex)
            assert(modelTile:isFogEnabledOnClient(), "ActionExecutorForWarOnline-updateModelTilesWithTilesData() the tile has no fog.")
            modelTile:updateAsFogDisabled(tileData)
        end
    end
end

local function updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)
    if (not IS_SERVER) then
        addActorUnitsWithUnitsData(   modelWarOnline, action.actingUnitsData, false)
        addActorUnitsWithUnitsData(   modelWarOnline, action.revealedUnits,   false)
        updateModelTilesWithTilesData(modelWarOnline, action.actingTilesData)
        updateModelTilesWithTilesData(modelWarOnline, action.revealedTiles)
    end
end

local function updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-updateTileAndUnitMapOnVisibilityChanged(modelWarOnline) this shouldn't be called on the server.")
    local playerIndex      = getPlayerIndexLoggedIn(modelWarOnline)
    getModelTileMap(modelWarOnline):forEachModelTile(function(modelTile)
        if (isTileVisible(modelWarOnline, modelTile:getGridIndex(), playerIndex)) then
            modelTile:updateAsFogDisabled()
        else
            modelTile:updateAsFogEnabled()
        end
        modelTile:updateView()
    end)
    getModelUnitMap(modelWarOnline):forEachModelUnitOnMap(function(modelUnit)
        local gridIndex = modelUnit:getGridIndex()
        if (isUnitVisible(modelWarOnline, gridIndex, modelUnit:getUnitType(), isModelUnitDiving(modelUnit), modelUnit:getPlayerIndex(), playerIndex)) then
            modelUnit:setViewVisible(true)
        else
            destroyActorUnitOnMap(modelWarOnline, gridIndex, true)
        end
    end)

    getScriptEventDispatcher(modelWarOnline)
        :dispatchEvent({name = "EvtModelTileMapUpdated"})
        :dispatchEvent({name = "EvtModelUnitMapUpdated"})
end

local function moveModelUnitWithAction(action, modelWarOnline)
    local path               = action.path
    local pathNodes          = path.pathNodes
    local beginningGridIndex = pathNodes[1]
    local modelFogMap        = getModelFogMap(modelWarOnline)
    local modelUnitMap       = getModelUnitMap(modelWarOnline)
    local launchUnitID       = action.launchUnitID
    local focusModelUnit     = modelUnitMap:getFocusModelUnit(beginningGridIndex, launchUnitID)
    local playerIndex        = focusModelUnit:getPlayerIndex()
    local shouldUpdateFogMap = (IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndex, getPlayerIndexLoggedIn(modelWarOnline)))
    if (shouldUpdateFogMap) then
        modelFogMap:updateMapForPathsWithModelUnitAndPath(focusModelUnit, pathNodes)
    end

    local pathLength = #pathNodes
    if (pathLength <= 1) then
        return
    end

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
    if ((shouldUpdateFogMap) and (not launchUnitID)) then
        modelFogMap:updateMapForUnitsForPlayerIndexOnUnitLeave(playerIndex, beginningGridIndex, focusModelUnit:getVisionForPlayerIndex(playerIndex))
    end
    focusModelUnit:setGridIndex(endingGridIndex, false)
    if ((shouldUpdateFogMap) and (actionCode ~= ACTION_CODES.ActionLoadModelUnit)) then
        modelFogMap:updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, endingGridIndex, focusModelUnit:getVisionForPlayerIndex(playerIndex))
    end

    if (launchUnitID) then
        local loaderModelUnit = modelUnitMap:getModelUnit(beginningGridIndex)
        if (loaderModelUnit) then
            loaderModelUnit:removeLoadUnitId(launchUnitID)
                :updateView()
                :showNormalAnimation()
        else
            assert(not IS_SERVER, "ActionExecutorForWarOnline-moveModelUnitWithAction() failed to get the loader for the launching unit, on the server.")
        end

        if (actionCode ~= ACTION_CODES.ActionLoadModelUnit) then
            modelUnitMap:setActorUnitUnloaded(launchUnitID, endingGridIndex)
        end
    else
        if (actionCode == ACTION_CODES.ActionLoadModelUnit) then
            modelUnitMap:setActorUnitLoaded(beginningGridIndex)
        else
            modelUnitMap:swapActorUnit(beginningGridIndex, endingGridIndex)
        end

        local modelTile = getModelTileMap(modelWarOnline):getModelTile(beginningGridIndex)
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

local function cleanupOnReceivingResponseFromServer(modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-cleanupOnReceivingResponseFromServer() this shouldn't be invoked on the server.")

    getModelMessageIndicator(modelWarOnline):hidePersistentMessage(getLocalizedText(80, "TransferingData"))
    getScriptEventDispatcher(modelWarOnline):dispatchEvent({
        name    = "EvtIsWaitingForServerResponse",
        waiting = false,
    })
end

local function prepareForExecutingWarAction(action, modelWarOnline)
    local currentActionID = modelWarOnline:getActionId()
    local nextActionID    = action.actionID
    local warID           = action.warID

    if ((not warID) or (warID ~= modelWarOnline:getWarId()) or (nextActionID <= currentActionID) or (modelWarOnline:isEnded())) then
        assert(not IS_SERVER)
        return false

    elseif ((nextActionID > currentActionID + 1) or (modelWarOnline:isExecutingAction())) then
        assert(not IS_SERVER)
        modelWarOnline:cacheAction(action)
        return false

    else
        if (IS_SERVER) then
            modelWarOnline:pushBackExecutedAction(action)
        end
        modelWarOnline:setActionId(nextActionID)
            :setExecutingAction(true)

        return true
    end
end

--------------------------------------------------------------------------------
-- The executors for non-war actions.
--------------------------------------------------------------------------------
local function executeChat(action, modelWarOnline)
    SingletonGetters.getModelChatManager(modelWarOnline):updateWithChatMessage(action.channelID, action.senderPlayerIndex, action.chatText)
    if (IS_SERVER) then
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)
    end
end

local function executeLogin(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeLogin() should not be invoked on the server.")

    local account, password = action.loginAccount, action.loginPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        runSceneMain(true)
        getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(26, account))
    end
end

local function executeLogout(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeLogout() should not be invoked on the server.")

    WebSocketManager.setLoggedInAccountAndPassword(nil, nil)
    runSceneMain(false, getLocalizedText(action.messageCode, unpack(action.messageParams or {})))
end

local function executeMessage(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeMessage() should not be invoked on the server.")

    local message = getLocalizedText(action.messageCode, unpack(action.messageParams or {}))
    getModelMessageIndicator(modelWarOnline):showMessage(message)
end

local function executeNetworkHeartbeat(action, modelWarOnline)
    assert(IS_SERVER, "ActionExecutorForWarOnline-executeNetworkHeartbeat() should not be invoked on the client.")

    PlayerProfileManager.updateProfileWithNetworkHeartbeat(action.playerAccount)
end

local function executeRegister(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeRegister() should not be invoked on the server.")

    local account, password = action.registerAccount, action.registerPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        runSceneMain(true)
        getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(27, account))
    end
end

local function executeReloadSceneWar(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeReloadSceneWar() should not be invoked on the server.")

    local warData = action.warData
    if ((modelWarOnline:getWarId() == warData.warID) and (modelWarOnline:getActionId() <= warData.actionID)) then
        if (action.messageCode) then
            getModelMessageIndicator(modelWarOnline):showPersistentMessage(getLocalizedText(action.messageCode, unpack(action.messageParams or {})))
        end

        local actorSceneWar = Actor.createWithModelAndViewName("warOnline.ModelWarOnline", warData, "common.ViewSceneWar")
        ActorManager.setAndRunRootActor(actorSceneWar, "FADE", 1)
    end
end

local function executeRunSceneMain(action, modelWarOnline)
    assert(not IS_SERVER, "ActionExecutorForWarOnline-executeRunSceneMain() should not be invoked on the server.")

    local message = (action.messageCode) and (getLocalizedText(action.messageCode, unpack(action.messageParams or {}))) or (nil)
    runSceneMain(getLoggedInAccountAndPassword() ~= nil, message)
end

--------------------------------------------------------------------------------
-- The executors for war actions.
--------------------------------------------------------------------------------
local function executeActivateSkill(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local playerIndex           = getModelTurnManager(modelWarOnline):getPlayerIndex()
    local modelPlayer           = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex)
    local modelSkillGroupActive = modelPlayer:getModelSkillConfiguration():getModelSkillGroupActive()
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelSkillGroupActive:getTotalEnergyCost())
        :setActivatingSkill(true)

    for _, skill in ipairs(modelSkillGroupActive:getAllSkills()) do
        InstantSkillExecutor.executeInstantSkill(modelWarOnline, skill.id, skill.level)
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        local modelGridEffect = getModelGridEffect(modelWarOnline)
        local func            = function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndex) then
                modelGridEffect:showAnimationSkillActivation(modelUnit:getGridIndex())
                modelUnit:updateView()
            end
        end
        getModelUnitMap(modelWarOnline):forEachModelUnitOnMap(func)
            :forEachModelUnitLoaded(func)

        updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)
        dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeAttack(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes           = action.path.pathNodes
    local attackDamage        = action.attackDamage
    local counterDamage       = action.counterDamage
    local attackerGridIndex   = pathNodes[#pathNodes]
    local targetGridIndex     = action.targetGridIndex
    local modelUnitMap        = getModelUnitMap(modelWarOnline)
    local modelTileMap        = getModelTileMap(modelWarOnline)
    local attacker            = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local attackTarget        = modelUnitMap:getModelUnit(targetGridIndex) or modelTileMap:getModelTile(targetGridIndex)
    local attackerPlayerIndex = attacker:getPlayerIndex()
    local targetPlayerIndex   = attackTarget:getPlayerIndex()
    moveModelUnitWithAction(action, modelWarOnline)
    attacker:setStateActioned()

    if (attacker:getPrimaryWeaponBaseDamage(attackTarget:getDefenseType())) then
        attacker:setPrimaryWeaponCurrentAmmo(attacker:getPrimaryWeaponCurrentAmmo() - 1)
    end
    if ((counterDamage) and (attackTarget:getPrimaryWeaponBaseDamage(attacker:getDefenseType()))) then
        attackTarget:setPrimaryWeaponCurrentAmmo(attackTarget:getPrimaryWeaponCurrentAmmo() - 1)
    end

    local modelPlayerManager = getModelPlayerManager(modelWarOnline)
    if (attackTarget.getUnitType) then
        local attackerDamageCost  = getBaseDamageCostWithTargetAndDamage(attacker,     counterDamage or 0)
        local targetDamageCost    = getBaseDamageCostWithTargetAndDamage(attackTarget, attackDamage)
        local attackerModelPlayer = modelPlayerManager:getModelPlayer(attackerPlayerIndex)
        local targetModelPlayer   = modelPlayerManager:getModelPlayer(targetPlayerIndex)
        local energyGainModifier  = modelWarOnline:getEnergyGainModifier()
        local attackEnergy        = getEnergyModifierWithTargetAndDamage(attackTarget, attackDamage,  energyGainModifier)
        local counterEnergy       = getEnergyModifierWithTargetAndDamage(attacker,     counterDamage, energyGainModifier)

        if (not attackerModelPlayer:isActivatingSkill()) then
            local modifierForSkill = SkillModifierFunctions.getEnergyGainModifierForSkillConfiguration(attackerModelPlayer:getModelSkillConfiguration())
            attackerModelPlayer:setEnergy(attackerModelPlayer:getEnergy() + AuxiliaryFunctions.round((attackEnergy + counterEnergy) * (100 + modifierForSkill) / 100))
        end
        if (not targetModelPlayer:isActivatingSkill()) then
            local modifierForSkill = SkillModifierFunctions.getEnergyGainModifierForSkillConfiguration(targetModelPlayer:getModelSkillConfiguration())
            targetModelPlayer:setEnergy(targetModelPlayer:getEnergy() + AuxiliaryFunctions.round((attackEnergy + counterEnergy) * (100 + modifierForSkill) / 100))
        end

        dispatchEvtModelPlayerUpdated(modelWarOnline, attackerPlayerIndex)
    end

    local attackerNewHP = math.max(0, attacker:getCurrentHP() - (counterDamage or 0))
    attacker:setCurrentHP(attackerNewHP)
    if (attackerNewHP == 0) then
        attackTarget:setCurrentPromotion(math.min(attackTarget:getMaxPromotion(), attackTarget:getCurrentPromotion() + 1))
        destroyActorUnitOnMap(modelWarOnline, attackerGridIndex, false)
    end

    local targetNewHP = math.max(0, attackTarget:getCurrentHP() - attackDamage)
    local targetVision, plasmaGridIndexes
    attackTarget:setCurrentHP(targetNewHP)
    if (targetNewHP == 0) then
        if (attackTarget.getUnitType) then
            targetVision = attackTarget:getVisionForPlayerIndex(targetPlayerIndex)

            attacker:setCurrentPromotion(math.min(attacker:getMaxPromotion(), attacker:getCurrentPromotion() + 1))
            destroyActorUnitOnMap(modelWarOnline, targetGridIndex, false, true)
        else
            if ((not IS_SERVER) and (attackTarget:isFogEnabledOnClient())) then
                attackTarget:updateAsFogDisabled()
            end
            attackTarget:updateWithObjectAndBaseId(0)

            plasmaGridIndexes = getAdjacentPlasmaGridIndexes(targetGridIndex, modelTileMap)
            for _, gridIndex in ipairs(plasmaGridIndexes) do
                local modelTile = modelTileMap:getModelTile(gridIndex)
                if ((not IS_SERVER) and (modelTile:isFogEnabledOnClient())) then
                    modelTile:updateAsFogDisabled()
                end
                modelTile:updateWithObjectAndBaseId(0)
            end
        end
    end

    local modelTurnManager   = getModelTurnManager(modelWarOnline)
    local lostPlayerIndex    = action.lostPlayerIndex
    local isInTurnPlayerLost = (lostPlayerIndex == attackerPlayerIndex)
    if (lostPlayerIndex) then
        modelWarOnline:setRemainingVotesForDraw(nil)
    end

    if (IS_SERVER) then
        if (targetVision) then
            getModelFogMap(modelWarOnline):updateMapForUnitsForPlayerIndexOnUnitLeave(targetPlayerIndex, targetGridIndex, targetVision)
        end
        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
            if (modelPlayerManager:getAliveTeamsCount() <= 1) then
                modelWarOnline:setEnded(true)
            elseif (isInTurnPlayerLost) then
                modelTurnManager:endTurnPhaseMain()
            end

            PlayerProfileManager.updateProfilesWithModelWarOnline(modelWarOnline)
        end

        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        local playerIndexLoggedIn  = getPlayerIndexLoggedIn(modelWarOnline)
        local isLoggedInPlayerLost = lostPlayerIndex == playerIndexLoggedIn
        if ((isLoggedInPlayerLost) or (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)) then
            modelWarOnline:setEnded(true)
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

            local modelGridEffect = getModelGridEffect(modelWarOnline)
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

            if ((targetVision) and (getModelPlayerManager(modelWarOnline):isSameTeamIndex(targetPlayerIndex, playerIndexLoggedIn))) then
                getModelFogMap(modelWarOnline):updateMapForUnitsForPlayerIndexOnUnitLeave(targetPlayerIndex, targetGridIndex, targetVision)
            end
            if (lostPlayerIndex) then
                Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
                getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(74, "Lose", modelPlayerManager:getModelPlayer(lostPlayerIndex):getNickname()))
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            if (modelWarOnline:isEnded()) then
                if (isLoggedInPlayerLost) then modelWarOnline:showEffectLose(     callbackOnWarEndedForClient)
                else                           modelWarOnline:showEffectWin(      callbackOnWarEndedForClient)
                end
            elseif (isInTurnPlayerLost) then
                modelTurnManager:endTurnPhaseMain()
            end

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeBeginTurn(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end

    local modelTurnManager   = getModelTurnManager(modelWarOnline)
    local lostPlayerIndex    = action.lostPlayerIndex
    local modelPlayerManager = getModelPlayerManager(modelWarOnline)
    if (lostPlayerIndex) then
        modelWarOnline:setRemainingVotesForDraw(nil)
    end

    if (IS_SERVER) then
        modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData)

        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
            if (modelPlayerManager:getAliveTeamsCount() <= 1) then
                modelWarOnline:setEnded(true)
            else
                modelTurnManager:endTurnPhaseMain()
            end

            PlayerProfileManager.updateProfilesWithModelWarOnline(modelWarOnline)
        end

        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        if (not lostPlayerIndex) then
            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                local playerIndexInTurn = modelTurnManager:getPlayerIndex()
                if (playerIndexInTurn == modelPlayerManager:getPlayerIndexLoggedIn()) then
                    local modelMessageIndicator = getModelMessageIndicator(modelWarOnline)
                    modelPlayerManager:forEachModelPlayer(function(modelPlayer, playerIndex)
                        if ((playerIndex ~= playerIndexInTurn)                                                    and
                            (not modelPlayer:getModelSkillConfiguration():getModelSkillGroupReserve():isEmpty())) then
                            modelMessageIndicator:showMessage(string.format("[%s] %s!", modelPlayer:getAccount(), getLocalizedText(22, "HasUpdatedReserveSkills")))
                        end
                    end)
                end

                modelWarOnline:setExecutingAction(false)
            end)
        else
            local lostModelPlayer      = modelPlayerManager:getModelPlayer(lostPlayerIndex)
            local isLoggedInPlayerLost = lostModelPlayer:getAccount() == getLoggedInAccountAndPassword(modelWarOnline)
            if ((modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1) or (isLoggedInPlayerLost)) then
                modelWarOnline:setEnded(true)
            end

            modelTurnManager:beginTurnPhaseBeginning(action.income, action.repairData, action.supplyData, function()
                getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(74, "Lose", lostModelPlayer:getNickname()))
                Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
                updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

                if (not modelWarOnline:isEnded()) then
                    modelTurnManager:endTurnPhaseMain()
                elseif (isLoggedInPlayerLost) then
                    modelWarOnline:showEffectLose(callbackOnWarEndedForClient)
                else
                    modelWarOnline:showEffectWin(callbackOnWarEndedForClient)
                end

                modelWarOnline:setExecutingAction(false)
            end)
        end
    end
end

local function executeBuildModelTile(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local focusModelUnit  = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile       = getModelTileMap(modelWarOnline):getModelTile(endingGridIndex)
    local buildPoint      = modelTile:getCurrentBuildPoint() - focusModelUnit:getBuildAmount()
    if ((not IS_SERVER) and (modelTile:isFogEnabledOnClient())) then
        modelTile:updateAsFogDisabled()
    end
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()

    if (buildPoint > 0) then
        focusModelUnit:setBuildingModelTile(true)
        modelTile:setCurrentBuildPoint(buildPoint)
    else
        focusModelUnit:setBuildingModelTile(false)
            :setCurrentMaterial(focusModelUnit:getCurrentMaterial() - 1)
        modelTile:updateWithObjectAndBaseId(focusModelUnit:getBuildTiledIdWithTileType(modelTile:getTileType()))

        local playerIndex = focusModelUnit:getPlayerIndex()
        if ((IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndex, getPlayerIndexLoggedIn(modelWarOnline)))) then
            getModelFogMap(modelWarOnline):updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndex, endingGridIndex, modelTile:getVisionForPlayerIndex(playerIndex))
        end
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeCaptureModelTile(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes       = action.path.pathNodes
    local endingGridIndex = pathNodes[#pathNodes]
    local modelTile       = getModelTileMap(modelWarOnline):getModelTile(endingGridIndex)
    local focusModelUnit  = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    if ((not IS_SERVER) and (modelTile:isFogEnabledOnClient())) then
        modelTile:updateAsFogDisabled()
    end
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()

    local modelFogMap         = getModelFogMap(modelWarOnline)
    local playerIndexLoggedIn = (not IS_SERVER) and (getPlayerIndexLoggedIn(modelWarOnline)) or (nil)
    local capturePoint        = modelTile:getCurrentCapturePoint() - focusModelUnit:getCaptureAmount()
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

        if ((IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndexActing, playerIndexLoggedIn))) then
            modelFogMap:updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndexActing, endingGridIndex, modelTile:getVisionForPlayerIndex(playerIndexActing))
        end
    end

    local modelPlayerManager = getModelPlayerManager(modelWarOnline)
    local lostPlayerIndex    = action.lostPlayerIndex
    if (lostPlayerIndex) then
        modelWarOnline:setRemainingVotesForDraw(nil)
    end

    if (IS_SERVER) then
        if (capturePoint <= 0) then
            modelFogMap:updateMapForTilesForPlayerIndexOnLosingOwnership(previousPlayerIndex, endingGridIndex, previousVision)
        end
        if (lostPlayerIndex) then
            Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
            modelWarOnline:setEnded(modelPlayerManager:getAliveTeamsCount() <= 1)
            PlayerProfileManager.updateProfilesWithModelWarOnline(modelWarOnline)
        end

        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        if (not lostPlayerIndex) then
            focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
                focusModelUnit:updateView()
                    :showNormalAnimation()
                modelTile:updateView()

                if ((capturePoint <= 0) and (getModelPlayerManager(modelWarOnline):isSameTeamIndex(previousPlayerIndex, playerIndexLoggedIn))) then
                    modelFogMap:updateMapForTilesForPlayerIndexOnLosingOwnership(previousPlayerIndex, endingGridIndex, previousVision)
                end
                updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

                modelWarOnline:setExecutingAction(false)
            end)
        else
            local lostModelPlayer      = modelPlayerManager:getModelPlayer(lostPlayerIndex)
            local isLoggedInPlayerLost = lostModelPlayer:getAccount() == getLoggedInAccountAndPassword()
            if ((isLoggedInPlayerLost) or (modelPlayerManager:getAliveTeamsCount(lostPlayerIndex) <= 1)) then
                modelWarOnline:setEnded(true)
            end

            focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
                focusModelUnit:updateView()
                    :showNormalAnimation()
                modelTile:updateView()

                getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(74, "Lose", lostModelPlayer:getNickname()))
                Destroyers.destroyPlayerForce(modelWarOnline, lostPlayerIndex)
                updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

                if     (not modelWarOnline:isEnded()) then -- do nothing.
                elseif (isLoggedInPlayerLost)        then modelWarOnline:showEffectLose(     callbackOnWarEndedForClient)
                else                                      modelWarOnline:showEffectWin(      callbackOnWarEndedForClient)
                end

                modelWarOnline:setExecutingAction(false)
            end)
        end
    end
end

local function executeDestroyOwnedModelUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local gridIndex           = action.gridIndex
    local modelUnitMap        = getModelUnitMap(modelWarOnline)
    local playerIndexActing   = getModelTurnManager(modelWarOnline):getPlayerIndex()
    local playerIndexLoggedIn = (not IS_SERVER) and (getPlayerIndexLoggedIn(modelWarOnline)) or (nil)

    if (gridIndex) then
        if ((IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndexActing, playerIndexLoggedIn))) then
            getModelFogMap(modelWarOnline):updateMapForPathsWithModelUnitAndPath(modelUnitMap:getModelUnit(gridIndex), {gridIndex})
        end
        destroyActorUnitOnMap(modelWarOnline, gridIndex, true)
    else
        assert(not IS_SERVER, "ActionExecutorForWarOnline-executeDestroyOwnedModelUnit() the gridIndex must exist on server.")
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        if (gridIndex) then
            getModelGridEffect(modelWarOnline):showAnimationExplosion(gridIndex)

            if (playerIndexActing == playerIndexLoggedIn) then
                for _, adjacentGridIndex in pairs(GridIndexFunctions.getAdjacentGrids(gridIndex, modelUnitMap:getMapSize())) do
                    local adjacentModelUnit = modelUnitMap:getModelUnit(adjacentGridIndex)
                    if ((adjacentModelUnit)                                                                                                                                                                     and
                        (not isUnitVisible(modelWarOnline, adjacentGridIndex, adjacentModelUnit:getUnitType(), isModelUnitDiving(adjacentModelUnit), adjacentModelUnit:getPlayerIndex(), playerIndexActing))) then
                        destroyActorUnitOnMap(modelWarOnline, adjacentGridIndex, true)
                    end
                end
            end
        end

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeDive(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()
        :setDiving(true)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, false, function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            local endingGridIndex     = pathNodes[#pathNodes]
            local playerIndexLoggedIn = getPlayerIndexLoggedIn(modelWarOnline)
            local unitType            = focusModelUnit:getUnitType()
            local playerIndexActing   = focusModelUnit:getPlayerIndex()
            focusModelUnit:setViewVisible(isUnitVisible(modelWarOnline, endingGridIndex, unitType, true, playerIndexActing, playerIndexLoggedIn))

            if (isUnitVisible(modelWarOnline, endingGridIndex, unitType, false, playerIndexActing, playerIndexLoggedIn)) then
                getModelGridEffect(modelWarOnline):showAnimationDive(endingGridIndex)
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeDropModelUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes        = action.path.pathNodes
    local modelUnitMap     = getModelUnitMap(modelWarOnline)
    local endingGridIndex  = pathNodes[#pathNodes]
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()

    local playerIndex        = focusModelUnit:getPlayerIndex()
    local shouldUpdateFogMap = (IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndex, getPlayerIndexLoggedIn(modelWarOnline)))
    local modelFogMap        = getModelFogMap(modelWarOnline)
    local dropModelUnits     = {}
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

        if (shouldUpdateFogMap) then
            modelFogMap:updateMapForPathsWithModelUnitAndPath(dropModelUnit, {endingGridIndex, gridIndex})
                :updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, dropModelUnit:getVisionForPlayerIndex(playerIndex))
        end
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            if (action.isDropBlocked) then
                getModelGridEffect(modelWarOnline):showAnimationBlock(endingGridIndex)
            end

            local playerIndexLoggedIn = getPlayerIndexLoggedIn(modelWarOnline)
            for _, dropModelUnit in ipairs(dropModelUnits) do
                local isDiving  = isModelUnitDiving(dropModelUnit)
                local gridIndex = dropModelUnit:getGridIndex()
                local isVisible = isUnitVisible(modelWarOnline, gridIndex, dropModelUnit:getUnitType(), isDiving, playerIndex, playerIndexLoggedIn)
                if (not isVisible) then
                    destroyActorUnitOnMap(modelWarOnline, gridIndex, false)
                end

                dropModelUnit:moveViewAlongPath({endingGridIndex, gridIndex}, isDiving, function()
                    dropModelUnit:updateView()
                        :showNormalAnimation()

                    if (not isVisible) then
                        dropModelUnit:removeViewFromParent()
                    end
                end)
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeEndTurn(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end

    if (IS_SERVER) then
        getModelTurnManager(modelWarOnline):endTurnPhaseMain()
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)
        getModelTurnManager(modelWarOnline):endTurnPhaseMain()
        modelWarOnline:setExecutingAction(false)
    end
end

local function executeJoinModelUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local endingGridIndex  = pathNodes[#pathNodes]
    local modelUnitMap     = getModelUnitMap(modelWarOnline)
    local focusModelUnit   = modelUnitMap:getFocusModelUnit(pathNodes[1], launchUnitID)
    local targetModelUnit  = modelUnitMap:getModelUnit(endingGridIndex)
    modelUnitMap:removeActorUnitOnMap(endingGridIndex)
    moveModelUnitWithAction(action, modelWarOnline)
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
            local modelPlayer = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex)
            modelPlayer:setFund(modelPlayer:getFund() + joinIncome)
            dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)
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

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            targetModelUnit:removeViewFromParent()

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeLaunchFlare(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes           = action.path.pathNodes
    local targetGridIndex     = action.targetGridIndex
    local modelUnitMap        = getModelUnitMap(modelWarOnline)
    local focusModelUnit      = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local playerIndexActing   = focusModelUnit:getPlayerIndex()
    local flareAreaRadius     = focusModelUnit:getFlareAreaRadius()
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()
        :setCurrentFlareAmmo(focusModelUnit:getCurrentFlareAmmo() - 1)

    local playerIndexLoggedIn = (not IS_SERVER) and (getPlayerIndexLoggedIn(modelWarOnline)) or (nil)
    if ((IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndexActing, playerIndexLoggedIn))) then
        getModelFogMap(modelWarOnline):updateMapForPathsForPlayerIndexWithFlare(playerIndexActing, targetGridIndex, flareAreaRadius)
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            if (playerIndexActing == playerIndexLoggedIn) then
                local modelGridEffect = getModelGridEffect(modelWarOnline)
                for _, gridIndex in pairs(getGridsWithinDistance(targetGridIndex, 0, flareAreaRadius, modelUnitMap:getMapSize())) do
                    modelGridEffect:showAnimationFlare(gridIndex)
                end
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeLaunchSilo(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarOnline)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    local modelTile      = getModelTileMap(modelWarOnline):getModelTile(pathNodes[#pathNodes])
    if ((not IS_SERVER) and (modelTile:isFogEnabledOnClient())) then
        modelTile:updateAsFogDisabled()
    end
    moveModelUnitWithAction(action, modelWarOnline)
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

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
            modelTile:updateView()
            for _, modelUnit in ipairs(targetModelUnits) do
                modelUnit:updateView()
            end

            local modelGridEffect = getModelGridEffect(modelWarOnline)
            for _, gridIndex in ipairs(targetGridIndexes) do
                modelGridEffect:showAnimationSiloAttack(gridIndex)
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeLoadModelUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes      = action.path.pathNodes
    local modelUnitMap   = getModelUnitMap(modelWarOnline)
    local focusModelUnit = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()

    local loaderModelUnit = modelUnitMap:getModelUnit(pathNodes[#pathNodes])
    if (loaderModelUnit) then
        loaderModelUnit:addLoadUnitId(focusModelUnit:getUnitId())
    else
        assert(not IS_SERVER, "ActionExecutorForWarOnline-executeLoadModelUnit() failed to get the target loader on the server.")
    end

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()
                :setViewVisible(false)
            if (loaderModelUnit) then
                loaderModelUnit:updateView()
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeProduceModelUnitOnTile(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local modelUnitMap     = getModelUnitMap(modelWarOnline)
    local producedUnitID   = modelUnitMap:getAvailableUnitId()
    local playerIndex      = getModelTurnManager(modelWarOnline):getPlayerIndex()

    if (action.tiledID) then
        local gridIndex         = action.gridIndex
        local producedActorUnit = produceActorUnit(modelWarOnline, action.tiledID, producedUnitID, gridIndex)
        modelUnitMap:addActorUnitOnMap(producedActorUnit)

        if ((IS_SERVER) or (getModelPlayerManager(modelWarOnline):isSameTeamIndex(playerIndex, getPlayerIndexLoggedIn(modelWarOnline)))) then
            getModelFogMap(modelWarOnline):updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, producedActorUnit:getModel():getVisionForPlayerIndex(playerIndex))
        end
    end

    modelUnitMap:setAvailableUnitId(producedUnitID + 1)
    updateFundWithCost(modelWarOnline, playerIndex, action.cost)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeProduceModelUnitOnUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local pathNodes    = action.path.pathNodes
    local modelUnitMap = getModelUnitMap(modelWarOnline)
    local producer     = modelUnitMap:getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    producer:setStateActioned()

    local producedUnitID    = modelUnitMap:getAvailableUnitId()
    local producedActorUnit = produceActorUnit(modelWarOnline, producer:getMovableProductionTiledId(), producedUnitID, pathNodes[#pathNodes])
    modelUnitMap:addActorUnitLoaded(producedActorUnit)
        :setAvailableUnitId(producedUnitID + 1)
    producer:addLoadUnitId(producedUnitID)
    if (producer.setCurrentMaterial) then
        producer:setCurrentMaterial(producer:getCurrentMaterial() - 1)
    end
    updateFundWithCost(modelWarOnline, producer:getPlayerIndex(), action.cost)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        producer:moveViewAlongPath(pathNodes, isModelUnitDiving(producer), function()
            producer:updateView()
                :showNormalAnimation()

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeResearchPassiveSkill(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local skillID                 = action.skillID
    local skillLevel              = action.skillLevel
    local playerIndex             = getModelTurnManager(modelWarOnline):getPlayerIndex()
    local modelPlayer             = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex)
    local modelSkillConfiguration = modelPlayer:getModelSkillConfiguration()
    modelPlayer:setEnergy(modelPlayer:getEnergy() - modelWarOnline:getModelSkillDataManager():getSkillPoints(skillID, skillLevel, false))
    modelSkillConfiguration:getModelSkillGroupResearching():pushBackSkill(skillID, skillLevel)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        local modelGridEffect = getModelGridEffect(modelWarOnline)
        local func            = function(modelUnit)
            if (modelUnit:getPlayerIndex() == playerIndex) then
                modelGridEffect:showAnimationSkillActivation(modelUnit:getGridIndex())
                modelUnit:updateView()
            end
        end
        getModelUnitMap(modelWarOnline):forEachModelUnitOnMap(func)
            :forEachModelUnitLoaded(func)

        updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)
        dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeSupplyModelUnit(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()
    local targetModelUnits = getAndSupplyAdjacentModelUnits(modelWarOnline, pathNodes[#pathNodes], focusModelUnit:getPlayerIndex())

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            local modelGridEffect = getModelGridEffect(modelWarOnline)
            for _, targetModelUnit in pairs(targetModelUnits) do
                targetModelUnit:updateView()
                modelGridEffect:showAnimationSupply(targetModelUnit:getGridIndex())
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeSurface(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local launchUnitID     = action.launchUnitID
    local pathNodes        = action.path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()
        :setDiving(false)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, true, function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            local endingGridIndex = pathNodes[#pathNodes]
            local isVisible = isUnitVisible(modelWarOnline, endingGridIndex, focusModelUnit:getUnitType(), false, focusModelUnit:getPlayerIndex(), getPlayerIndexLoggedIn(modelWarOnline))
            focusModelUnit:setViewVisible(isVisible)
            if (isVisible) then
                getModelGridEffect(modelWarOnline):showAnimationSurface(endingGridIndex)
            end

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

local function executeSurrender(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end

    local modelPlayerManager = getModelPlayerManager(modelWarOnline)
    local modelTurnManager   = getModelTurnManager(modelWarOnline)
    local playerIndex        = modelTurnManager:getPlayerIndex()
    local modelPlayer        = modelPlayerManager:getModelPlayer(playerIndex)
    modelWarOnline:setRemainingVotesForDraw(nil)
    Destroyers.destroyPlayerForce(modelWarOnline, playerIndex)

    if (IS_SERVER) then
        if (modelPlayerManager:getAliveTeamsCount() <= 1) then
            modelWarOnline:setEnded(true)
        else
            modelTurnManager:endTurnPhaseMain()
        end

        modelWarOnline:setExecutingAction(false)
        PlayerProfileManager.updateProfilesWithModelWarOnline(modelWarOnline)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        local isLoggedInPlayerLost = modelPlayer:getAccount() == getLoggedInAccountAndPassword(modelWarOnline)
        if ((modelPlayerManager:getAliveTeamsCount(playerIndex) <= 1) or (isLoggedInPlayerLost)) then
            modelWarOnline:setEnded(true)
        end

        updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)
        getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(74, "Surrender", modelPlayer:getNickname()))

        if (not modelWarOnline:isEnded()) then
            modelTurnManager:endTurnPhaseMain()
        elseif (isLoggedInPlayerLost) then
            modelWarOnline:showEffectSurrender(callbackOnWarEndedForClient)
        else
            modelWarOnline:showEffectWin(callbackOnWarEndedForClient)
        end

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeUpdateReserveSkills(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end

    local playerIndex = getModelTurnManager(modelWarOnline):getPlayerIndex()
    local modelPlayer = getModelPlayerManager(modelWarOnline):getModelPlayer(playerIndex)
    modelPlayer:getModelSkillConfiguration():getModelSkillGroupReserve():ctor(action.reserveSkills)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        getModelMessageIndicator(modelWarOnline):showMessage(
            string.format("[%s] %s!", modelPlayer:getNickname(), getLocalizedText(22, "HasUpdatedReserveSkills"))
        )
        dispatchEvtModelPlayerUpdated(modelWarOnline, playerIndex)

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeVoteForDraw(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end

    local doesAgree          = action.doesAgree
    local modelPlayerManager = getModelPlayerManager(modelWarOnline)
    local modelPlayer        = modelPlayerManager:getModelPlayer(getModelTurnManager(modelWarOnline):getPlayerIndex())
    if (not doesAgree) then
        modelWarOnline:setRemainingVotesForDraw(nil)
    else
        local remainingVotes = (modelWarOnline:getRemainingVotesForDraw() or modelPlayerManager:getAlivePlayersCount()) - 1
        modelWarOnline:setRemainingVotesForDraw(remainingVotes)
        if (remainingVotes == 0) then
            modelWarOnline:setEnded(true)
        end
    end
    modelPlayer:setVotedForDraw(true)

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        if (modelWarOnline:isEnded()) then
            PlayerProfileManager.updateProfilesWithModelWarOnline(modelWarOnline)
        end
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        if (not doesAgree) then
            getModelMessageIndicator(modelWarOnline):showMessage(getLocalizedText(74, "DisagreeDraw", modelPlayer:getNickname()))
        else
            local modelMessageIndicator = getModelMessageIndicator(modelWarOnline)
            modelMessageIndicator:showMessage(getLocalizedText(74, "AgreeDraw", modelPlayer:getNickname()))
            if (modelWarOnline:isEnded()) then
                modelMessageIndicator:showMessage(getLocalizedText(74, "EndWithDraw"))
            end
        end

        if (modelWarOnline:isEnded()) then
            modelWarOnline:showEffectEndWithDraw(callbackOnWarEndedForClient)
        end

        modelWarOnline:setExecutingAction(false)
    end
end

local function executeWait(action, modelWarOnline)
    if (not prepareForExecutingWarAction(action, modelWarOnline)) then
        return
    end
    updateTilesAndUnitsBeforeExecutingAction(action, modelWarOnline)

    local path             = action.path
    local pathNodes        = path.pathNodes
    local focusModelUnit   = getModelUnitMap(modelWarOnline):getFocusModelUnit(pathNodes[1], action.launchUnitID)
    moveModelUnitWithAction(action, modelWarOnline)
    focusModelUnit:setStateActioned()

    if (IS_SERVER) then
        modelWarOnline:setExecutingAction(false)
        OnlineWarManager.updateWithModelWarOnline(modelWarOnline)

    else
        cleanupOnReceivingResponseFromServer(modelWarOnline)

        focusModelUnit:moveViewAlongPath(pathNodes, isModelUnitDiving(focusModelUnit), function()
            focusModelUnit:updateView()
                :showNormalAnimation()

            updateTileAndUnitMapOnVisibilityChanged(modelWarOnline)

            if (path.isBlocked) then
                getModelGridEffect(modelWarOnline):showAnimationBlock(pathNodes[#pathNodes])
            end

            modelWarOnline:setExecutingAction(false)
        end)
    end
end

--------------------------------------------------------------------------------
-- The public function.
--------------------------------------------------------------------------------
function ActionExecutorForWarOnline.execute(action, modelWarOnline)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionExecutorForWarOnline.execute() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionChat)                   then executeChat(                  action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionLogin)                  then executeLogin(                 action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionLogout)                 then executeLogout(                action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionMessage)                then executeMessage(               action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionNetworkHeartbeat)       then executeNetworkHeartbeat(      action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionRegister)               then executeRegister(              action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionReloadSceneWar)         then executeReloadSceneWar(        action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionRunSceneMain)           then executeRunSceneMain(          action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionActivateSkill)          then executeActivateSkill(         action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionAttack)                 then executeAttack(                action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionBeginTurn)              then executeBeginTurn(             action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionBuildModelTile)         then executeBuildModelTile(        action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionCaptureModelTile)       then executeCaptureModelTile(      action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionDestroyOwnedModelUnit)  then executeDestroyOwnedModelUnit( action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionDive)                   then executeDive(                  action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionDropModelUnit)          then executeDropModelUnit(         action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionEndTurn)                then executeEndTurn(               action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionJoinModelUnit)          then executeJoinModelUnit(         action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionLaunchFlare)            then executeLaunchFlare(           action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionLaunchSilo)             then executeLaunchSilo(            action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionLoadModelUnit)          then executeLoadModelUnit(         action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnTile) then executeProduceModelUnitOnTile(action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionProduceModelUnitOnUnit) then executeProduceModelUnitOnUnit(action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionResearchPassiveSkill)   then executeResearchPassiveSkill(  action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionSupplyModelUnit)        then executeSupplyModelUnit(       action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionSurface)                then executeSurface(               action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionSurrender)              then executeSurrender(             action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionUpdateReserveSkills)    then executeUpdateReserveSkills(   action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionVoteForDraw)            then executeVoteForDraw(           action, modelWarOnline)
    elseif (actionCode == ACTION_CODES.ActionWait)                   then executeWait(                  action, modelWarOnline)
    end

    return ActionExecutorForWarOnline
end

return ActionExecutorForWarOnline
