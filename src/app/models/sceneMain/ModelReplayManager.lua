
local ModelReplayManager = class("ModelReplayManager")

local Actor                  = requireFW("src.global.actors.Actor")
local ActorManager           = requireFW("src.global.actors.ActorManager")
local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions     = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions  = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local WarFieldManager        = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager       = requireFW("src.app.utilities.WebSocketManager")

local getLocalizedText         = LocalizationFunctions.getLocalizedText
local getModelMessageIndicator = SingletonGetters.getModelMessageIndicator
local string                   = string

local ACTION_CODE_DOWNLOAD_REPLAY_DATA      = ActionCodeFunctions.getActionCode("ActionDownloadReplayData")
local ACTION_CODE_GET_REPLAY_CONFIGURATIONS = ActionCodeFunctions.getActionCode("ActionGetReplayConfigurations")

local REPLAY_DIRECTORY_PATH = cc.FileUtils:getInstance():getWritablePath() .. "writablePath/replay/"
local REPLAY_LIST_PATH      = REPLAY_DIRECTORY_PATH .. "ReplayList.lua"

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function getReplayDataFileName(warID)
    return REPLAY_DIRECTORY_PATH .. warID .. ".spdata"
end

local function loadReplayList()
    local file = io.open(REPLAY_LIST_PATH, "rb")
    if (not file) then
        return nil
    else
        local replayList = SerializationFunctions.decode("ReplayListForClient", file:read("*a")).list
        file:close()

        return replayList
    end
end

local function serializeReplayList(replayList)
    local file = io.open(REPLAY_LIST_PATH, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(REPLAY_DIRECTORY_PATH)
        file = io.open(REPLAY_LIST_PATH, "wb")
    end
    file:write(SerializationFunctions.encode("ReplayListForClient", {list = replayList}))
    file:close()
end

local function loadDecodedReplayData(warID)
    local file = io.open(getReplayDataFileName(warID), "rb")
    local replayData = SerializationFunctions.decode("SceneWar", file:read("*a"))
    file:close()
    return replayData
end

local function serializeEncodedReplayData(warID, encodedReplayData)
    local fileName = getReplayDataFileName(warID)
    local file     = io.open(fileName, "wb")
    if (not file) then
        cc.FileUtils:getInstance():createDirectory(REPLAY_DIRECTORY_PATH)
        file = io.open(fileName, "wb")
    end
    file:write(encodedReplayData)
    file:close()
end

local function deleteReplayData(self, warID)
    if (self.m_ReplayList[warID]) then
        os.remove(getReplayDataFileName(warID))

        self.m_ReplayList[warID] = nil
        serializeReplayList(self.m_ReplayList)
    end
end

local function generateReplayConfiguration(warData)
    local players = {}
    for playerIndex, player in pairs(warData.players) do
        players[playerIndex] = {
            account   = player.account,
            nickname  = player.nickname,
            teamIndex = player.teamIndex or playerIndex,
        }
    end

    return {
        actionsCount     = #warData.executedActions,
        players          = players,
        warID            = warData.warID,
        warFieldFileName = warData.warField.warFieldFileName,
    }
end

local function generateLeftLabelText(replayConfiguration)
    local players  = replayConfiguration.players
    local textList = {getLocalizedText(48, "Players")}
    for i = 1, WarFieldManager.getPlayersCount(replayConfiguration.warFieldFileName) do
        textList[#textList + 1] = string.format("%d. %s (%s: %s)",
            i,
            players[i].account,
            getLocalizedText(14, "TeamIndex"),
            AuxiliaryFunctions.getTeamNameWithTeamIndex((players[i].teamIndex) or (i))
        )
    end

    if (replayConfiguration.actionsCount) then
        textList[#textList + 1] = string.format("%s: %d", getLocalizedText(14, "ActionsCount"), replayConfiguration.actionsCount)
    end

    return table.concat(textList, "\n")
end

local function getActorWarFieldPreviewer(self)
    if (not self.m_ActorWarFieldPreviewer) then
        local actor = Actor.createWithModelAndViewName("sceneMain.ModelWarFieldPreviewer", nil, "sceneMain.ViewWarFieldPreviewer")

        self.m_ActorWarFieldPreviewer = actor
        if (self.m_View) then
            self.m_View:setViewWarFieldPreviewer(actor:getView())
        end
    end

    return self.m_ActorWarFieldPreviewer
end

local setStateDelete
local function createMenuItemsForDelete(self)
    local items = {}
    for warID, replayConfiguration in pairs(self.m_ReplayList) do
        local warFieldFileName = replayConfiguration.warFieldFileName
        items[#items + 1] = {
            name         = WarFieldManager.getWarFieldName(warFieldFileName),
            warID        = warID,
            actionsCount = replayConfiguration.actionsCount,
            callback     = function()
                getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                    :setLeftLabelText(generateLeftLabelText(replayConfiguration))
                    :setEnabled(true)
                if (self.m_View) then
                    self.m_View:setButtonConfirmVisible(true)
                end

                self.m_OnButtonConfirmTouched = function()
                    local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain)
                    modelConfirmBox:setEnabled(true)
                        :setConfirmText(getLocalizedText(10, "DeleteConfirmation"))
                        :setOnConfirmYes(function()
                            deleteReplayData(self, warID)
                            setStateDelete(self)
                            modelConfirmBox:setEnabled(false)
                        end)
                end
            end,
        }
    end

    table.sort(items, function(item1, item2)
        return item1.warID < item2.warID
    end)

    return items
end

local function createMenuItemsForDownload(self, list)
    local items = {}
    for _, replayConfiguration in pairs(list or {}) do
        local warID            = replayConfiguration.warID
        local warFieldFileName = replayConfiguration.warFieldFileName
        if (not self.m_ReplayList[warID]) then
            items[#items + 1] = {
                name         = WarFieldManager.getWarFieldName(warFieldFileName),
                warID        = warID,
                actionsCount = replayConfiguration.actionsCount,
                callback     = function()
                    getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                        :setLeftLabelText(generateLeftLabelText(replayConfiguration))
                        :setEnabled(true)
                    if (self.m_View) then
                        self.m_View:setButtonConfirmVisible(true)
                    end

                    self.m_OnButtonConfirmTouched = function()
                        WebSocketManager.sendAction({
                            actionCode = ACTION_CODE_DOWNLOAD_REPLAY_DATA,
                            warID      = warID,
                        })
                        if (self.m_View) then
                            self.m_View:disableButtonConfirmForSecs(10)
                        end

                        getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "DownloadStarted"))
                    end
                end,
            }
        end
    end

    table.sort(items, function(item1, item2)
        return item1.warID < item2.warID
    end)

    return items
