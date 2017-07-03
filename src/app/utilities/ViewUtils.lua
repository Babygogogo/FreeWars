
local ViewUtils = {}

local CAP_INSETS = {
    ["c03_t01_s05_f01.png"] = {x = 9, y = 9, width = 1, height = 1},
}

local DISPLAY_WIDTH, DISPLAY_HEIGHT = display.width, display.height
local VIEW_STATIC_INFO

local assert = assert

function ViewUtils.init()
    VIEW_STATIC_INFO = {}
    local info = VIEW_STATIC_INFO
    local width, height, x, y

    width  = DISPLAY_WIDTH
    height = 20
    x      = 0
    y      = DISPLAY_HEIGHT - height
    info.ViewMoneyEnergyInfo = {width = width, height = height, x = x, y = y}

    width  = 70
    height = 70
    x      = DISPLAY_WIDTH - width
    y      = 0
    info.ViewLowerRightButton = {width = width, height = height, x = x, y = y}

    width  = info.ViewLowerRightButton.width
    height = DISPLAY_HEIGHT - info.ViewMoneyEnergyInfo.height - info.ViewLowerRightButton.height - 10
    x      = DISPLAY_WIDTH - width
    y      = info.ViewLowerRightButton.y + info.ViewLowerRightButton.height + 5
    info.ViewWarCommandBar = {width = width, height = height, x = x, y = y}
end

function ViewUtils.getCapInsets(spriteFrameName)
    local capInsets = CAP_INSETS[spriteFrameName]
    assert(capInsets, "ViewUtils.getCapInsets() failed to find the cap insets for image: " .. (spriteFrameName or ""))
    return capInsets
end

function ViewUtils.getViewStaticInfo(viewName)
    local info = VIEW_STATIC_INFO[viewName]
    assert(info, "ViewUtils.getViewStaticInfo() failed to find the info for view: " .. (viewName or ""))
    return info
end

function ViewUtils.getViewWidth(viewName)
    return ViewUtils.getViewStaticInfo(viewName).width
end

function ViewUtils.getViewHeight(viewName)
    return ViewUtils.getViewStaticInfo(viewName).height
end

function ViewUtils.getViewPositionX(viewName)
    return ViewUtils.getViewStaticInfo(viewName).x
end

function ViewUtils.getViewPositionY(viewName)
    return ViewUtils.getViewStaticInfo(viewName).y
end

return ViewUtils
