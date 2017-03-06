
local ModelWarCommandMenuForReplay = class("ModelWarCommandMenuForReplay")

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
local round                    = AuxiliaryFunctions.round
local string, ipairs, pairs    = string, ipairs, pairs

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function dispatchEvtWarCommandMenuUpdated(self)
    getScriptEventDispatcher(self.m_ModelWarReplay):dispatchEvent({
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
    local modelWarReplay      = self.m_ModelWarReplay
    local modelPlayerManager = getModelPlayerManager(modelWarReplay)
    local dataForEachPlayer  = {}
    local modelFogMap        = getModelFogMap(modelWarReplay)

    modelPlayerManager:forEachModelPlayer(function(modelPlayer, playerIndex)
        if (modelPlayer:isAlive()) then
            dataForEachPlayer[playerIndex] = {
                nickname            = modelPlayer:getNickname(),
                fund                = modelPlayer:getFund(),
                energy              = modelPlayer:getEnergy(),
                idleUnitsCount      = 0,
                isSkillDeclared     = modelPlayer:isSkillDeclared(),
                unitsCount          = 0,
                unitsValue          = 0,
                tilesCount          = 0,
                income              = 0,
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
        data.unitsValue     = data.unitsValue + round(modelUnit:getNormalizedCurrentHP() * modelUnit:getBaseProductionCost() / 10)
    end

    getModelUnitMap(self.m_ModelWarReplay):forEachModelUnitOnMap(updateUnitCountAndValue)
        :forEachModelUnitLoaded(updateUnitCountAndValue)
end

local function updateTilesData(self, dataForEachPlayer)
    local modelUnitMap = getModelUnitMap(self.m_ModelWarReplay)
    getModelTileMap(self.m_ModelWarReplay):forEachModelTile(function(modelTile)
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
    local modelWar = self.m_ModelWarReplay
    local textList = {
        string.format("%s\n%s: %s      %s: %d      %s: %d",
            generateMapTitle(SingletonGetters.getModelWarField(modelWar):getWarFieldFileName()),
            getLocalizedText(65, "WarID"),             AuxiliaryFunctions.getWarNameWithWarId(SingletonGetters.getWarId(modelWar)),
            getLocalizedText(65, "TurnIndex"),         getModelTurnManager(modelWar):getTurnIndex(),
            getLocalizedText(65, "ActionID"),          getActionId(modelWar)
        ),
        string.format("%s: %d%%      %s: %d%%\n%s: %d%%      %s: %d",
            getLocalizedText(14, "IncomeModifier"),     modelWar:getIncomeModifier(),
            getLocalizedText(14, "EnergyGainModifier"), modelWar:getEnergyGainModifier(),
            getLocalizedText(14, "AttackModifier"),     modelWar:getAttackModifier(),
            getLocalizedText(14, "MoveRangeModifier"),  modelWar:getMoveRangeModifier()
        ),
    }

    return table.concat(textList, "\n--------------------\n")
end

local function getInTurnDescription(modelWarReplay)
    return string.format("(%s)", getLocalizedText(49))
end

local function generateTextWarInfo(self)
    local dataForEachPlayer = generateEmptyDataForEachPlayer(self)
    updateUnitsData(self, dataForEachPlayer)
    updateTilesData(self, dataForEachPlayer)

    local modelWarReplay    = self.m_ModelWarReplay
    local stringList        = {getMapInfo(self)}
    local playerIndexInTurn = getModelTurnManager(modelWarReplay):getPlayerIndex()
    for i = 1, getModelPlayerManager(modelWarReplay):getPlayersCount() do
        if (not dataForEachPlayer[i]) then
            stringList[#stringList + 1] = string.format("%s %d: %s", getLocalizedText(65, "Player"), i, getLocalizedText(65, "Lost"))
        else
            local d                  = dataForEachPlayer[i]
            local isPlayerInTurn     = i == playerIndexInTurn
            stringList[#stringList + 1] = string.format("%s %d: %s %s\n%s: %d        %s: %s\n%s: %d        %s: %s        %s: %d\n%s: %d%s        %s: %d",
                getLocalizedText(65, "Player"),       i,           d.nickname, ((isPlayerInTurn) and (getInTurnDescription(modelWarReplay)) or ("")),
                getLocalizedText(65, "Energy"),       d.energy,
                getLocalizedText(22, "DeclareSkill"), (d.isSkillDeclared) and (getLocalizedText(22, "Yes")) or (getLocalizedText(22, "No")),
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
local function generateTileInfoWithCounters(tileCounters)
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
    local modelWarReplay           = self.m_ModelWarReplay
    local modelPlayerManager = SingletonGetters.getModelPlayerManager(modelWarReplay)
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

    SingletonGetters.getModelTileMap(modelWarReplay):forEachModelTile(function(modelTile)
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
        generateMapTitle(SingletonGetters.getModelWarField(modelWarReplay):getWarFieldFileName()),
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
-- The dynamic item generators.
--------------------------------------------------------------------------------
local function generateItemsForStateMain(self)
    return {
        self.m_ItemQuit,
        self.m_ItemSkillInfo,
        self.m_ItemAuxiliaryCommands,
        self.m_ItemHelp,
    }
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateAuxiliaryCommands(self)
    self.m_State = "stateAuxiliaryCommands"

    self.m_View:setItems({
        self.m_ItemTileInfo,
        self.m_ItemHideUI,
        self.m_ItemSetMessageIndicator,
        self.m_ItemSetMusic,
    })
end

local function setStateDisabled(self)
    self.m_State = "stateDisabled"
    self.m_View:setVisible(false)

    dispatchEvtWarCommandMenuUpdated(self)
end

local function setStateHelp(self)
    self.m_State = "stateHelp"

    self.m_View:setItems({
        self.m_ItemUnitPropertyList,
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
    if (self.m_State == "stateHiddenWithHideUI") then
        setStateDisabled(self)
    end
end

local function onEvtMapCursorMoved(self, event)
    if (self.m_State == "stateHiddenWithHideUI") then
        setStateDisabled(self)
    end
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
getActorSkillConfigurator = function(self)
    if (not self.m_ActorSkillConfigurator) then
        local model = Actor.createModel("warReplay.ModelSkillConfiguratorForReplay")
        model:onStartRunning(self.m_ModelWarReplay)
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

local function initItemAuxiliaryCommands(self)
    self.m_ItemAuxiliaryCommands = {
        name     = getLocalizedText(65, "AuxiliaryCommands"),
        callback = function()
            setStateAuxiliaryCommands(self)
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

local function initItemQuit(self)
    local item = {
        name     = getLocalizedText(65, "QuitWar"),
        callback = function()
            getModelConfirmBox(self.m_ModelWarReplay):setConfirmText(getLocalizedText(66, "QuitWar"))
                :setOnConfirmYes(function()
                    local modelSceneMain = Actor.createModel("sceneMain.ModelSceneMain", {isPlayerLoggedIn = WebSocketManager.getLoggedInAccountAndPassword() ~= nil})
                    local actorSceneMain = Actor.createWithModelAndViewInstance(modelSceneMain, Actor.createView("sceneMain.ViewSceneMain"))
                    ActorManager.setAndRunRootActor(actorSceneMain, "FADE", 1)
                end)
                :setEnabled(true)
        end,
    }

    self.m_ItemQuit = item
end

local function initItemSetMessageIndicator(self)
    self.m_ItemSetMessageIndicator = {
        name     = getLocalizedText(1, "SetMessageIndicator"),
        callback = function()
            local indicator = SingletonGetters.getModelMessageIndicator(self.m_ModelWarReplay)
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
function ModelWarCommandMenuForReplay:ctor(param)
    self.m_State = "stateDisabled"

    initItemAbout(              self)
    initItemAuxiliaryCommands(  self)
    initItemEssentialConcept(   self)
    initItemGameFlow(           self)
    initItemHelp(               self)
    initItemHideUI(             self)
    initItemQuit(               self)
    initItemSkillInfo(          self)
    initItemSkillSystem(        self)
    initItemSetMessageIndicator(self)
    initItemSetMusic(           self)
    initItemsUnitProperties(    self)
    initItemTileInfo(           self)
    initItemUnitPropertyList(   self)
    initItemWarControl(         self)

    return self
end

--------------------------------------------------------------------------------
-- The public callback function on start running or script events.
--------------------------------------------------------------------------------
function ModelWarCommandMenuForReplay:onStartRunning(modelWarReplay)
    self.m_ModelWarReplay = modelWarReplay
    getScriptEventDispatcher(modelWarReplay)
        :addEventListener("EvtGridSelected",   self)
        :addEventListener("EvtMapCursorMoved", self)

    return self
end

function ModelWarCommandMenuForReplay:onEvent(event)
    local eventName = event.name
    if     (eventName == "EvtGridSelected")   then onEvtGridSelected(  self, event)
    elseif (eventName == "EvtMapCursorMoved") then onEvtMapCursorMoved(self, event)
    end

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarCommandMenuForReplay:isEnabled()
    return (self.m_State ~= "stateDisabled") and (self.m_State ~= "stateHiddenWithHideUI")
end

function ModelWarCommandMenuForReplay:isHiddenWithHideUI()
    return self.m_State == "stateHiddenWithHideUI"
end

function ModelWarCommandMenuForReplay:setEnabled(enabled)
    if (enabled) then
        setStateMain(self)
    else
        setStateDisabled(self)
    end

    return self
end

function ModelWarCommandMenuForReplay:onButtonBackTouched()
    local state = self.m_State
    if     (state == "stateAuxiliaryCommands") then setStateMain(self)
    elseif (state == "stateHelp")              then setStateMain(self)
    elseif (state == "stateMain")              then self:setEnabled(false)
    elseif (state == "stateUnitPropertyList")  then setStateHelp(self)
    else                                       error("ModelWarCommandMenuForReplay:onButtonBackTouched() the state is invalid: " .. (state or ""))
    end

    return self
end

return ModelWarCommandMenuForReplay
