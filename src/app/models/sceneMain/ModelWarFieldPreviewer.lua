
local ModelWarFieldPreviewer = class("ModelWarFieldPreviewer")

local AnimationLoader       = requireFW("src.app.utilities.AnimationLoader")
local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions    = requireFW("src.app.utilities.GridIndexFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local WarFieldManager       = requireFW("src.app.utilities.WarFieldManager")

local cc               = cc
local getLocalizedText = LocalizationFunctions.getLocalizedText

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function createTileSpriteWithTiledId(tiledID, x, y)
    local sprite = cc.Sprite:create()
    sprite:ignoreAnchorPointForPosition(true)
        :setPosition(GridIndexFunctions.toPositionWithXY(x, y))
        :playAnimationForever(AnimationLoader.getTileAnimationWithTiledId(tiledID))

    return sprite
end

local function createViewTiles(warFieldFileName)
    local warFieldData    = WarFieldManager.getWarFieldData(warFieldFileName)
    local baseLayerData   = warFieldData.layers[1].data
    local objectLayerData = warFieldData.layers[2].data
    local width, height   = warFieldData.width, warFieldData.height

    local viewTiles = cc.Node:create()
    for y = height, 1, -1 do
        for x = width, 1, -1 do
            local idIndex = x + (height - y) * width
            viewTiles:addChild(createTileSpriteWithTiledId(baseLayerData[idIndex], x, y))

            local objectID = objectLayerData[idIndex]
            if (objectID > 0) then
                viewTiles:addChild(createTileSpriteWithTiledId(objectID, x, y))
            end
        end
    end

    return viewTiles
end

local function createViewUnits(warFieldFileName)
    local warFieldData  = WarFieldManager.getWarFieldData(warFieldFileName)
    local unitLayerData = warFieldData.layers[3].data
    local width, height = warFieldData.width, warFieldData.height

    local viewUnits = cc.Node:create()
    for y = height, 1, -1 do
        for x = width, 1, -1 do
            local tiledID = unitLayerData[x + (height - y) * width]
            if (tiledID > 0) then
                local viewUnit    = cc.Sprite:create()
                local unitType    = GameConstantFunctions.getUnitTypeWithTiledId(tiledID)
                local playerIndex = GameConstantFunctions.getPlayerIndexWithTiledId(tiledID)
                viewUnit:ignoreAnchorPointForPosition(true)
                    :setPosition(GridIndexFunctions.toPositionWithXY(x, y))
                    :playAnimationForever(AnimationLoader.getUnitAnimation(unitType, playerIndex, "normal"))

                viewUnits:addChild(viewUnit)
            end
        end
    end

    return viewUnits
end

--------------------------------------------------------------------------------
-- The constructor.
--------------------------------------------------------------------------------
function ModelWarFieldPreviewer:ctor()
    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarFieldPreviewer:setWarField(warFieldFileName)
    if (self.m_WarFieldFileName ~= warFieldFileName) then
        self.m_WarFieldFileName = warFieldFileName

        local isRandom = WarFieldManager.isRandomWarField(warFieldFileName)
        if (not isRandom) then
            self.m_View:setViewTilesAndUnits(
                createViewTiles(warFieldFileName),
                createViewUnits(warFieldFileName),
                WarFieldManager.getMapSize(warFieldFileName)
            )
        end

        self.m_View:setIsRandomWarField(isRandom)
            :setPlayersCount(WarFieldManager.getPlayersCount(      warFieldFileName))
            :setRightLabelText(getLocalizedText(48, "Author") .. WarFieldManager.getWarFieldAuthorName(warFieldFileName))
    end

    return self
end

function ModelWarFieldPreviewer:setLeftLabelText(text)
    self.m_View:setLeftLabelText(text)

    return self
end

function ModelWarFieldPreviewer:setEnabled(enabled)
    self.m_View:setEnabled(enabled)

    return self
end

return ModelWarFieldPreviewer
