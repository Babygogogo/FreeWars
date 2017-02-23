
local ModelFogMapForReplay = requireFW("src.global.functions.class")("ModelFogMapForReplay")

local GridIndexFunctions     = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SkillModifierFunctions = requireFW("src.app.utilities.SkillModifierFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")

local canRevealHidingPlacesWithUnits = SkillModifierFunctions.canRevealHidingPlacesWithUnits
local getGridsWithinDistance         = GridIndexFunctions.getGridsWithinDistance
local getModelPlayerManager          = SingletonGetters.getModelPlayerManager
local getModelTileMap                = SingletonGetters.getModelTileMap
local getModelUnitMap                = SingletonGetters.getModelUnitMap

local FORCING_FOG_CODE = {
    None  = 0,
    Fog   = 1,
    Clear = 2,
}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getVisionForModelTileOrUnit(modelTileOrUnit, playerIndex, visionModifier)
    if ((modelTileOrUnit) and (modelTileOrUnit.getVisionForPlayerIndex)) then
        local vision = modelTileOrUnit:getVisionForPlayerIndex(playerIndex)
        if (vision) then
            return vision + visionModifier
        end
    end
    return nil
end

local function fillArray(array, size, value)
    for i = 1, size do
        array[i] = value
    end

    return array
end

local function fillSingleMapWithValue(map, mapSize, value)
    local width, height = mapSize.width, mapSize.height
    for x = 1, width do
        fillArray(map[x], height, value)
    end

    return map
end

local function createSingleMap(mapSize, defaultValue)
    local map           = {}
    local width, height = mapSize.width, mapSize.height
    for x = 1, width do
        map[x] = fillArray({}, height, defaultValue)
    end

    return map
end

local function createSerializableDataForSingleMapForPaths(map, mapSize, playerIndex)
    local width, height = mapSize.width, mapSize.height
    local array         = {}
    for x = 1, width do
        local column = map[x]
        local offset = (x - 1) * height
        for y = 1, height do
            array[offset + y] = column[y]
        end
    end

    return {
        playerIndex           = playerIndex,
        encodedFogMapForPaths = table.concat(array),
    }
end

local function fillMapForPathsWithData(map, mapSize, data)
    local width, height = mapSize.width, mapSize.height
    local byteFor0      = string.byte("0")
    local bytesForData  = {string.byte(data, 1, -1)}
    for x = 1, width do
        local column = map[x]
        local offset = (x - 1) * height
        for y = 1, height do
            column[y] = bytesForData[offset + y] - byteFor0
        end
    end

    return map
end

local function updateMapForPaths(map, mapSize, origin, vision, canRevealHidingPlaces)
    if (vision) then
        if (canRevealHidingPlaces) then
            for _, gridIndex in pairs(getGridsWithinDistance(origin, 0, vision, mapSize)) do
                map[gridIndex.x][gridIndex.y] = 2
            end
        else
            for _, gridIndex in pairs(getGridsWithinDistance(origin, 0, 1, mapSize)) do
                map[gridIndex.x][gridIndex.y] = 2
            end
            for _, gridIndex in pairs(getGridsWithinDistance(origin, 2, vision, mapSize)) do
                map[gridIndex.x][gridIndex.y] = math.max(1, map[gridIndex.x][gridIndex.y])
            end
        end
    end
end

local function updateMapForTilesOrUnits(map, mapSize, origin, vision, modifier)
    assert((modifier == 1) or (modifier == -1), "ModelFogMapForReplay-updateMapForTilesOrUnits() invalid modifier: " .. (modifier or ""))
    if (vision) then
        for _, gridIndex in pairs(getGridsWithinDistance(origin, 0, vision, mapSize)) do
            map[gridIndex.x][gridIndex.y] = map[gridIndex.x][gridIndex.y] + modifier
        end
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelFogMapForReplay:ctor(param, warFieldFileName)
    param = param or {}
    local mapSize                           = WarFieldManager.getMapSize(warFieldFileName)
    self.m_MapSize                          = mapSize
    self.m_ForcingFogCode                   = param.forcingFogCode or FORCING_FOG_CODE.None
    self.m_ExpiringPlayerIndexForForcingFog = param.expiringPlayerIndexForForcingFog
    self.m_ExpiringTurnIndexForForcingFog   = param.expiringTurnIndexForForcingFog
    self.m_MapsForPaths                     = {}
    self.m_MapsForTiles                     = {}
    self.m_MapsForUnits                     = {}

    local mapsForPaths = param.mapsForPaths
    for playerIndex = 1, WarFieldManager.getPlayersCount(warFieldFileName) do
        self.m_MapsForPaths[playerIndex] = createSingleMap(mapSize, 0)
        self.m_MapsForTiles[playerIndex] = createSingleMap(mapSize, 0)
        self.m_MapsForUnits[playerIndex] = createSingleMap(mapSize, 0)
        self:resetMapForPathsForPlayerIndex(playerIndex, (mapsForPaths) and (mapsForPaths[playerIndex].encodedFogMapForPaths) or (nil))
    end

    return self
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelFogMapForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay      = modelWarReplay
    self.m_IsFogOfWarByDefault = modelWarReplay:isFogOfWarByDefault()

    for playerIndex = 1, getModelPlayerManager(modelWarReplay):getPlayersCount() do
        self:resetMapForTilesForPlayerIndex(playerIndex)
            :resetMapForUnitsForPlayerIndex(playerIndex)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelFogMapForReplay:getMapSize()
    return self.m_MapSize
end

