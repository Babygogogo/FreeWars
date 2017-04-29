
local ActionCodeFunctions = {}

local TableFunctions = requireFW("src.app.utilities.TableFunctions")

local assert = assert

local s_ActionCodes = {
    ActionChat                         = 1,
    ActionDownloadReplayData           = 2,
    ActionExitWar                      = 3,
    ActionGetJoinableWarConfigurations = 4,
    ActionGetOngoingWarConfigurations  = 5,
    ActionGetPlayerProfile             = 6,
    ActionGetRankingList               = 7,
    ActionGetReplayConfigurations      = 8,
    ActionGetWaitingWarConfigurations  = 9,
    ActionJoinWar                      = 10,
    ActionLogin                        = 11,
    ActionLogout                       = 12,
    ActionMessage                      = 13,
    ActionNetworkHeartbeat             = 14,
    ActionNewWar                       = 15,
    ActionRegister                     = 16,
    ActionReloadSceneWar               = 17,
    ActionRunSceneMain                 = 18,
    ActionRunSceneWar                  = 19,
    ActionSyncSceneWar                 = 21,

    ActionActivateSkill                = 100,
    ActionAttack                       = 101,
    ActionBeginTurn                    = 102,
    ActionBuildModelTile               = 103,
    ActionCaptureModelTile             = 104,
    ActionDestroyOwnedModelUnit        = 105,
    ActionDive                         = 106,
    ActionDropModelUnit                = 107,
    ActionEndTurn                      = 108,
    ActionJoinModelUnit                = 109,
    ActionLaunchFlare                  = 110,
    ActionLaunchSilo                   = 111,
    ActionLoadModelUnit                = 112,
    ActionProduceModelUnitOnTile       = 113,
    ActionProduceModelUnitOnUnit       = 114,
    ActionResearchPassiveSkill         = 115,
    ActionSupplyModelUnit              = 116,
    ActionSurface                      = 117,
    ActionSurrender                    = 118,
    ActionUpdateReserveSkills          = 119,
    ActionVoteForDraw                  = 120,
    ActionWait                         = 121,
}
local s_ActionNames

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ActionCodeFunctions.getActionCode(actionName)
    local code = s_ActionCodes[actionName]
    assert(code, "ActionCodeFunctions.getActionCode() invalid actionName: " .. (actionName or ""))
    return code
end

function ActionCodeFunctions.getActionName(actionCode)
    if (not s_ActionNames) then
        s_ActionNames = {}
        for name, code in pairs(s_ActionCodes) do
            s_ActionNames[code] = name
        end
    end

    local name = s_ActionNames[actionCode]
    assert(name, "ActionCodeFunctions.getActionName() invalid actionCode: " .. (actionCode or ""))
    return name
end

function ActionCodeFunctions.getFullList()
    return TableFunctions.clone(s_ActionCodes)
end

return ActionCodeFunctions
