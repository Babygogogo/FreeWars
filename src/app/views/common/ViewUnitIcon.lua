
local ViewUnitIcon = class("ViewUnitIcon", cc.Node)

local AnimationLoader       = requireFW("src.app.utilities.AnimationLoader")
local GameConstantFunctions = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions    = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters      = requireFW("src.app.utilities.SingletonGetters")

local getModelMapCursor        = SingletonGetters.getModelMapCursor
local getModelPlayerManager    = SingletonGetters.getModelPlayerManager
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher

local cc = cc

local GRID_SIZE              = GameConstantFunctions.getGridSize()
local COLOR_IDLE             = {r = 255, g = 255, b = 255}
local COLOR_ACTIONED         = {r = 170, g = 170, b = 170}
local MOVE_DURATION_PER_GRID = 0.15

local STATE_INDICATOR_POSITION_X = 3
local STATE_INDICATOR_POSITION_Y = 0
local HP_INDICATOR_POSITION_X    = GRID_SIZE.width - 24 -- 24 is the width of the indicator
local HP_INDICATOR_POSITION_Y    = 0

local STATE_INDICATOR_DURATION = 0.8

local HP_INDICATOR_Z_ORDER    = 1
local STATE_INDICATOR_Z_ORDER = 1
local UNIT_SPRITE_Z_ORDER     = 0

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getSkillIndicatorFrame(unit)
    local playerIndex = unit:getPlayerIndex()
    if (getModelPlayerManager(unit:getModelWar()):getModelPlayer(playerIndex):isActivatingSkill()) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s07_f0" .. playerIndex .. ".png")
    else
        return nil
    end
end

local function getLevelIndicatorFrame(unit)
    if ((unit.getCurrentPromotion) and (unit:getCurrentPromotion() > 0)) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s05_f0" .. unit:getCurrentPromotion() .. ".png")
    else
        return nil
    end
end

local function getFuelIndicatorFrame(unit)
    if ((unit.isFuelInShort) and (unit:isFuelInShort())) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s02_f01.png")
    else
        return nil
    end
end

local function getAmmoIndicatorFrame(unit)
    if (((unit.isPrimaryWeaponAmmoInShort) and (unit:isPrimaryWeaponAmmoInShort())) or
        ((unit.isFlareAmmoInShort) and (unit:isFlareAmmoInShort())))                then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s02_f02.png")
    else
        return nil
    end
end

local function getDiveIndicatorFrame(unit)
    if ((unit.isDiving) and (unit:isDiving())) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s03_f0" .. unit:getPlayerIndex() .. ".png")
    else
        return nil
    end
end

local function getCaptureIndicatorFrame(unit)
    if ((unit.isCapturingModelTile) and (unit:isCapturingModelTile())) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s04_f0" .. unit:getPlayerIndex() .. ".png")
    else
        return nil
    end
end

local function getBuildIndicatorFrame(unit)
    if ((unit.isBuildingModelTile) and (unit:isBuildingModelTile())) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s04_f0" .. unit:getPlayerIndex() .. ".png")
    else
        return nil
    end
end

local function getLoadIndicatorFrame(unit)
    if ((unit.getCurrentLoadCount) and (unit:getCurrentLoadCount() > 0)) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s06_f0" .. unit:getPlayerIndex() .. ".png")
    else
        return nil
    end
end

local function getMaterialIndicatorFrame(unit)
    if ((unit.isMaterialInShort) and (unit:isMaterialInShort())) then
        return cc.SpriteFrameCache:getInstance():getSpriteFrame("c02_t99_s02_f04.png")
    else
        return nil
    end
end

local function playSpriteAnimation(sprite, tiledID, state)
    if (state == "moving") then
        sprite:setPosition(-18, 0)
    else
        sprite:setPosition(0, 0)
    end

    local unitName       = GameConstantFunctions.getUnitTypeWithTiledId(tiledID)
    local playerIndex    = GameConstantFunctions.getPlayerIndexWithTiledId(tiledID)
    sprite:stopAllActions()
        :playAnimationForever(AnimationLoader.getUnitAnimation(unitName, playerIndex, state))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initUnitSprite(self)
    local sprite = cc.Sprite:create()
    sprite:ignoreAnchorPointForPosition(true)

    self.m_UnitSprite = sprite
    self:addChild(sprite, UNIT_SPRITE_Z_ORDER)
