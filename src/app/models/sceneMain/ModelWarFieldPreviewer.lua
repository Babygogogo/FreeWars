
local ModelWarFieldPreviewer = class("ModelWarFieldPreviewer")

local AnimationLoader	   = requireFW("src.app.utilities.AnimationLoader")
local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions	= requireFW("src.app.utilities.GridIndexFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local WarFieldManager	   = requireFW("src.app.utilities.WarFieldManager")

local cc			   = cc
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

local function createViewTiles(warFieldData)
	if not warFieldData then return end
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

local function createViewUnits(warFieldData)
	if not warFieldData then return end
	local unitLayerData = warFieldData.layers[3].data
	local width, height = warFieldData.width, warFieldData.height

	local viewUnits = cc.Node:create()
	for y = height, 1, -1 do
		for x = width, 1, -1 do
			local tiledID = unitLayerData[x + (height - y) * width]
			if (tiledID > 0) then
				local viewUnit	= cc.Sprite:create()
				local unitType	= GameConstantFunctions.getUnitTypeWithTiledId(tiledID)
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
function ModelWarFieldPreviewer:setWarField(warFieldData)
	self.m_View:setViewTilesAndUnits(
		createViewTiles(warFieldData),
		createViewUnits(warFieldData),
		warFieldData and {width = warFieldData.width, height = warFieldData.height}
	)
	self.m_View:setIsRandomWarField(false)
	if warFieldData then
		self.m_View:setPlayersCount(warFieldData.playersCount)
			:setRightLabelText(getLocalizedText(48, "Author") .. warFieldData.authorName)
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
