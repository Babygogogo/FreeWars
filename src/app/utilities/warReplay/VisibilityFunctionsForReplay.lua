
local VisibilityFunctionsForReplay = {}

local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")

local canRevealHidingPlacesWithTilesForSkillGroup = SkillModifierFunctions.canRevealHidingPlacesWithTilesForSkillGroup
local canRevealHidingPlacesWithTiles              = SkillModifierFunctions.canRevealHidingPlacesWithTiles
local canRevealHidingPlacesWithUnitsForSkillGroup = SkillModifierFunctions.canRevealHidingPlacesWithUnitsForSkillGroup
local canRevealHidingPlacesWithUnits              = SkillModifierFunctions.canRevealHidingPlacesWithUnits
local getAdjacentGrids                            = GridIndexFunctions.getAdjacentGrids
local getModelFogMap                              = SingletonGetters.getModelFogMap
local getModelPlayerManager                       = SingletonGetters.getModelPlayerManager
local getModelTileMap                             = SingletonGetters.getModelTileMap
local getModelUnitMap                             = SingletonGetters.getModelUnitMap

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function hasUnitWithPlayerIndexOnAdjacentGrid(modelWarReplay, gridIndex, playerIndex)
    local modelUnitMap = getModelUnitMap(modelWarReplay)
    for _, adjacentGridIndex in ipairs(getAdjacentGrids(gridIndex, modelUnitMap:getMapSize())) do
        local adjacentModelUnit = modelUnitMap:getModelUnit(adjacentGridIndex)
        if ((adjacentModelUnit) and (adjacentModelUnit:getPlayerIndex() == playerIndex)) then
            return true
        end
    end

    return false
end

local function hasUnitWithPlayerIndexOnGrid(modelWarReplay, gridIndex, playerIndex)
    local modelUnit = getModelUnitMap(modelWarReplay):getModelUnit(gridIndex)
    return (modelUnit) and (modelUnit:getPlayerIndex() == playerIndex)
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function VisibilityFunctionsForReplay.isTileVisibleToPlayerIndex(modelWarReplay, gridIndex, targetPlayerIndex, canRevealWithTiles, canRevealWithUnits)
    local modelTile     = getModelTileMap(modelWarReplay):getModelTile(gridIndex)
    if (modelTile:getPlayerIndex() == targetPlayerIndex) then
        return true
    else
        local visibilityForPaths, visibilityForTiles, visibilityForUnits = getModelFogMap(modelWarReplay):getVisibilityOnGridForPlayerIndex(gridIndex, targetPlayerIndex)
        if (visibilityForPaths == 2) then
            return true
        elseif ((visibilityForPaths == 0) and (visibilityForTiles == 0) and (visibilityForUnits == 0)) then
            return false
        elseif (not modelTile.canHideUnitType) then
            return true
        elseif ((hasUnitWithPlayerIndexOnAdjacentGrid(modelWarReplay, gridIndex, targetPlayerIndex))  or
            (    hasUnitWithPlayerIndexOnGrid(        modelWarReplay, gridIndex, targetPlayerIndex))) then
            return true
        else
            local skillConfiguration = getModelPlayerManager(modelWarReplay):getModelPlayer(targetPlayerIndex):getModelSkillConfiguration()
            canRevealWithTiles = false --(not canRevealWithTiles) and (canRevealHidingPlacesWithTiles(skillConfiguration)) or (canRevealWithTiles)
            canRevealWithUnits = false --(not canRevealWithUnits) and (canRevealHidingPlacesWithUnits(skillConfiguration)) or (canRevealWithUnits)
            return ((visibilityForTiles == 1) and (canRevealWithTiles)) or
                (   (visibilityForUnits == 1) and (canRevealWithUnits))
        end
    end
end

return VisibilityFunctionsForReplay
