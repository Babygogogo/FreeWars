
local ViewWarCommandBar = class("ViewWarCommandBar", cc.Node)

local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local ViewUtils             = requireFW("src.app.utilities.ViewUtils")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")

local getCapInsets           = ViewUtils.getCapInsets
local getLocalizedText       = LocalizationFunctions.getLocalizedText
local getModelFogMap         = SingletonGetters.getModelFogMap
local getPlayerIndexLoggedIn = SingletonGetters.getPlayerIndexLoggedIn

local LABEL_Z_ORDER      = 1
local BACKGROUND_Z_ORDER = 0

local FONT_SIZE  = 14
local FONT_NAME  = "res/fonts/msyhbd.ttc"
local FONT_COLOR = {r = 255, g = 255, b = 255}

local VIEW_STATIC_INFO     = ViewUtils.getViewStaticInfo("ViewWarCommandBar")
local BACKGROUND_WIDTH     = VIEW_STATIC_INFO.width
local BACKGROUND_HEIGHT    = VIEW_STATIC_INFO.height
local BACKGROUND_POS_X     = VIEW_STATIC_INFO.x
local BACKGROUND_POS_Y     = VIEW_STATIC_INFO.y
local BACKGROUND_NAME      = "c03_t01_s05_f01.png"

local LIST_VIEW_WIDTH        = BACKGROUND_WIDTH
local LIST_VIEW_HEIGHT       = BACKGROUND_HEIGHT - 20
local LIST_VIEW_POS_X        = BACKGROUND_POS_X
local LIST_VIEW_POS_Y        = BACKGROUND_POS_Y + 10
local LIST_VIEW_ITEMS_MARGIN = 25

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function createItem(info)
    local button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s05_f01.png", ccui.TextureResType.plistType)
        :ignoreAnchorPointForPosition(true)
        :setPosition(BACKGROUND_POS_X + 10, BACKGROUND_POS_Y + BACKGROUND_HEIGHT - 60)

        :setZoomScale(-0.05)

        :addTouchEventListener(function(sender, eventType)
            if ((eventType == ccui.TouchEventType.ended) and (self.m_Model)) then
                self.m_Model:onPlayerTouch()
            end
        end)

    self.m_Button = button
    self:addChild(button)
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initBackground(self)
    local background = cc.Scale9Sprite:createWithSpriteFrameName(BACKGROUND_NAME, getCapInsets(BACKGROUND_NAME))
    background:ignoreAnchorPointForPosition(true)
        :setPosition(BACKGROUND_POS_X, BACKGROUND_POS_Y)
        :setContentSize(BACKGROUND_WIDTH, BACKGROUND_HEIGHT)

    self.m_Background = background
    self:addChild(background, BACKGROUND_Z_ORDER)
end

local function initListView(self)
    local listView = ccui.ListView:create()
    listView:ignoreAnchorPointForPosition(true)
        :setPosition(LIST_VIEW_POS_X, LIST_VIEW_POS_Y)
        :setContentSize(LIST_VIEW_WIDTH, LIST_VIEW_HEIGHT)

        :setItemsMargin(LIST_VIEW_ITEMS_MARGIN)
        :setGravity(ccui.ListViewGravity.centerHorizontal)

    self.m_ListView = listView
    self:addChild(listView)

    local button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s05_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s06_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s07_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s08_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s09_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s10_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)
    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s10_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)
        button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s10_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)

    button = ccui.Button:create()
    button:loadTextureNormal("c03_t02_s11_f01.png", ccui.TextureResType.plistType)
        :setZoomScale(-0.05)
    listView:pushBackCustomItem(button)
end

local function initCorner(self)
    local background = cc.Scale9Sprite:createWithSpriteFrameName(BACKGROUND_NAME, getCapInsets(BACKGROUND_NAME))
    background:ignoreAnchorPointForPosition(true)
        :setPosition(display.width - 70, 0)
        :setContentSize(70, 70)

    local sprite = cc.Sprite:createWithSpriteFrameName("c03_t02_s07_f01.png")
    sprite:setPosition(10, 10)
        :ignoreAnchorPointForPosition(true)
    background:addChild(sprite)
    self:addChild(background)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewWarCommandBar:ctor(param)
    initBackground(self)
    initListView(  self)
    initCorner(    self)

    self:ignoreAnchorPointForPosition(true)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewWarCommandBar:showItems(itemsInfo)
    local listView = self.m_ListView
    listView:removeAllItems()

    for _, info in ipairs(itemsInfo) do
        listView:pushBackCustomItem(createItem(info))
    end

    return self
end

return ViewWarCommandBar