end

local setStateLoadReplay
local function createMenuItemsForPlayback(self)
    local items = {}
    for warID, replayConfiguration in pairs(self.m_ReplayList) do
        local warFieldFileName = replayConfiguration.warFieldFileName
        items[#items + 1] = {
            name         = WarFieldManager.getWarFieldName(warFieldFileName),
            warID        = warID,
            actionsCount = replayConfiguration.actionsCount,
            callback     = function()
                getActorWarFieldPreviewer(self):getModel():setWarField(warFieldFileName)
                    :setLeftLabelText(generateLeftLabelText(replayConfiguration))
                    :setEnabled(true)

                self.m_View:setButtonConfirmVisible(true)

                self.m_OnButtonConfirmTouched = function()
                    setStateLoadReplay(self)
                    self.m_View:runAction(cc.Sequence:create(
                        cc.DelayTime:create(0.02),
                        cc.CallFunc:create(function()
                            local modelWarReplay = Actor.createModel("warReplay.ModelWarReplay", loadDecodedReplayData(warID))
                            modelWarReplay:initWarDataForEachTurn()
                            ActorManager.setAndRunRootActor(Actor.createWithModelAndViewInstance(modelWarReplay, Actor.createView("common.ViewSceneWar")), "FADE", 1)
                        end)
                    ))
                end
            end,
        }
    end

    table.sort(items, function(item1, item2)
        return item1.warID < item2.warID
    end)

    return items
end

--------------------------------------------------------------------------------
-- The functions for managing states.
--------------------------------------------------------------------------------
setStateDelete = function(self)
    self.m_State = "stateDelete"
    local view = self.m_View
    if (view) then
        view:setMenuTitle(getLocalizedText(10, "DeleteReplay"))
            :setButtonConfirmText(getLocalizedText(10, "DeleteReplay"))
            :setButtonConfirmVisible(false)
            :setButtonFindVisible(false)
            :enableButtonConfirm()
        getActorWarFieldPreviewer(self):getModel():setEnabled(false)

        local items = createMenuItemsForDelete(self)
        if (#items == 0) then
            view:removeAllMenuItems()
            getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "NoReplayData"))
        else
            view:setMenuItems(items)
        end
    end
end

local function setStateDisabled(self)
    self.m_State = "stateDisabled"
    if (self.m_View) then
        self.m_View:setVisible(false)
        getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    end
end

local function setStateDownload(self)
    self.m_State = "stateDownload"
    WebSocketManager.sendAction({
        actionCode = ACTION_CODE_GET_REPLAY_CONFIGURATIONS,
    })

    if (self.m_View) then
        self.m_View:setMenuTitle(getLocalizedText(10, "DownloadReplay"))
            :setButtonConfirmVisible(false)
            :setButtonFindVisible(true)
            :removeAllMenuItems()
        getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    end
end

setStateLoadReplay = function(self)
    self.m_State = "stateLoadReplay"

    SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showPersistentMessage(getLocalizedText(10, "LoadingReplay"))
    self.m_View:disableButtonConfirmForSecs(999)
end