function ModelFogMapForReplay:isFogOfWarCurrently()
    return (self:isEnablingFogByForce())
        or ((self.m_IsFogOfWarByDefault) and (not self:isDisablingFogByForce()))
end

function ModelFogMapForReplay:isEnablingFogByForce()
    return self.m_ForcingFogCode == "Enabled"
end

function ModelFogMapForReplay:isDisablingFogByForce()
    return self.m_ForcingFogCode == "Disabled"
end

function ModelFogMapForReplay:resetMapForPathsForPlayerIndex(playerIndex, data)
    local visibilityMap = self.m_MapsForPaths[playerIndex]
    local mapSize       = self:getMapSize()
    if (data) then
        fillMapForPathsWithData(visibilityMap, mapSize, data)
    else
        fillSingleMapWithValue(visibilityMap, mapSize, 0)
    end

    return self
end

function ModelFogMapForReplay:updateMapForPathsWithModelUnitAndPath(modelUnit, path)
    local playerIndex = modelUnit:getPlayerIndex()
    local canRevealHidingPlaces = false -- canRevealHidingPlacesWithUnits(getModelPlayerManager(self.m_ModelWarReplay):getModelPlayer(playerIndex):getModelSkillConfiguration())
    local visibilityMap         = self.m_MapsForPaths[playerIndex]
    local mapSize               = self:getMapSize()
    for _, pathNode in ipairs(path) do
        updateMapForPaths(visibilityMap, mapSize, pathNode, modelUnit:getVisionForPlayerIndex(playerIndex, pathNode), canRevealHidingPlaces)
    end

    return self
end

function ModelFogMapForReplay:updateMapForPathsForPlayerIndexWithFlare(playerIndex, origin, radius)
    local visibilityMap = self.m_MapsForPaths[playerIndex]
    for _, gridIndex in pairs(getGridsWithinDistance(origin, 0, radius, self:getMapSize())) do
        visibilityMap[gridIndex.x][gridIndex.y] = 2
    end

    return self
end

function ModelFogMapForReplay:resetMapForTilesForPlayerIndex(playerIndex, visionModifier)
    local visibilityMap = self.m_MapsForTiles[playerIndex]
    local mapSize       = self:getMapSize()
    visionModifier      = visionModifier or 0
    fillSingleMapWithValue(visibilityMap, mapSize, 0)
    getModelTileMap(self.m_ModelWarReplay):forEachModelTile(function(modelTile)
        updateMapForTilesOrUnits(visibilityMap, mapSize, modelTile:getGridIndex(), getVisionForModelTileOrUnit(modelTile, playerIndex, visionModifier), 1)
    end)

    return self
end

function ModelFogMapForReplay:updateMapForTilesForPlayerIndexOnGettingOwnership(playerIndex, gridIndex, vision)
    updateMapForTilesOrUnits(self.m_MapsForTiles[playerIndex], self:getMapSize(), gridIndex, vision, 1)

    return self
end

function ModelFogMapForReplay:updateMapForTilesForPlayerIndexOnLosingOwnership(playerIndex, gridIndex, vision)
    updateMapForTilesOrUnits(self.m_MapsForTiles[playerIndex], self:getMapSize(), gridIndex, vision, -1)

    return self
end

function ModelFogMapForReplay:resetMapForUnitsForPlayerIndex(playerIndex, visionModifier)
    local visibilityMap = self.m_MapsForUnits[playerIndex]
    local mapSize       = self:getMapSize()
    visionModifier      = visionModifier or 0
    fillSingleMapWithValue(visibilityMap, mapSize, 0)
    getModelUnitMap(self.m_ModelWarReplay):forEachModelUnitOnMap(function(modelUnit)
        updateMapForTilesOrUnits(visibilityMap, mapSize, modelUnit:getGridIndex(), getVisionForModelTileOrUnit(modelUnit, playerIndex, visionModifier), 1)
    end)

    return self
end

function ModelFogMapForReplay:updateMapForUnitsForPlayerIndexOnUnitArrive(playerIndex, gridIndex, vision)
    updateMapForTilesOrUnits(self.m_MapsForUnits[playerIndex], self:getMapSize(), gridIndex, vision, 1)

    return self
end

function ModelFogMapForReplay:updateMapForUnitsForPlayerIndexOnUnitLeave(playerIndex, gridIndex, vision)
    updateMapForTilesOrUnits(self.m_MapsForUnits[playerIndex], self:getMapSize(), gridIndex, vision, -1)

    return self
end

function ModelFogMapForReplay:getVisibilityOnGridForPlayerIndex(gridIndex, playerIndex)
    -- This function returns 3 numbers, indicating the visibility calculated with the move paths/tiles/units of the playerIndex.
    -- Each visibility can be 0 or 1:
    -- 0: The grid is out of vision completely.
    -- 1: The grid is in vision, but it's not sure that it is visible or not.
    -- The visibility of paths can also be 2:
    -- 2: The grid is in vision and is visible to the playerIndex.

    -- The skills that enable the tiles/units to see through the hiding places are ignored for the maps for tiles/units, while they are considered for the maps for move paths.
    -- To check if a tile/unit is visible to a player, use functions in VisibilityFunctions.

    if (not self:isFogOfWarCurrently()) then
        return 2, 1, 1
    else
        local x, y = gridIndex.x, gridIndex.y
        return self.m_MapsForPaths[playerIndex][x][y],
            (self.m_MapsForTiles[playerIndex][x][y] > 0) and (1) or (0),
            (self.m_MapsForUnits[playerIndex][x][y] > 0) and (1) or (0)
    end
end

return ModelFogMapForReplay
