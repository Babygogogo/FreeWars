
--[[--------------------------------------------------------------------------------
-- ModelWarCommandMenuForOnline是战局中的命令菜单（与单位操作菜单不同），在玩家点击MoneyEnergyInfo时呼出。
--
-- 主要职责和使用场景举例：
--   同上
--
-- 其他：
--   - ModelWarCommandMenuForOnline将包括以下菜单项（可能有遗漏）：
--     - 离开战局（回退到主画面，而不是投降）
--     - 发动co技能
--     - 发动super技能
--     - 游戏设定（声音等）
--     - 投降
--     - 求和
--     - 结束回合
--]]--------------------------------------------------------------------------------

local ModelWarCommandMenuForOnline = class("ModelWarCommandMenuForOnline")

local ActionCodeFunctions       = requireFW("src.app.utilities.ActionCodeFunctions")
local AudioManager              = requireFW("src.app.utilities.AudioManager")
local AuxiliaryFunctions        = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions     = requireFW("src.app.utilities.LocalizationFunctions")
local GameConstantFunctions     = requireFW("src.app.utilities.GameConstantFunctions")
local GridIndexFunctions        = requireFW("src.app.utilities.GridIndexFunctions")
local SingletonGetters          = requireFW("src.app.utilities.SingletonGetters")
local SkillDescriptionFunctions = requireFW("src.app.utilities.SkillDescriptionFunctions")
local WarFieldManager           = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager          = requireFW("src.app.utilities.WebSocketManager")
local Actor                     = requireFW("src.global.actors.Actor")
local ActorManager              = requireFW("src.global.actors.ActorManager")

local getActionId              = SingletonGetters.getActionId
local getLocalizedText         = LocalizationFunctions.getLocalizedText
local getModelConfirmBox       = SingletonGetters.getModelConfirmBox
local getModelFogMap           = SingletonGetters.getModelFogMap
local getModelMessageIndicator = SingletonGetters.getModelMessageIndicator
local getModelPlayerManager    = SingletonGetters.getModelPlayerManager
local getModelTileMap          = SingletonGetters.getModelTileMap
local getModelTurnManager      = SingletonGetters.getModelTurnManager
local getModelUnitMap          = SingletonGetters.getModelUnitMap
local getScriptEventDispatcher = SingletonGetters.getScriptEventDispatcher

local table, string, ipairs, pairs = table, string, ipairs, pairs

local ACTION_CODE_DESTROY_OWNED_UNIT   = ActionCodeFunctions.getActionCode("ActionDestroyOwnedModelUnit")
local ACTION_CODE_END_TURN             = ActionCodeFunctions.getActionCode("ActionEndTurn")
local ACTION_CODE_RELOAD_SCENE_WAR     = ActionCodeFunctions.getActionCode("ActionReloadSceneWar")
local ACTION_CODE_SURRENDER            = ActionCodeFunctions.getActionCode("ActionSurrender")
local ACTION_CODE_VOTE_FOR_DRAW        = ActionCodeFunctions.getActionCode("ActionVoteForDraw")

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function dispatchEvtMapCursorMoved(self, gridIndex)
    getScriptEventDispatcher(self.m_ModelWar):dispatchEvent({
        name      = "EvtMapCursorMoved",
        gridIndex = gridIndex,
    })
end

local function dispatchEvtWarCommandMenuUpdated(self)
    getScriptEventDispatcher(self.m_ModelWar):dispatchEvent({
        name                = "EvtWarCommandMenuUpdated",
        modelWarCommandMenu = self,
    })
end

--------------------------------------------------------------------------------
-- The dynamic text generator for war info.
--------------------------------------------------------------------------------
local function generateMapTitle(warFieldFileName)
    return string.format("%s: %s      %s: %s",
        getLocalizedText(65, "MapName"), WarFieldManager.getWarFieldName(warFieldFileName),
        getLocalizedText(65, "Author"),  WarFieldManager.getWarFieldAuthorName(warFieldFileName)
    )
end

local function generateEmptyDataForEachPlayer(self)
    local modelWar           = self.m_ModelWar
    local modelPlayerManager = getModelPlayerManager(modelWar)
    local dataForEachPlayer  = {}
    local modelFogMap        = getModelFogMap(modelWar)

    modelPlayerManager:forEachModelPlayer(function(modelPlayer, playerIndex)
        if (modelPlayer:isAlive()) then
            local shouldShowFund = (not modelFogMap:isFogOfWarCurrently()) or (modelPlayerManager:isSameTeamIndex(playerIndex, self.m_PlayerIndexLoggedIn))
            dataForEachPlayer[playerIndex] = {
                energy          = modelPlayer:getEnergy(),
                fund            = (shouldShowFund) and (modelPlayer:getFund()) or ("--"),
                income          = 0,
                idleUnitsCount  = 0,
                nickname        = modelPlayer:getNickname(),
                teamIndex       = modelPlayer:getTeamIndex(),
                tilesCount      = 0,
                unitsCount      = 0,
                unitsValue      = 0,
            }
        end
    end)

    return dataForEachPlayer
end