local function setStateMain(self)
    self.m_State = "stateMain"
    if (self.m_View) then
        self.m_View:setMenuTitle(getLocalizedText(1, "ManageReplay"))
            :setMenuItems(self.m_ItemsForStateMain)
            :setButtonConfirmVisible(false)
            :setButtonFindVisible(false)
            :setVisible(true)
        getActorWarFieldPreviewer(self):getModel():setEnabled(false)
    end
end

local function setStatePlayback(self)
    self.m_State = "statePlayback"
    local view = self.m_View
    if (view) then
        view:setMenuTitle(getLocalizedText(10, "Playback"))
            :setButtonConfirmText(getLocalizedText(10, "Playback"))
            :setButtonConfirmVisible(false)
            :setButtonFindVisible(false)
            :enableButtonConfirm()
        getActorWarFieldPreviewer(self):getModel():setEnabled(false)

        local items = createMenuItemsForPlayback(self)
        if (#items == 0) then
            view:removeAllMenuItems()
            getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "NoReplayData"))
        else
            view:setMenuItems(items)
        end
    end
end

--------------------------------------------------------------------------------
-- The composition items.
--------------------------------------------------------------------------------
local function initReplayList(self)
    self.m_ReplayList = loadReplayList()
    if (not self.m_ReplayList) then
        self.m_ReplayList = {}
        serializeReplayList(self.m_ReplayList)
    end
end

local function initItemPlayback(self)
    local item = {
        name     = getLocalizedText(10, "Playback"),
        callback = function()
            setStatePlayback(self)
        end,
    }

    self.m_ItemPlayback = item
end

local function initItemDownload(self)
    local item = {
        name     = getLocalizedText(10, "Download"),
        callback = function()
            setStateDownload(self)
        end,
    }

    self.m_ItemDownload = item
end

local function initItemDelete(self)
    local item = {
        name     = getLocalizedText(10, "Delete"),
        callback = function()
            setStateDelete(self)
        end,
    }

    self.m_ItemDelete = item
end

local function initItemsForStateMain(self)
    self.m_ItemsForStateMain = {
        self.m_ItemPlayback,
        self.m_ItemDownload,
        self.m_ItemDelete,
    }
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelReplayManager:ctor()
    self.m_State = "stateDisabled"

    initReplayList(       self)
    initItemPlayback(     self)
    initItemDownload(     self)
    initItemDelete(       self)
    initItemsForStateMain(self)

    return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelReplayManager:onStartRunning(modelSceneMain)
    self.m_ModelSceneMain = modelSceneMain

    return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelReplayManager:setEnabled(enabled)
    if (enabled) then
        setStateMain(self)
    else
        setStateDisabled(self)
    end

    return self
end

function ModelReplayManager:isRetrievingReplayConfigurations()
    return self.m_State == "stateDownload"
end

function ModelReplayManager:updateWithReplayConfigurations(replayConfigurations)
    local items = createMenuItemsForDownload(self, replayConfigurations)
    if (#items == 0) then
        getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "NoDownloadableReplay"))
    else
        self.m_View:setMenuItems(items)
            :setButtonConfirmText(getLocalizedText(10, "DownloadReplay"))
    end

    return self
end

function ModelReplayManager:isRetrievingEncodedReplayData()
    return self.m_State ~= "stateDisabled"
end

function ModelReplayManager:updateWithEncodedReplayData(encodedReplayData)
    local replayData = SerializationFunctions.decode("SceneWar", encodedReplayData)
    local warID      = replayData.warID
    if (not self.m_ReplayList[warID]) then
        serializeEncodedReplayData(warID, encodedReplayData)

        self.m_ReplayList[warID] = generateReplayConfiguration(replayData)
        serializeReplayList(self.m_ReplayList)
    end
    getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "ReplayDataExists"))

    return self
end

function ModelReplayManager:onButtonBackTouched()
    local state = self.m_State
    if (state == "stateMain") then
        setStateDisabled(self)
        SingletonGetters.getModelMainMenu(self.m_ModelSceneMain):setMenuEnabled(true)
    elseif (state == "stateDownload") then
        setStateMain(self)
    elseif (state == "stateDelete") then
        setStateMain(self)
    elseif (state == "statePlayback") then
        setStateMain(self)
    elseif (state == "stateLoadReplay") then
        -- do nothing.
    else
        error("ModelReplayManager:onButtonBackTouched() the current state is invalid: " .. state)
    end

    return self
end

function ModelReplayManager:onButtonConfirmTouched()
    self.m_OnButtonConfirmTouched()

    return self
end

function ModelReplayManager:onButtonFindTouched(warName)
    if (string.len(warName) ~= 6) then
        getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "InvalidWarName"))
    else
        getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(10, "RetrievingReplayConfiguration"))
        WebSocketManager.sendAction({
            actionCode = ACTION_CODE_GET_REPLAY_CONFIGURATIONS,
            warID      = AuxiliaryFunctions.getWarIdWithWarName(warName),
        })
    end

    return self
end

return ModelReplayManager
