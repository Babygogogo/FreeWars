
local ActionExecutorForSceneMain = {}

local ActionCodeFunctions    = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions     = requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions  = requireFW("src.app.utilities.LocalizationFunctions")
local SerializationFunctions = requireFW("src.app.utilities.SerializationFunctions")
local SingletonGetters       = requireFW("src.app.utilities.SingletonGetters")
local WebSocketManager       = requireFW("src.app.utilities.WebSocketManager")
local Actor                  = requireFW("src.global.actors.Actor")
local ActorManager           = requireFW("src.global.actors.ActorManager")

local ACTION_CODES = ActionCodeFunctions.getFullList()

local getLocalizedText              = LocalizationFunctions.getLocalizedText
local getLoggedInAccountAndPassword = (WebSocketManager) and (WebSocketManager.getLoggedInAccountAndPassword) or (nil)
local getModelMessageIndicator      = SingletonGetters.getModelMessageIndicator

local math, string                  = math, string
local next, pairs, ipairs, unpack   = next, pairs, ipairs, unpack

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function runSceneMain(isPlayerLoggedIn, confirmText)
    local modelSceneMain = Actor.createModel("sceneMain.ModelSceneMain", {
        isPlayerLoggedIn = isPlayerLoggedIn,
        confirmText      = confirmText,
    })
    local viewSceneMain  = Actor.createView( "sceneMain.ViewSceneMain")

    ActorManager.setAndRunRootActor(Actor.createWithModelAndViewInstance(modelSceneMain, viewSceneMain), "FADE", 1)
end

--------------------------------------------------------------------------------
-- The executors for non-war actions.
--------------------------------------------------------------------------------
local function executeChat(action, modelSceneMain)
    SingletonGetters.getModelMessageIndicator(modelSceneMain):showMessage(string.format("%s[%s]%s: %s",
        getLocalizedText(65, "War"),
        AuxiliaryFunctions.getWarNameWithWarId(action.warID),
        getLocalizedText(65, "ReceiveChatText"),
        action.chatText
    ))
end

local function executeDownloadReplayData(action, modelSceneMain)
    local modelReplayManager = modelSceneMain:getModelMainMenu():getModelReplayManager()
    if (modelReplayManager:isRetrievingEncodedReplayData()) then
        modelReplayManager:updateWithEncodedReplayData(action.encodedReplayData)
    end
end

local function executeExitWar(action, modelSceneMain)
    local warID = action.warID
    getModelMessageIndicator(modelSceneMain):showMessage(getLocalizedText(56, "ExitWarSuccessfully", AuxiliaryFunctions.getWarNameWithWarId(warID)))

    local modelMainMenu        = modelSceneMain:getModelMainMenu()
    local modelExitWarSelector = modelMainMenu:getModelExitWarSelector()
    if (modelExitWarSelector:isRetrievingExitWarResult(warID)) then
        modelExitWarSelector:setEnabled(false)
        modelMainMenu:setMenuEnabled(true)
    end
end

local function executeGetJoinableWarConfigurations(action, modelSceneMain)
    local modelJoinWarSelector = modelSceneMain:getModelMainMenu():getModelJoinWarSelector()
    if (modelJoinWarSelector:isRetrievingJoinableWarConfigurations()) then
        modelJoinWarSelector:updateWithJoinableWarConfigurations(action.warConfigurations)
    end
end

local function executeGetOngoingWarConfigurations(action, modelSceneMain)
    local modelContinueWarSelector = modelSceneMain:getModelMainMenu():getModelContinueWarSelector()
    if (modelContinueWarSelector:isRetrievingOngoingWarConfigurations()) then
        modelContinueWarSelector:updateWithOngoingWarConfigurations(action.warConfigurations)
    end
end

local function executeGetPlayerProfile(action, modelSceneMain)
    local modelGameRecordViewer = modelSceneMain:getModelMainMenu():getModelGameRecordViewer()
    if (modelGameRecordViewer:isRetrievingPlayerProfile()) then
        modelGameRecordViewer:updateWithPlayerProfile(action.playerProfile)
    end
end

local function executeGetRankingList(action, modelSceneMain)
    local modelGameRecordViewer = modelSceneMain:getModelMainMenu():getModelGameRecordViewer()
    if (modelGameRecordViewer:isRetrievingRankingList(action.rankingListIndex)) then
        modelGameRecordViewer:updateWithRankingList(action.rankingList, action.rankingListIndex)
    end
end

local function executeGetReplayConfigurations(action, modelSceneMain)
    local modelReplayManager = modelSceneMain:getModelMainMenu():getModelReplayManager()
    if (modelReplayManager:isRetrievingReplayConfigurations()) then
        modelReplayManager:updateWithReplayConfigurations(action.replayConfigurations, action.pageIndex)
    end
end

local function executeGetWaitingWarConfigurations(action, modelSceneMain)
    local modelExitWarSelector = modelSceneMain:getModelMainMenu():getModelExitWarSelector()
    if (modelExitWarSelector:isRetrievingWaitingWarConfigurations()) then
        modelExitWarSelector:updateWithWaitingWarConfigurations(action.warConfigurations)
    end
end

