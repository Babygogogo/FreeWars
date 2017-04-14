
local ModelTileMapForCampaign = requireFW("src.global.functions.class")("ModelTileMapForCampaign")

local GameConstantFunctions  = requireFW("src.app.utilities.GameConstantFunctions")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local TableFunctions         = requireFW("src.app.utilities.TableFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")
local Actor                  = requireFW("src.global.actors.Actor")

local ceil = math.ceil

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getXYWithPositionIndex(positionIndex, height)
    local x = ceil(positionIndex / height)
    return x, positionIndex - (x - 1) * height
end

local function createEmptyMap(width)
    local map = {}
    for x = 1, width do
        map[x] = {}
    end

    return map
end

local function createActorTilesMapWithWarFieldFileName(warFieldFileName)
    local warFieldData     = WarFieldManager.getWarFieldData(warFieldFileName)
    local baseLayer        = warFieldData.layers[1]
    local objectLayerData  = warFieldData.layers[2].data
    local width, height    = baseLayer.width, baseLayer.height
    local baseLayerData    = baseLayer.data
    local map              = createEmptyMap(width)

    for x = 1, width do
        for y = 1, height do
            local idIndex = x + (height - y) * width
            local actorData = {
                positionIndex = (x - 1) * height + y,
                objectID      = objectLayerData[idIndex],
                baseID        = baseLayerData[idIndex],
                GridIndexable = {x = x, y = y},
            }
            map[x][y] = Actor.createWithModelAndViewName("warNative.ModelTileForCampaign", actorData, "common.ViewTile")
        end
    end

    return map, {width = width, height = height}
end

local function updateActorTilesMapWithTilesData(map, height, tiles)
    if (tiles) then
        for positionIndex, singleTileData in pairs(tiles) do
            local x, y = getXYWithPositionIndex(positionIndex, height)
            singleTileData.GridIndexable = (singleTileData.GridIndexable) or ({x = x, y = y})
            map[x][y]:getModel():ctor(singleTileData)
        end
    end
end

local function resetActorTilesMap(map, mapSize, warFieldFileName)
    local width, height    = mapSize.width, mapSize.height
    local warFieldData     = WarFieldManager.getWarFieldData(warFieldFileName)
    local baseLayerData    = warFieldData.layers[1].data
    local objectLayerData  = warFieldData.layers[2].data

    for x = 1, width do
        for y = 1, height do
            local idIndex  = x + (height - y) * width
            local objectID = objectLayerData[idIndex]
            local baseID   = baseLayerData[idIndex]
            local tileData = TableFunctions.clone(GameConstantFunctions.getTemplateModelTileWithObjectAndBaseId(objectID, baseID))
            tileData.positionIndex = (x - 1) * height + y
            tileData.objectID      = objectID
            tileData.baseID        = baseID
            tileData.GridIndexable = {x = x, y = y}

            map[x][y]:getModel():ctor(tileData)
        end
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelTileMapForCampaign:ctor(param, warFieldFileName)
    if (self.m_ActorTilesMap) then
        resetActorTilesMap(self.m_ActorTilesMap, self.m_MapSize, warFieldFileName)
        updateActorTilesMapWithTilesData(self.m_ActorTilesMap, self.m_MapSize.height, param.tiles)
    else
        local map, mapSize = createActorTilesMapWithWarFieldFileName(warFieldFileName)
        updateActorTilesMapWithTilesData(map, mapSize.height, (param) and (param.tiles) or (nil))

        self.m_ActorTilesMap = map
        self.m_MapSize       = mapSize
    end

    return self
end

function ModelTileMapForCampaign:initView()
    local view = self.m_View
    assert(view, "ModelTileMapForCampaign:initView() no view is attached to the owner actor of the model.")
    view:removeAllChildren()

    local mapSize = self:getMapSize()
    for y = mapSize.height, 1, -1 do
        for x = mapSize.width, 1, -1 do
            view:addChild(self.m_ActorTilesMap[x][y]:getView())
        end
    end

    return self
end

--------------------------------------------------------------------------------
-- The function for serialization.
--------------------------------------------------------------------------------
function ModelTileMapForCampaign:toSerializableTable()
    local tiles = {}
    self:forEachModelTile(function(modelTile)
        tiles[modelTile:getPositionIndex()] = modelTile:toSerializableTable()
    end)

    return {tiles = tiles}
end

--------------------------------------------------------------------------------
-- The callback functions on start running/script events.
--------------------------------------------------------------------------------
function ModelTileMapForCampaign:onStartRunning(modelWar)
    self.m_ModelWar = modelWar
    self:forEachModelTile(function(modelTile)
        modelTile:onStartRunning(modelWar)
    end)

    return self
end

function ModelTileMapForCampaign:updateOnModelFogMapStartedRunning()
    local playerIndex = SingletonGetters.getModelPlayerManager(self.m_ModelWar):getPlayerIndexForHuman()
    self:forEachModelTile(function(modelTile)
        modelTile:updateView()
    end)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelTileMapForCampaign:getMapSize()
    return self.m_MapSize
end

function ModelTileMapForCampaign:getModelTile(gridIndex)
    return self.m_ActorTilesMap[gridIndex.x][gridIndex.y]:getModel()
end

function ModelTileMapForCampaign:getModelTileWithPositionIndex(positionIndex)
    local x, y = getXYWithPositionIndex(positionIndex, self:getMapSize().height)
    return self.m_ActorTilesMap[x][y]:getModel()
end

function ModelTileMapForCampaign:forEachModelTile(func)
    local mapSize = self:getMapSize()
    for x = 1, mapSize.width do
        for y = 1, mapSize.height do
            func(self.m_ActorTilesMap[x][y]:getModel(), x, y)
        end
    end

    return self
end

return ModelTileMapForCampaign
