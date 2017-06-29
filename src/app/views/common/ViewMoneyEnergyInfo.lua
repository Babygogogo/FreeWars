
local ViewMoneyEnergyInfo = class("ViewMoneyEnergyInfo", cc.Node)

local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local ResourceManager       = requireFW("src.app.utilities.ResourceManager")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")

local getCapInsets           = ResourceManager.getCapInsets
local getLocalizedText       = LocalizationFunctions.getLocalizedText
local getModelFogMap         = SingletonGetters.getModelFogMap
local getPlayerIndexLoggedIn = SingletonGetters.getPlayerIndexLoggedIn

local LABEL_Z_ORDER      = 1
local BACKGROUND_Z_ORDER = 0

local FONT_SIZE  = 14
local FONT_NAME  = "res/fonts/msyhbd.ttc"
local FONT_COLOR = {r = 255, g = 255, b = 255}

local BACKGROUND_WIDTH     = display.width
local BACKGROUND_HEIGHT    = 20
local BACKGROUND_NAME      = "c03_t01_s05_f01.png"
local BACKGROUND_POS_X     = 0
local BACKGROUND_POS_Y     = display.height - BACKGROUND_HEIGHT

local LABEL_MAX_WIDTH  = BACKGROUND_WIDTH - 10
local LABEL_MAX_HEIGHT = BACKGROUND_HEIGHT - 8
local LABEL_POS_X      = 5
local LABEL_POS_Y      = 2

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

local function initLabel(self)
    local label = cc.Label:createWithTTF("", FONT_NAME, FONT_SIZE)
    label:setAnchorPoint(0, 0)
        :ignoreAnchorPointForPosition(true)
        :setPosition(LABEL_POS_X, LABEL_POS_Y)

        :setHorizontalAlignment(cc.TEXT_ALIGNMENT_LEFT)
        :setVerticalAlignment(cc.VERTICAL_TEXT_ALIGNMENT_BOTTOM)

        :setTextColor(FONT_COLOR)

    self.m_Label = label
    self.m_Background:addChild(label, LABEL_Z_ORDER)
end

local function initSideBar(self)
    local width = 70
    local height = 70
    local background = ccui.Button:create()
    background:loadTextureNormal(BACKGROUND_NAME, ccui.TextureResType.plistType)
        :ignoreAnchorPointForPosition(true)
        :setPosition(display.width - width, display.height - BACKGROUND_HEIGHT - height)

        :setScale9Enabled(true)
        :setCapInsets(getCapInsets(BACKGROUND_NAME))
        :setContentSize(width, height)

        :setZoomScale(-0.05)

        :addTouchEventListener(function(sender, eventType)
            if ((eventType == ccui.TouchEventType.ended) and (self.m_Model)) then
                self.m_Model:onPlayerTouch()
            end
        end)

    local icon = cc.Sprite:createWithSpriteFrameName("c03_t02_s05_f01.png")
    icon:setPosition(width / 2, height / 2)
    background:getRendererNormal():addChild(icon)

    self.m_SideBar = background
    self:addChild(background)
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewMoneyEnergyInfo:ctor(param)
    initBackground(self)
    initLabel(     self)
    initSideBar(   self)

    self:ignoreAnchorPointForPosition(true)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewMoneyEnergyInfo:adjustPositionOnTouch(touch)
    return self
end

function ViewMoneyEnergyInfo:setInfoText(text)
    local label = self.m_Label
    label:setString(text)
        :setScaleX(math.min(1, LABEL_MAX_WIDTH / label:getContentSize().width))

    return self
end

function ViewMoneyEnergyInfo:updateWithPlayerIndex(playerIndex)
    return self
end

return ViewMoneyEnergyInfo