local function updateUnitsData(self, dataForEachPlayer)
    local updateUnitCountAndValue = function(modelUnit)
        local data          = dataForEachPlayer[modelUnit:getPlayerIndex()]
        data.unitsCount     = data.unitsCount + 1
        data.idleUnitsCount = data.idleUnitsCount + (modelUnit:isStateIdle() and 1 or 0)
        data.unitsValue     = data.unitsValue + AuxiliaryFunctions.round(modelUnit:getNormalizedCurrentHP() * modelUnit:getBaseProductionCost() / 10)
    end

    getModelUnitMap(self.m_ModelWar):forEachModelUnitOnMap(updateUnitCountAndValue)
        :forEachModelUnitLoaded(updateUnitCountAndValue)
end

local function updateTilesData(self, dataForEachPlayer)
    getModelTileMap(self.m_ModelWar):forEachModelTile(function(modelTile)
        local playerIndex = modelTile:getPlayerIndex()
        if (playerIndex ~= 0) then
            local data = dataForEachPlayer[playerIndex]
            data.tilesCount = data.tilesCount + 1

            if (modelTile.getIncomeAmount) then
                data.income = data.income + (modelTile:getIncomeAmount() or 0)
            end
        end
    end)
end

local function getMapInfo(self)
    local modelWar = self.m_ModelWar
    local textList = {
        string.format("%s\n%s: %s      %s: %d      %s: %d",
            generateMapTitle(SingletonGetters.getModelWarField(modelWar):getWarFieldFileName()),
            getLocalizedText(65, "WarID"),             AuxiliaryFunctions.getWarNameWithWarId(SingletonGetters.getWarId(modelWar)),
            getLocalizedText(65, "TurnIndex"),         getModelTurnManager(modelWar):getTurnIndex(),
            getLocalizedText(65, "ActionID"),          getActionId(modelWar)
        ),
        string.format("%s: %d%%      %s: %d%%\n%s: %d%%      %s: %d      %s: %d",
            getLocalizedText(14, "IncomeModifier"),     modelWar:getIncomeModifier(),
            getLocalizedText(14, "EnergyGainModifier"), modelWar:getEnergyGainModifier(),
            getLocalizedText(14, "AttackModifier"),     modelWar:getAttackModifier(),
            getLocalizedText(14, "MoveRangeModifier"),  modelWar:getMoveRangeModifier(),
            getLocalizedText(14, "VisionModifier"),     modelWar:getVisionModifier()
        ),
    }

    return table.concat(textList, "\n--------------------\n")
end

local function getInTurnDescription(modelWar)
    local formattedCountdown = AuxiliaryFunctions.formatTimeInterval(modelWar:getIntervalUntilBoot() - os.time() + modelWar:getEnterTurnTime())
    return string.format("(%s, %s: %s)", getLocalizedText(49), getLocalizedText(34, "BootCountdown"), formattedCountdown)
end

