
local Destroyers = {}

local IS_SERVER           = requireFW("src.app.utilities.GameConstantFunctions").isServer()
local SingletonGetters    = requireFW("src.app.utilities.SingletonGetters")
local WebSocketManager    = (not IS_SERVER) and (requireFW("src.app.utilities.WebSocketManager")) or (nil)

local getModelFogMap           = SingletonGetters.getModelFogMap
local getModelGridEffect       = SingletonGetters.getModelGridEffect
local getModelPlayerManager    = SingletonGetters.getModelPlayerManager
local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getPlayerIndexLoggedIn   = SingletonGetters.getPlayerIndexLoggedIn
local isWarReplay              = SingletonGetters.isWarReplay

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function resetModelTile(modelWar, gridIndex)
    local modelTile = getModelTileMap(modelWar):getModelTile(gridIndex)
    if (modelTile.setCurrentBuildPoint) then
        modelTile:setCurrentBuildPoint(modelTile:getMaxBuildPoint())
    end
    if (modelTile.setCurrentCapturePoint) then
        modelTile:setCurrentCapturePoint(modelTile:getMaxCapturePoint())
    end
end

local function destroySingleActorUnitLoaded(modelUnitMap, modelUnitLoaded, shouldRemoveView)
    modelUnitMap:removeActorUnitLoaded(modelUnitLoaded:getUnitId())
    if (shouldRemoveView) then
        modelUnitLoaded:removeViewFromParent()
    end

    return modelUnitLoaded
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function Destroyers.destroyActorUnitLoaded(modelWar, unitID, shouldRemoveView)
    local modelUnitMap    = getModelUnitMap(modelWar)
    local modelUnitLoaded = modelUnitMap:getLoadedModelUnitWithUnitId(unitID)
    local destroyedUnits  = {}
    shouldRemoveView      = (not IS_SERVER) and (shouldRemoveView)

    destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, modelUnitLoaded, shouldRemoveView)
    for _, subModelUnitLoaded in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(modelUnitLoaded, true) or {}) do
        destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, subModelUnitLoaded, shouldRemoveView)
    end

    return destroyedUnits
end

function Destroyers.destroyActorUnitOnMap(modelWar, gridIndex, shouldRemoveView, shouldRetainVisibility)
    resetModelTile(modelWar, gridIndex)

    local modelUnitMap   = getModelUnitMap(modelWar)
    local modelUnit      = modelUnitMap:getModelUnit(gridIndex)
    local destroyedUnits = {modelUnit}
    shouldRemoveView     = (not IS_SERVER) and (shouldRemoveView)

    modelUnitMap:removeActorUnitOnMap(gridIndex)
    if (shouldRemoveView) then
        modelUnit:removeViewFromParent()
    end
    for _, modelUnitLoaded in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(modelUnit, true) or {}) do
        destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, modelUnitLoaded, true)
    end

    if (not shouldRetainVisibility) then
        local playerIndex = modelUnit:getPlayerIndex()
        if ((IS_SERVER) or (isWarReplay(modelWar)) or (playerIndex == getPlayerIndexLoggedIn(modelWar))) then
            getModelFogMap(modelWar):updateMapForUnitsForPlayerIndexOnUnitLeave(playerIndex, gridIndex, modelUnit:getVisionForPlayerIndex(playerIndex))
        end
    end

    return destroyedUnits
end

function Destroyers.destroyPlayerForce(modelWar, playerIndex)
    local modelGridEffect
    if ((not IS_SERVER)                                                           and
        ((not isWarReplay(modelWar)) or (not modelWar:isFastExecutingActions()))) then
        modelGridEffect = SingletonGetters.getModelGridEffect(modelWar)
    end

    getModelUnitMap(modelWar):forEachModelUnitOnMap(function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            local gridIndex = modelUnit:getGridIndex()
            Destroyers.destroyActorUnitOnMap(modelWar, gridIndex, true, true)

            if (modelGridEffect) then
                modelGridEffect:showAnimationExplosion(gridIndex)
            end
        end
    end)

    getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        if (modelTile:getPlayerIndex() == playerIndex) then
            modelTile:updateWithPlayerIndex(0)
                :updateView()
        end
    end)

    if ((IS_SERVER) or (isWarReplay(modelWar)) or (playerIndex == getPlayerIndexLoggedIn(modelWar))) then
        getModelFogMap(modelWar):resetMapForPathsForPlayerIndex(playerIndex)
            :resetMapForTilesForPlayerIndex(playerIndex)
            :resetMapForUnitsForPlayerIndex(playerIndex)
    end

    getModelPlayerManager(modelWar):getModelPlayer(playerIndex):setAlive(false)
end

return Destroyers