local function executeJoinWar(action, modelSceneMain)
    local warID = action.warID
    getModelMessageIndicator(modelSceneMain):showMessage(getLocalizedText(56, "JoinWarSuccessfully", AuxiliaryFunctions.getWarNameWithWarId(warID)))
        :showMessage(getLocalizedText(56, (action.isWarStarted) and ("JoinWarStarted") or ("JoinWarNotStarted")))
    local modelMainMenu        = modelSceneMain:getModelMainMenu()
    local modelJoinWarSelector = modelMainMenu:getModelJoinWarSelector()
    if (modelJoinWarSelector:isRetrievingJoinWarResult(warID)) then
        modelJoinWarSelector:setEnabled(false)
        modelMainMenu:setMenuEnabled(true)
    end
end

local function executeLogin(action, modelSceneMain)
    local account, password = action.loginAccount, action.loginPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        local modelMainMenu   = SingletonGetters.getModelMainMenu(modelSceneMain)
        local modelLoginPanel = modelMainMenu:getModelLoginPanel()
        if (not modelLoginPanel:isEnabled()) then
            runSceneMain(true)
        else
            modelLoginPanel:setEnabled(false)
            modelMainMenu:updateWithIsPlayerLoggedIn(true)
                :setMenuEnabled(true)
        end

        getModelMessageIndicator(modelSceneMain):showMessage(getLocalizedText(26, account))
    end
end

local function executeLogout(action)
    WebSocketManager.setLoggedInAccountAndPassword(nil, nil)
    runSceneMain(false, getLocalizedText(action.messageCode, unpack(action.messageParams or {})))
end

local function executeMessage(action, modelSceneMain)
    local message = getLocalizedText(action.messageCode, unpack(action.messageParams or {}))
    getModelMessageIndicator(modelSceneMain):showMessage(message)
end

local function executeNewWar(action, modelSceneMain)
    getModelMessageIndicator(modelSceneMain):showMessage(getLocalizedText(51, "NewWarCreated", AuxiliaryFunctions.getWarNameWithWarId(action.warID)))
    local modelMainMenu      = modelSceneMain:getModelMainMenu()
    local modelNewWarCreator = modelMainMenu:getModelNewWarCreator()
    if (modelNewWarCreator:isEnabled()) then
        modelNewWarCreator:setEnabled(false)
        modelMainMenu:setMenuEnabled(true)
    end
end

local function executeRegister(action, modelSceneMain)
    local account, password = action.registerAccount, action.registerPassword
    if (account ~= getLoggedInAccountAndPassword()) then
        WebSocketManager.setLoggedInAccountAndPassword(account, password)
        SerializationFunctions.serializeAccountAndPassword(account, password)

        local modelMainMenu   = modelSceneMain:getModelMainMenu()
        local modelLoginPanel = modelMainMenu:getModelLoginPanel()
        if (not modelLoginPanel:isEnabled()) then
            runSceneMain(true)
        else
            modelLoginPanel:setEnabled(false)
            modelMainMenu:updateWithIsPlayerLoggedIn(true)
                :setMenuEnabled(true)
        end

        getModelMessageIndicator(modelSceneMain):showMessage(getLocalizedText(27, account))
    end
end

local function executeRunSceneMain(action)
    local message = (action.messageCode) and (getLocalizedText(action.messageCode, unpack(action.messageParams or {}))) or (nil)
    runSceneMain(getLoggedInAccountAndPassword() ~= nil, message)
end

local function executeRunSceneWar(action, modelSceneMain)
    local modelContinueWarSelector = modelSceneMain:getModelMainMenu():getModelContinueWarSelector()
    if (modelContinueWarSelector:isRetrievingOngoingWarData()) then
        modelContinueWarSelector:updateWithOngoingWarData(action.warData)
    end
end

--------------------------------------------------------------------------------
-- The public function.
--------------------------------------------------------------------------------
function ActionExecutorForSceneMain.execute(action, modelSceneMain)
    local actionCode = action.actionCode
    assert(ActionCodeFunctions.getActionName(actionCode), "ActionExecutorForSceneMain.execute() invalid actionCode: " .. (actionCode or ""))

    if     (actionCode == ACTION_CODES.ActionChat)                         then executeChat(                        action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionDownloadReplayData)           then executeDownloadReplayData(          action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionExitWar)                      then executeExitWar(                     action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetJoinableWarConfigurations) then executeGetJoinableWarConfigurations(action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetOngoingWarConfigurations)  then executeGetOngoingWarConfigurations( action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetPlayerProfile)             then executeGetPlayerProfile(            action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetRankingList)               then executeGetRankingList(              action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetReplayConfigurations)      then executeGetReplayConfigurations(     action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionGetWaitingWarConfigurations)  then executeGetWaitingWarConfigurations( action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionJoinWar)                      then executeJoinWar(                     action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionLogin)                        then executeLogin(                       action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionLogout)                       then executeLogout(                      action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionMessage)                      then executeMessage(                     action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionNewWar)                       then executeNewWar(                      action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionRegister)                     then executeRegister(                    action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionRunSceneMain)                 then executeRunSceneMain(                action, modelSceneMain)
    elseif (actionCode == ACTION_CODES.ActionRunSceneWar)                  then executeRunSceneWar(                 action, modelSceneMain)
    end

    return ActionExecutorForSceneMain
end

return ActionExecutorForSceneMain
