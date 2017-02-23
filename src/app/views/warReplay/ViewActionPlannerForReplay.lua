
local ViewActionPlannerForReplay = class("ViewActionPlannerForReplay", cc.Node)

local GridIndexFunctions = requireFW("src.app.utilities.GridIndexFunctions")

local PREVIEW_ATTACKABLE_AREA_Z_ORDER  = 0
local PREVIEW_REACHABLE_AREA_Z_ORDER   = 0

local ATTACKABLE_GRIDS_OPACITY = 140
local REACHABLE_GRIDS_OPACITY  = 150

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function createViewSingleReachableGridWithXY(x, y)
    local view = cc.Sprite:create()
    view:ignoreAnchorPointForPosition(true)
        :setPosition(GridIndexFunctions.toPositionWithXY(x, y))
        :playAnimationForever(display.getAnimationCache("ReachableGrid"))

    return view
end

local function createViewSingleAttackableGridWithXY(x, y)
    local view = cc.Sprite:create()
    view:ignoreAnchorPointForPosition(true)
        :setPosition(GridIndexFunctions.toPositionWithXY(x, y))
        :playAnimationForever(display.getAnimationCache("AttackableGrid"))

    return view
end

local function createViewAreaAndGrids(mapSize, gridCreator, opacity)
    local area = cc.Node:create()
    area:setOpacity(opacity)
        :setCascadeOpacityEnabled(true)

    local grids = {}
    local width, height = mapSize.width, mapSize.height
    for x = 1, width do
        grids[x] = {}
        for y = 1, height do
            local grid = gridCreator(x, y)
            grid:setVisible(false)

            area:addChild(grid)
            grids[x][y] = grid
        end
    end

    return area, grids
end

local function setGridsVisibleWithArea(grids, area)
    for x = 1, #grids do
        for y = 1, #grids[x] do
            grids[x][y]:setVisible((area[x]) and (area[x][y] ~= nil))
        end
    end
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initViewPreviewAttackableArea(self)
    self.m_ViewPreviewAttackableArea, self.m_ViewPreviewAttackableGrids = createViewAreaAndGrids(
        self.m_MapSize,
        createViewSingleAttackableGridWithXY,
        ATTACKABLE_GRIDS_OPACITY
    )
    self:addChild(self.m_ViewPreviewAttackableArea, PREVIEW_ATTACKABLE_AREA_Z_ORDER)
end

local function initViewPreviewReachableArea(self)
    self.m_ViewPreviewReachableArea, self.m_ViewPreviewReachableGrids = createViewAreaAndGrids(
        self.m_MapSize,
        createViewSingleReachableGridWithXY,
        REACHABLE_GRIDS_OPACITY
    )
    self:addChild(self.m_ViewPreviewReachableArea, PREVIEW_REACHABLE_AREA_Z_ORDER)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewActionPlannerForReplay:ctor(param)
    return self
end

function ViewActionPlannerForReplay:setMapSize(size)
    if (not self.m_MapSize) then
        self.m_MapSize = size
        initViewPreviewAttackableArea(self)
        initViewPreviewReachableArea( self)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewActionPlannerForReplay:setPreviewAttackableArea(area)
    setGridsVisibleWithArea(self.m_ViewPreviewAttackableGrids, area)

    return self
end

function ViewActionPlannerForReplay:setPreviewAttackableAreaVisible(visible)
    self.m_ViewPreviewAttackableArea:setVisible(visible)

    return self
end

function ViewActionPlannerForReplay:setPreviewReachableArea(area)
    setGridsVisibleWithArea(self.m_ViewPreviewReachableGrids, area)

    return self
end

function ViewActionPlannerForReplay:setPreviewReachableAreaVisible(visible)
    self.m_ViewPreviewReachableArea:setVisible(visible)

    return self
end

return ViewActionPlannerForReplay