end

local function initHpIndicator(self)
    local indicator = cc.Sprite:createWithSpriteFrameName("c02_t99_s01_f00.png")
    indicator:ignoreAnchorPointForPosition(true)
        :setPosition(HP_INDICATOR_POSITION_X, HP_INDICATOR_POSITION_Y)
        :setVisible(false)

    self.m_HpIndicator = indicator
    self:addChild(indicator, HP_INDICATOR_Z_ORDER)
end

local function initStateIndicator(self)
    local indicator = cc.Sprite:createWithSpriteFrameName("c02_t99_s02_f01.png")
    indicator:ignoreAnchorPointForPosition(true)
        :setPosition(STATE_INDICATOR_POSITION_X, STATE_INDICATOR_POSITION_Y)
        :setVisible(true)

    self.m_StateIndicator = indicator
    self:addChild(indicator, STATE_INDICATOR_Z_ORDER)
end

--------------------------------------------------------------------------------
-- The functions for updating the composition elements.
--------------------------------------------------------------------------------
local function updateUnitSprite(self, tiledID)
    if (self.m_TiledID ~= tiledID) then
        playSpriteAnimation(self.m_UnitSprite, tiledID, "normal")
    end
end

local function updateUnitState(self, isStateIdle)
    if (self.m_IsStateIdle ~= isStateIdle) then
        if (isStateIdle) then
            self:setColor(COLOR_IDLE)
        else
            self:setColor(COLOR_ACTIONED)
        end
    end
end

local function updateHpIndicator(self, modelUnit)
    local hp = modelUnit:getNormalizedCurrentHP()
    if ((hp >= 10) or (hp < 0)) then
        self.m_HpIndicator:setVisible(false)
    else
        self.m_HpIndicator:setVisible(true)
            :setSpriteFrame("c02_t99_s01_f0" .. hp .. ".png")
    end
end

local function updateStateIndicator(self, unit)
    local frames = {}
    frames[#frames + 1] = getSkillIndicatorFrame(   unit)
    frames[#frames + 1] = getLevelIndicatorFrame(   unit)
    frames[#frames + 1] = getFuelIndicatorFrame(    unit)
    frames[#frames + 1] = getAmmoIndicatorFrame(    unit)
    frames[#frames + 1] = getDiveIndicatorFrame(    unit)
    frames[#frames + 1] = getCaptureIndicatorFrame( unit)
    frames[#frames + 1] = getBuildIndicatorFrame(   unit)
    frames[#frames + 1] = getLoadIndicatorFrame(    unit)
    frames[#frames + 1] = getMaterialIndicatorFrame(unit)

    local indicator = self.m_StateIndicator
    indicator:stopAllActions()
    if (#frames == 0) then
        indicator:setVisible(false)
    else
        indicator:setVisible(true)
            :playAnimationForever(display.newAnimation(frames, STATE_INDICATOR_DURATION))
    end
end

local function updateZOrder(self, modelUnit)
    if (modelUnit.getGridIndex) then
        local mapSize = SingletonGetters.getModelTileMap(modelUnit:getModelWar()):getMapSize()
        self:setLocalZOrder(mapSize.height - modelUnit:getGridIndex().y)
    end
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ViewUnitIcon:ctor()
    self:ignoreAnchorPointForPosition(true)
        :setCascadeColorEnabled(true)

    initUnitSprite(    self)
    initHpIndicator(   self)
    initStateIndicator(self)

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ViewUnitIcon:updateWithModelUnit(modelUnit)
    local tiledID     = modelUnit:getTiledId()
    local isStateIdle = modelUnit:isStateIdle()
    updateUnitSprite(    self, tiledID)
    updateUnitState(     self, isStateIdle)
    updateHpIndicator(   self, modelUnit)
    updateStateIndicator(self, modelUnit)
    updateZOrder(        self, modelUnit)

    self.m_TiledID     = tiledID
    self.m_IsStateIdle = isStateIdle

    return self
end

return ViewUnitIcon
