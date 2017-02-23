
local DestroyersForReplay = {}

local GridIndexFunctions  = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters    = requireFW("src.app.utilities.SingletonGetters")

local getAdjacentGrids         = GridIndexFunctions.getAdjacentGrids
local getModelFogMap           = SingletonGetters.getModelFogMap
local getModelGridEffect       = SingletonGetters.getModelGridEffect
local getModelPlayerManager    = SingletonGetters.getModelPlayerManager
local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function resetModelTile(modelWarReplay, gridIndex)
    local modelTile = getModelTileMap(modelWarReplay):getModelTile(gridIndex)
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
function DestroyersForReplay.destroyActorUnitLoaded(modelWarReplay, unitID, shouldRemoveView)
    local modelUnitMap    = getModelUnitMap(modelWarReplay)
    local modelUnitLoaded = modelUnitMap:getLoadedModelUnitWithUnitId(unitID)
    local destroyedUnits  = {}

    destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, modelUnitLoaded, shouldRemoveView)
    for _, subModelUnitLoaded in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(modelUnitLoaded, true) or {}) do
        destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, subModelUnitLoaded, shouldRemoveView)
    end

    return destroyedUnits
end

function DestroyersForReplay.destroyActorUnitOnMap(modelWarReplay, gridIndex, shouldRemoveView, shouldRetainVisibility)
    resetModelTile(modelWarReplay, gridIndex)

    local modelUnitMap   = getModelUnitMap(modelWarReplay)
    local modelUnit      = modelUnitMap:getModelUnit(gridIndex)
    local destroyedUnits = {modelUnit}

    modelUnitMap:removeActorUnitOnMap(gridIndex)
    if (shouldRemoveView) then
        modelUnit:removeViewFromParent()
    end
    for _, modelUnitLoaded in pairs(modelUnitMap:getLoadedModelUnitsWithLoader(modelUnit, true) or {}) do
        destroyedUnits[#destroyedUnits + 1] = destroySingleActorUnitLoaded(modelUnitMap, modelUnitLoaded, true)
    end

    if (not shouldRetainVisibility) then
        local playerIndex = modelUnit:getPlayerIndex()
        getModelFogMap(modelWarReplay):updateMapForUnitsForPlayerIndexOnUnitLeave(playerIndex, gridIndex, modelUnit:getVisionForPlayerIndex(playerIndex))
    end

    return destroyedUnits
end

function DestroyersForReplay.destroyPlayerForce(modelWarReplay, playerIndex)
    local modelGridEffect = (not modelWarReplay:isFastExecutingActions()) and (getModelGridEffect(modelWarReplay)) or (nil)
    getModelUnitMap(modelWarReplay):forEachModelUnitOnMap(function(modelUnit)
        if (modelUnit:getPlayerIndex() == playerIndex) then
            local gridIndex = modelUnit:getGridIndex()
            DestroyersForReplay.destroyActorUnitOnMap(modelWarReplay, gridIndex, true, true)

            if (modelGridEffect) then
                modelGridEffect:showAnimationExplosion(gridIndex)
            end
        end
    end)

    getModelTileMap(modelWarReplay):forEachModelTile(function(modelTile)
        if (modelTile:getPlayerIndex() == playerIndex) then
            modelTile:updateWithPlayerIndex(0)
                :updateView()
        end
    end)

    getModelFogMap(modelWarReplay):resetMapForPathsForPlayerIndex(playerIndex)
        :resetMapForTilesForPlayerIndex(playerIndex)
        :resetMapForUnitsForPlayerIndex(playerIndex)

    getModelPlayerManager(modelWarReplay):getModelPlayer(playerIndex):setAlive(false)

    return DestroyersForReplay
end

return DestroyersForReplay