local function generateTextWarInfo(self)
    local dataForEachPlayer = generateEmptyDataForEachPlayer(self)
    updateUnitsData(self, dataForEachPlayer)
    updateTilesData(self, dataForEachPlayer)

    local modelWar          = self.m_ModelWar
    local stringList        = {getMapInfo(self)}
    local playerIndexInTurn = getModelTurnManager(modelWar):getPlayerIndex()
    for i = 1, getModelPlayerManager(modelWar):getPlayersCount() do
        if (not dataForEachPlayer[i]) then
            stringList[#stringList + 1] = string.format("%s %d: %s", getLocalizedText(65, "Player"), i, getLocalizedText(65, "Lost"))
        else
            local d              = dataForEachPlayer[i]
            local isPlayerInTurn = i == playerIndexInTurn
            stringList[#stringList + 1] = string.format("%s %d: %s %s\n%s: %s        %s: %d\n%s: %d        %s: %s        %s: %d\n%s: %d%s        %s: %d",
                getLocalizedText(65, "Player"),       i,           d.nickname, ((isPlayerInTurn) and (getInTurnDescription(modelWar)) or ("")),
                getLocalizedText(14, "TeamIndex"),    AuxiliaryFunctions.getTeamNameWithTeamIndex(d.teamIndex),
                getLocalizedText(65, "Energy"),       d.energy,
                getLocalizedText(65, "TilesCount"),   d.tilesCount,
                getLocalizedText(65, "Fund"),         "" .. d.fund,
                getLocalizedText(65, "Income"),       d.income,
                getLocalizedText(65, "UnitsCount"),   d.unitsCount, ((isPlayerInTurn) and (string.format(" (%d)", d.idleUnitsCount)) or ("")),
                getLocalizedText(65, "UnitsValue"),   d.unitsValue
            )
        end
    end

    return table.concat(stringList, "\n--------------------\n")
end

--------------------------------------------------------------------------------
-- The dynamic text generator for tile info.
--------------------------------------------------------------------------------
local function generateTileInfoWithCounters(tileCounters, showIdleTilesCount)
    return string.format("%s: %d\n%s: %d%s%s: %d%s%s: %d%s%s: %d%s%s: %d\n%s: %d%s%s: %d%s%s: %d%s%s: %d",
        getLocalizedText(65,  "TilesCount"),   tileCounters.total,
        getLocalizedText(116, "Headquarters"), tileCounters.Headquarters, "        ",
        getLocalizedText(116, "City"),         tileCounters.City,         "        ",
        getLocalizedText(116, "Factory"),      tileCounters.Factory,      "        ",
        getLocalizedText(116, "Airport"),      tileCounters.Airport,      "        ",
        getLocalizedText(116, "Seaport"),      tileCounters.Seaport,
        getLocalizedText(116, "CommandTower"), tileCounters.CommandTower, "        ",
        getLocalizedText(116, "Radar"),        tileCounters.Radar,        "        ",
        getLocalizedText(116, "TempAirport"),  tileCounters.TempAirport,  "        ",
        getLocalizedText(116, "TempSeaport"),  tileCounters.TempSeaport
    )
end

local function generateTextTileInfo(self)
    local modelWar           = self.m_ModelWar
    local modelPlayerManager = SingletonGetters.getModelPlayerManager(modelWar)
    local tileCounters       = {}
    for playerIndex = 0, modelPlayerManager:getPlayersCount() do
        tileCounters[playerIndex] = {
            total        = 0,
            Headquarters = 0,
            City         = 0,
            Factory      = 0,
            Airport      = 0,
            Seaport      = 0,
            TempAirport  = 0,
            TempSeaport  = 0,
            CommandTower = 0,
            Radar        = 0,
        }
    end

    SingletonGetters.getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        local tileType = modelTile:getTileType()
        if (tileCounters[0][tileType]) then
            tileCounters[0][tileType] = tileCounters[0][tileType] + 1
            tileCounters[0].total     = tileCounters[0].total     + 1

            local playerIndex = modelTile:getPlayerIndex()
            if (playerIndex ~= 0) then
                tileCounters[playerIndex][tileType] = tileCounters[playerIndex][tileType] + 1
                tileCounters[playerIndex].total     = tileCounters[playerIndex].total     + 1
            end
        end
    end)

    local textList = {string.format("%s\n%s",
        generateMapTitle(SingletonGetters.getModelWarField(modelWar):getWarFieldFileName()),
        generateTileInfoWithCounters(tileCounters[0])
    )}
    modelPlayerManager:forEachModelPlayer(function(modelPlayer, playerIndex)
        if (not modelPlayer:isAlive()) then
            textList[#textList + 1] = string.format("%s %d: %s (%s)", getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(), getLocalizedText(65, "Lost"))
        else
            textList[#textList + 1] = string.format("%s %d: %s\n%s", getLocalizedText(65, "Player"), playerIndex, modelPlayer:getNickname(), generateTileInfoWithCounters(tileCounters[playerIndex]))
        end
    end)

    return table.concat(textList, "\n--------------------\n")
end

--------------------------------------------------------------------------------
-- The dynamic text generator for unit properties.
--------------------------------------------------------------------------------
local function createWeaponPropertyText(unitType)
    local template   = GameConstantFunctions.getTemplateModelUnitWithName(unitType)
    local attackDoer = template.AttackDoer
    if (not attackDoer) then
        return ""
    else
        local maxAmmo = (attackDoer.primaryWeapon) and (attackDoer.primaryWeapon.maxAmmo) or (nil)
        return string.format("%s: %d - %d      %s: %s      %s: %s",
                getLocalizedText(9, "AttackRange"),        attackDoer.minAttackRange, attackDoer.maxAttackRange,
                getLocalizedText(9, "MaxAmmo"),            (maxAmmo) and ("" .. maxAmmo) or ("--"),
                getLocalizedText(9, "CanAttackAfterMove"), getLocalizedText(9, attackDoer.canAttackAfterMove)
            )
    end
end

local function createCommonPropertyText(unitType)
    local template   = GameConstantFunctions.getTemplateModelUnitWithName(unitType)
    local weaponText = createWeaponPropertyText(unitType)
    return string.format("%s: %d (%s)      %s: %d      %s: %d\n%s: %d      %s: %d      %s: %s%s",
        getLocalizedText(9, "Movement"),           template.MoveDoer.range, getLocalizedText(110, template.MoveDoer.type),
        getLocalizedText(9, "Vision"),             template.VisionOwner.vision,
        getLocalizedText(9, "ProductionCost"),     template.Producible.productionCost,
        getLocalizedText(9, "MaxFuel"),            template.FuelOwner.max,
        getLocalizedText(9, "ConsumptionPerTurn"), template.FuelOwner.consumptionPerTurn,
        getLocalizedText(9, "DestroyOnRunOut"),    getLocalizedText(9, template.FuelOwner.destroyOnOutOfFuel),
        ((string.len(weaponText) > 0) and ("\n" .. weaponText) or (weaponText))
    )
end

local function createDamageSubText(targetType, primaryDamage, secondaryDamage)
    local targetTypeText = getLocalizedText(113, targetType)
    local primaryText    = string.format("%s", primaryDamage[targetType]   or "--")
    local secondaryText  = string.format("%s", secondaryDamage[targetType] or "--")

    return string.format("%s:%s%s%s%s",
        targetTypeText, string.rep(" ", 30 - string.len(targetTypeText) / 3 * 4),
        primaryText,    string.rep(" ", 22 - string.len(primaryText) * 2),
        secondaryText
    )
end

local function createDamageText(unitType)
    local baseDamage = GameConstantFunctions.getBaseDamageForAttackerUnitType(unitType)
    if (not baseDamage) then
        return string.format("%s : %s", getLocalizedText(65, "DamageChart"), getLocalizedText(3, "None"))
    else
        local subTexts  = {}
        local primary   = baseDamage.primary or {}
        local secondary = baseDamage.secondary  or {}
        for _, targetType in ipairs(GameConstantFunctions.getCategory("AllUnits")) do
            subTexts[#subTexts + 1] = createDamageSubText(targetType, primary, secondary)
        end
        subTexts[#subTexts + 1] = createDamageSubText("Meteor", primary, secondary)

        local unitTypeText = getLocalizedText(65, "DamageChart")
        return string.format("%s%s%s          %s\n%s",
            unitTypeText, string.rep(" ", 28 - string.len(unitTypeText) / 3 * 4),
            getLocalizedText(65, "MainWeapon"), getLocalizedText(65, "SubWeapon"),
            table.concat(subTexts, "\n")
        )
    end
end

local function createUnitPropertyText(unitType)
    local template = GameConstantFunctions.getTemplateModelUnitWithName(unitType)
    return string.format("%s\n%s\n\n%s",
        getLocalizedText(114, unitType),
        createCommonPropertyText(unitType),
        createDamageText(unitType)
    )
end

--------------------------------------------------------------------------------
-- The dynamic text generator for end turn confirmation.
--------------------------------------------------------------------------------
local function getIdleTilesCount(self)
    local modelWar = self.m_ModelWar
    local modelUnitMap  = getModelUnitMap(modelWar)
    local playerIndex   = getModelTurnManager(modelWar):getPlayerIndex()
    local idleFactoriesCount, idleAirportsCount, idleSeaportsCount = 0, 0, 0

    getModelTileMap(modelWar):forEachModelTile(function(modelTile)
        if ((modelTile:getPlayerIndex() == playerIndex) and (not modelUnitMap:getModelUnit(modelTile:getGridIndex()))) then
            local tileType = modelTile:getTileType()
            if     (tileType == "Airport") then idleAirportsCount  = idleAirportsCount  + 1
            elseif (tileType == "Factory") then idleFactoriesCount = idleFactoriesCount + 1
            elseif (tileType == "Seaport") then idleSeaportsCount  = idleSeaportsCount  + 1
            end
        end
    end)

    return idleFactoriesCount, idleAirportsCount, idleSeaportsCount
end

local function getIdleUnitsCount(self)
    local modelWar = self.m_ModelWar
    local playerIndex   = getModelTurnManager(modelWar):getPlayerIndex()
    local count         = 0

    getModelUnitMap(modelWar):forEachModelUnitOnMap(function(modelUnit)
        if ((modelUnit:getPlayerIndex() == playerIndex) and (modelUnit:isStateIdle())) then
            count = count + 1
        end
    end)

    return count
end

local function createEndTurnText(self)
    local textList       = {}
    local idleUnitsCount = getIdleUnitsCount(self)
    if (idleUnitsCount > 0) then
        textList[#textList + 1] = string.format("%s:  %d", getLocalizedText(65, "IdleUnits"), idleUnitsCount)
    end

    local idleFactoriesCount, idleAirportsCount, idleSeaportsCount = getIdleTilesCount(self)
    if (idleFactoriesCount + idleAirportsCount + idleSeaportsCount > 0) then
        textList[#textList + 1] = string.format("%s:  %d    %d    %d", getLocalizedText(65, "IdleTiles"), idleFactoriesCount, idleAirportsCount, idleSeaportsCount)
    end

    if (#textList == 0) then
        return getLocalizedText(66, "EndTurnConfirmation")
    else
        textList[#textList + 1] = "\n" .. getLocalizedText(66, "EndTurnConfirmation")
        return table.concat(textList, "\n")
    end
end

--------------------------------------------------------------------------------
-- The dynamic items generators.
--------------------------------------------------------------------------------
local function generateItemsForStateAuxiliaryCommands(self)
    local items    = {
        self.m_ItemChat,
        self.m_ItemUnitPropertyList,
        self.m_ItemReload,
    }

    local modelWar            = self.m_ModelWar
    local playerIndexLoggedIn = self.m_PlayerIndexLoggedIn
    if ((playerIndexLoggedIn == getModelTurnManager(modelWar):getPlayerIndex()) and
        (not self.m_IsWaitingForServerResponse))                                then
        local modelUnit = getModelUnitMap(modelWar):getModelUnit(self.m_MapCursorGridIndex)
        self.m_ItemDestroyOwnedUnit.isAvailable = ((modelUnit ~= nil) and (modelUnit:isStateIdle()) and (modelUnit:getPlayerIndex() == playerIndexLoggedIn))

        items[#items + 1] = self.m_ItemDrawOrSurrender
        items[#items + 1] = self.m_ItemFindIdleUnit
        items[#items + 1] = self.m_ItemFindIdleTile
        items[#items + 1] = self.m_ItemDestroyOwnedUnit
    end

    items[#items + 1] = self.m_ItemTileInfo
    items[#items + 1] = self.m_ItemHelp
    items[#items + 1] = self.m_ItemHideUI
    items[#items + 1] = self.m_ItemSetMessageIndicator
    items[#items + 1] = self.m_ItemSetMusic

    return items
end

local function generateItemsForStateDrawOrSurrender(self)
    local modelWar          = self.m_ModelWar
    local playerIndexInTurn = getModelTurnManager(modelWar):getPlayerIndex()
    assert((self.m_PlayerIndexLoggedIn == playerIndexInTurn) and (not self.m_IsWaitingForServerResponse))

    local modelPlayer = getModelPlayerManager(modelWar):getModelPlayer(playerIndexInTurn)
    local items       = {self.m_ItemSurrender}
    if (modelPlayer:hasVotedForDraw()) then
        -- do nothing.
    elseif (not modelWar:getRemainingVotesForDraw()) then
        items[#items + 1] = self.m_ItemProposeDraw
    else
        items[#items + 1] = self.m_ItemAgreeDraw
        items[#items + 1] = self.m_ItemDisagreeDraw
    end

    return items
end

local function generateItemsForStateMain(self)
    local items = {
        self.m_ItemBackToMainScene,
        self.m_ItemSkillInfo,
        self.m_ItemAuxiliaryCommands,
    }
    if ((not self.m_IsWaitingForServerResponse)                                                and
        (getModelTurnManager(self.m_ModelWar):getPlayerIndex() == self.m_PlayerIndexLoggedIn)) then
        items[#items + 1] = self.m_ItemEndTurn
    end

    return items
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------
local function createAndSendAction(self, rawAction, needActionID)
    local modelWar = self.m_ModelWar
    if (needActionID) then
        rawAction.actionID = getActionId(modelWar) + 1
        rawAction.warID    = SingletonGetters.getWarId(self.m_ModelWar)
    end

    WebSocketManager.sendAction(rawAction)
    getModelMessageIndicator(modelWar):showPersistentMessage(getLocalizedText(80, "TransferingData"))
    getScriptEventDispatcher(modelWar):dispatchEvent({
        name    = "EvtIsWaitingForServerResponse",
        waiting = true,
    })
end

local function sendActionActivateSkillGroup(self, skillGroupID)
    createAndSendAction(self, {
        actionCode   = ACTION_CODE_ACTIVATE_SKILL_GROUP,
        skillGroupID = skillGroupID,
    }, true)
end

local function sendActionDestroyOwnedModelUnit(self)
    createAndSendAction(self, {
        actionCode = ACTION_CODE_DESTROY_OWNED_UNIT,
        gridIndex  = self.m_MapCursorGridIndex,
    }, true)
end

local function sendActionEndTurn(self)
    createAndSendAction(self, {actionCode = ACTION_CODE_END_TURN}, true)
end

local function sendActionVoteForDraw(self, doesAgree)
    createAndSendAction(self, {
        actionCode = ACTION_CODE_VOTE_FOR_DRAW,
        doesAgree  = doesAgree,
    }, true)
end

local function sendActionReloadSceneWar(self)
    createAndSendAction(self, {
        actionCode = ACTION_CODE_RELOAD_SCENE_WAR,
        warID      = SingletonGetters.getWarId(self.m_ModelWar),
    }, false)
end

local function sendActionSurrender(self)
    createAndSendAction(self, {actionCode = ACTION_CODE_SURRENDER}, true)
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateAuxiliaryCommands(self)
    self.m_State = "stateAuxiliaryCommands"
    self.m_View:setItems(generateItemsForStateAuxiliaryCommands(self))
end

local function setStateDisabled(self)
    self.m_State = "stateDisabled"
    self.m_View:setVisible(false)

    dispatchEvtWarCommandMenuUpdated(self)
end

local function setStateDrawOrSurrender(self)
    self.m_State = "stateDrawOrSurrender"
    self.m_View:setItems(generateItemsForStateDrawOrSurrender(self))
end

local function setStateHelp(self)
    self.m_State = "stateHelp"
    self.m_View:setItems({
        self.m_ItemGameFlow,
        self.m_ItemWarControl,
        self.m_ItemEssentialConcept,
        self.m_ItemSkillSystem,
        self.m_ItemAbout,
    })
end

local function setStateHiddenWithHideUI(self)
    self.m_State = "stateHiddenWithHideUI"
    self.m_View:setVisible(false)

    dispatchEvtWarCommandMenuUpdated(self)
end

local getActorSkillConfigurator
local function setStateMain(self)
    self.m_State = "stateMain"
    getActorSkillConfigurator(self):getModel():setEnabled(false)

    self.m_View:setItems(generateItemsForStateMain(self))
        :setMenuVisible(true)
        :setOverviewString(generateTextWarInfo(self))
        :setOverviewVisible(true)
        :setVisible(true)

    dispatchEvtWarCommandMenuUpdated(self)
end

local function setStateUnitPropertyList(self)
    self.m_State = "stateUnitPropertyList"

    self.m_View:setItems(self.m_ItemsUnitProperties)
end

--------------------------------------------------------------------------------
-- The private callback functions on script events.
--------------------------------------------------------------------------------
local function onEvtGridSelected(self, event)
    self.m_MapCursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    if (self.m_State == "stateHiddenWithHideUI") then
        setStateDisabled(self)
    end
end

local function onEvtMapCursorMoved(self, event)
    self.m_MapCursorGridIndex = GridIndexFunctions.clone(event.gridIndex)
    if (self.m_State == "stateHiddenWithHideUI") then
        setStateDisabled(self)
    end
end

local function onEvtIsWaitingForServerResponse(self, event)
    self.m_IsWaitingForServerResponse = event.waiting
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
getActorSkillConfigurator = function(self)
    if (not self.m_ActorSkillConfigurator) then
        local model = Actor.createModel("warOnline.ModelSkillConfiguratorForOnline")
        model:onStartRunning(self.m_ModelWar)
            :setCallbackOnButtonBackTouched(function()
                model:setEnabled(false)
                self.m_View:setOverviewVisible(true)
                    :setMenuVisible(true)
            end)

        local view = Actor.createView("common.ViewSkillConfigurator")
        self.m_View:setViewSkillConfigurator(view)

        self.m_ActorSkillConfigurator = Actor.createWithModelAndViewInstance(model, view)
    end

    return self.m_ActorSkillConfigurator
end

local function initItemAbout(self)
    self.m_ItemAbout = {
        name     = getLocalizedText(1, "About"),
        callback = function()
            self.m_View:setOverviewString(getLocalizedText(2, 3))
        end,
    }
end

local function initItemAgreeDraw(self)
    self.m_ItemAgreeDraw = {
        name = getLocalizedText(65, "AgreeDraw"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "AgreeDraw"))
                :setOnConfirmYes(function()
                    sendActionVoteForDraw(self, true)
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                end)
                :setEnabled(true)
        end,
    }
end

local function initItemAuxiliaryCommands(self)
    self.m_ItemAuxiliaryCommands = {
        name     = getLocalizedText(65, "AuxiliaryCommands"),
        callback = function()
            setStateAuxiliaryCommands(self)
        end,
    }
end

local function initItemChat(self)
    self.m_ItemChat = {
        name     = getLocalizedText(65, "Chat"),
        callback = function()
            SingletonGetters.getModelChatManager(self.m_ModelWar):setEnabled(true)
            setStateDisabled(self)
        end,
    }
end

local function initItemDestroyOwnedUnit(self)
    self.m_ItemDestroyOwnedUnit = {
        name     = getLocalizedText(65, "DestroyOwnedUnit"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "DestroyOwnedUnit"))
                :setOnConfirmYes(function()
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                    sendActionDestroyOwnedModelUnit(self)
                end)
                :setEnabled(true)
        end,
    }
end

local function initItemDisagreeDraw(self)
    self.m_ItemDisagreeDraw = {
        name = getLocalizedText(65, "DisagreeDraw"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "DisagreeDraw"))
                :setOnConfirmYes(function()
                    sendActionVoteForDraw(self, false)
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                end)
                :setEnabled(true)
        end,
    }
end

local function initItemDrawOrSurrender(self)
    self.m_ItemDrawOrSurrender = {
        name     = getLocalizedText(65, "DrawOrSurrender"),
        callback = function()
            setStateDrawOrSurrender(self)
        end
    }
end

local function initItemEndTurn(self)
    self.m_ItemEndTurn = {
        name     = getLocalizedText(65, "EndTurn"),
        callback = function()
            local modelWar = self.m_ModelWar
            if ((modelWar:getRemainingVotesForDraw())                                                                                          and
                (not getModelPlayerManager(modelWar):getModelPlayer(getModelTurnManager(modelWar):getPlayerIndex()):hasVotedForDraw())) then
                getModelMessageIndicator(modelWar):showMessage(getLocalizedText(66, "RequireVoteForDraw"))
            else
                local modelConfirmBox = getModelConfirmBox(modelWar)
                modelConfirmBox:setConfirmText(createEndTurnText(self))
                    :setOnConfirmYes(function()
                        modelConfirmBox:setEnabled(false)
                        self:setEnabled(false)
                        sendActionEndTurn(self)
                    end)
                    :setEnabled(true)
            end
        end,
    }
end

local function initItemEssentialConcept(self)
    self.m_ItemEssentialConcept = {
        name     = getLocalizedText(1, "EssentialConcept"),
        callback = function()
            self.m_View:setOverviewString(getLocalizedText(2, 4))
        end,
    }
end

local function initItemFindIdleUnit(self)
    local item = {
        name     = getLocalizedText(65, "FindIdleUnit"),
        callback = function()
            local modelUnitMap        = getModelUnitMap(self.m_ModelWar)
            local mapSize             = modelUnitMap:getMapSize()
            local cursorX, cursorY    = self.m_MapCursorGridIndex.x, self.m_MapCursorGridIndex.y
            local playerIndexLoggedIn = self.m_PlayerIndexLoggedIn
            local firstGridIndex

            for y = 1, mapSize.height do
                for x = 1, mapSize.width do
                    local gridIndex = {x = x, y = y}
                    local modelUnit = modelUnitMap:getModelUnit(gridIndex)
                    if ((modelUnit)                                         and
                        (modelUnit:getPlayerIndex() == playerIndexLoggedIn) and
                        (modelUnit:isStateIdle()))                          then
                        if ((y > cursorY)                       or
                            ((y == cursorY) and (x > cursorX))) then
                            dispatchEvtMapCursorMoved(self, gridIndex)
                            self:setEnabled(false)
                            return
                        end

                        firstGridIndex = firstGridIndex or gridIndex
                    end
                end
            end

            if (firstGridIndex) then
                dispatchEvtMapCursorMoved(self, firstGridIndex)
            else
                getModelMessageIndicator(self.m_ModelWar):showMessage(getLocalizedText(66, "NoIdleUnit"))
            end
            self:setEnabled(false)
        end,
    }

    self.m_ItemFindIdleUnit = item
end

local function initItemFindIdleTile(self)
    local item = {
        name     = getLocalizedText(65, "FindIdleTile"),
        callback = function()
            local modelWar            = self.m_ModelWar
            local playerIndexLoggedIn = self.m_PlayerIndexLoggedIn
            local modelUnitMap        = getModelUnitMap(modelWar)
            local modelTileMap        = getModelTileMap(modelWar)
            local mapSize             = modelUnitMap:getMapSize()
            local cursorX, cursorY    = self.m_MapCursorGridIndex.x, self.m_MapCursorGridIndex.y
            local firstGridIndex

            for y = 1, mapSize.height do
                for x = 1, mapSize.width do
                    local gridIndex = {x = x, y = y}
                    local modelTile = modelTileMap:getModelTile(gridIndex)
                    if ((modelTile.getProductionList)                       and
                        (modelTile:getPlayerIndex() == playerIndexLoggedIn) and
                        (not modelUnitMap:getModelUnit(gridIndex)))         then
                        if ((y > cursorY)                       or
                            ((y == cursorY) and (x > cursorX))) then
                            dispatchEvtMapCursorMoved(self, gridIndex)
                            self:setEnabled(false)
                            return
                        end

                        firstGridIndex = firstGridIndex or gridIndex
                    end
                end
            end

            if (firstGridIndex) then
                dispatchEvtMapCursorMoved(self, firstGridIndex)
            else
                getModelMessageIndicator(self.m_ModelWar):showMessage(getLocalizedText(66, "NoIdleTile"))
            end
            self:setEnabled(false)
        end,
    }

    self.m_ItemFindIdleTile = item
end

local function initItemGameFlow(self)
    local item = {
        name     = getLocalizedText(1, "GameFlow"),
        callback = function()
            if (self.m_View) then
                self.m_View:setOverviewString(getLocalizedText(2, 1))
            end
        end,
    }

    self.m_ItemGameFlow = item
end

local function initItemHelp(self)
    local item = {
        name     = getLocalizedText(65, "Help"),
        callback = function()
            setStateHelp(self)
        end
    }

    self.m_ItemHelp = item
end

local function initItemHideUI(self)
    local item = {
        name     = getLocalizedText(65, "HideUI"),
        callback = function()
            setStateHiddenWithHideUI(self)
        end,
    }

    self.m_ItemHideUI = item
end

local function initItemProposeDraw(self)
    self.m_ItemProposeDraw = {
        name     = getLocalizedText(65, "ProposeDraw"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "ProposeDraw"))
                :setOnConfirmYes(function()
                    sendActionVoteForDraw(self, true)
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                end)
                :setEnabled(true)
        end,
    }
end

local function initItemSkillInfo(self)
    self.m_ItemSkillInfo = {
        name     = getLocalizedText(22, "SkillInfo"),
        callback = function()
            self.m_View:setMenuVisible(false)
                :setOverviewVisible(false)
            getActorSkillConfigurator(self):getModel():setEnabled(true)
        end,
    }
end

local function initItemSkillSystem(self)
    local item = {
        name     = getLocalizedText(1, "SkillSystem"),
        callback = function()
            self.m_View:setOverviewString(getLocalizedText(2, 5))
        end,
    }

    self.m_ItemSkillSystem = item
end

local function initItemTileInfo(self)
    self.m_ItemTileInfo = {
        name     = getLocalizedText(65, "TileInfo"),
        callback = function()
            self.m_View:setOverviewString(generateTextTileInfo(self))
        end,
    }
end

local function initItemUnitPropertyList(self)
    local item = {
        name     = getLocalizedText(65, "UnitPropertyList"),
        callback = function()
            setStateUnitPropertyList(self)
        end,
    }

    self.m_ItemUnitPropertyList = item
end

local function initItemsUnitProperties(self)
    local items    = {}
    local allUnits = GameConstantFunctions.getCategory("AllUnits")
    for _, unitType in ipairs(allUnits) do
        items[#items + 1] = {
            name     = getLocalizedText(113, unitType),
            callback = function()
                if (self.m_View) then
                    self.m_View:setOverviewString(createUnitPropertyText(unitType))
                end
            end,
        }
    end

    self.m_ItemsUnitProperties = items
end

local function initItemBackToMainScene(self)
    self.m_ItemBackToMainScene = {
        name     = getLocalizedText(65, "BackToMainScene"),
        callback = function()
            getModelConfirmBox(self.m_ModelWar):setConfirmText(getLocalizedText(66, "QuitWar"))
                :setOnConfirmYes(function()
                    local modelSceneMain = Actor.createModel("sceneMain.ModelSceneMain", {isPlayerLoggedIn = WebSocketManager.getLoggedInAccountAndPassword() ~= nil})
                    local actorSceneMain = Actor.createWithModelAndViewInstance(modelSceneMain, Actor.createView("sceneMain.ViewSceneMain"))
                    ActorManager.setAndRunRootActor(actorSceneMain, "FADE", 1)
                end)
                :setEnabled(true)
        end,
    }
end

local function initItemReload(self)
    local item = {
        name     = getLocalizedText(65, "ReloadWar"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "ReloadWar"))
                :setOnConfirmYes(function()
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                    sendActionReloadSceneWar(self)
                end)
                :setEnabled(true)
        end,
    }

    self.m_ItemReload = item
end

local function initItemSetMessageIndicator(self)
    self.m_ItemSetMessageIndicator = {
        name     = getLocalizedText(1, "SetMessageIndicator"),
        callback = function()
            local indicator = SingletonGetters.getModelMessageIndicator(self.m_ModelWar)
            indicator:setEnabled(not indicator:isEnabled())
        end,
    }
end

local function initItemSetMusic(self)
    local item = {
        name     = getLocalizedText(1, "SetMusic"),
        callback = function()
            local isEnabled = not AudioManager.isEnabled()
            AudioManager.setEnabled(isEnabled)
            if (isEnabled) then
                AudioManager.playRandomWarMusic()
            end
        end,
    }

    self.m_ItemSetMusic = item
end

local function initItemSurrender(self)
    local item = {
        name     = getLocalizedText(65, "Surrender"),
        callback = function()
            local modelConfirmBox = getModelConfirmBox(self.m_ModelWar)
            modelConfirmBox:setConfirmText(getLocalizedText(66, "Surrender"))
                :setOnConfirmYes(function()
                    modelConfirmBox:setEnabled(false)
                    self:setEnabled(false)
                    sendActionSurrender(self)
                end)
                :setEnabled(true)
        end,
    }

    self.m_ItemSurrender = item
end

local function initItemWarControl(self)
    local item = {
        name     = getLocalizedText(1, "WarControl"),
        callback = function()
            self.m_View:setOverviewString(getLocalizedText(2, 2))
        end,
    }

    self.m_ItemWarControl = item
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarCommandMenuForOnline:ctor(param)
    self.m_IsWaitingForServerResponse = false
    self.m_State                      = "stateDisabled"

    initItemAbout(              self)
    initItemAgreeDraw(          self)
    initItemAuxiliaryCommands(  self)
    initItemBackToMainScene(    self)
    initItemChat(               self)
    initItemDestroyOwnedUnit(   self)
    initItemDisagreeDraw(       self)
    initItemDrawOrSurrender(    self)
    initItemEndTurn(            self)
    initItemEssentialConcept(   self)
    initItemFindIdleTile(       self)
    initItemFindIdleUnit(       self)
    initItemGameFlow(           self)
    initItemHelp(               self)
    initItemHideUI(             self)
    initItemProposeDraw(        self)
    initItemReload(             self)
    initItemSkillInfo(          self)
    initItemSkillSystem(        self)
    initItemSetMessageIndicator(self)
    initItemSetMusic(           self)
    initItemSurrender(          self)
    initItemsUnitProperties(    self)
    initItemTileInfo(           self)
    initItemUnitPropertyList(   self)
    initItemWarControl(         self)

    return self
end

--------------------------------------------------------------------------------
-- The public callback function on start running or script events.
--------------------------------------------------------------------------------
function ModelWarCommandMenuForOnline:onStartRunning(modelWar)
    self.m_ModelWar             = modelWar
    self.m_PlayerIndexLoggedIn, self.m_ModelPlayerLoggedIn = SingletonGetters.getPlayerIndexLoggedIn(modelWar)

    getScriptEventDispatcher(modelWar)
        :addEventListener("EvtIsWaitingForServerResponse", self)
        :addEventListener("EvtGridSelected",               self)
        :addEventListener("EvtMapCursorMoved",             self)

    return self
end

function ModelWarCommandMenuForOnline:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtGridSelected")               then onEvtGridSelected(              self, event)
    elseif (eventName == "EvtMapCursorMoved")             then onEvtMapCursorMoved(            self, event)
    elseif (eventName == "EvtIsWaitingForServerResponse") then onEvtIsWaitingForServerResponse(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarCommandMenuForOnline:isEnabled()
    return (self.m_State ~= "stateDisabled") and (self.m_State ~= "stateHiddenWithHideUI")
end

function ModelWarCommandMenuForOnline:isHiddenWithHideUI()
    return self.m_State == "stateHiddenWithHideUI"
end

function ModelWarCommandMenuForOnline:setEnabled(enabled)
    if (enabled) then
        setStateMain(self)
    else
        setStateDisabled(self)
    end

    return self
end

function ModelWarCommandMenuForOnline:onButtonBackTouched()
    local state = self.m_State
    if     (state == "stateAuxiliaryCommands") then setStateMain(             self)
    elseif (state == "stateDrawOrSurrender")   then setStateAuxiliaryCommands(self)
    elseif (state == "stateHelp")              then setStateAuxiliaryCommands(self)
    elseif (state == "stateMain")              then setStateDisabled(         self)
    elseif (state == "stateUnitPropertyList")  then setStateAuxiliaryCommands(self)
    else                                       error("ModelWarCommandMenuForOnline:onButtonBackTouched() the state is invalid: " .. (state or ""))
    end

    return self
end

return ModelWarCommandMenuForOnline
