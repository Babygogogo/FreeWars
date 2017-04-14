
local WarFieldManager = {}

local WAR_FIELD_PATH           = "res.data.templateWarField."
local WAR_FIELD_FILENAME_LISTS = requireFW(WAR_FIELD_PATH .. "WarFieldFilenameLists")
local IS_SERVER                = requireFW("src.app.utilities.GameConstantFunctions").isServer()

local string, pairs, ipairs, require, assert = string, pairs, ipairs, require, assert
local math                                   = math

local s_IsInitialized          = false
local s_WarFieldList
local s_WarFieldListDeprecated = {}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function createWarFieldList()
    local list = {}
    for categoryName, subList in pairs(WAR_FIELD_FILENAME_LISTS) do
        if ((not IS_SERVER)                                                          or
            ((categoryName ~= "Campaign") and (categoryName ~= "SinglePlayerGame"))) then
            assert(#subList > 0)
            for _, warFieldFilename in pairs(subList) do
                list[warFieldFilename] = list[warFieldFilename] or requireFW(WAR_FIELD_PATH .. warFieldFilename)
            end
        end
    end

    return list
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function WarFieldManager.init()
    if (not s_IsInitialized) then
        s_IsInitialized = true

        s_WarFieldList = createWarFieldList()
    end

    return WarFieldManager
end

function WarFieldManager.isRandomWarField(warFieldFilename)
    return (string.find(warFieldFilename, "Random", 1, true) == 1)
end

function WarFieldManager.getRandomWarFieldFilename(warFieldFilename)
    local list = WAR_FIELD_FILENAME_LISTS[warFieldFilename]
    return list[math.random(#list)]
end

function WarFieldManager.getWarFieldData(warFieldFilename)
    assert(s_IsInitialized, "WarFieldManager.getWarFieldData() the manager has not been initialized yet.")
    if (s_WarFieldList[warFieldFilename]) then
        return s_WarFieldList[warFieldFilename]
    else
        if (not s_WarFieldListDeprecated[warFieldFilename]) then
            s_WarFieldListDeprecated[warFieldFilename] = requireFW(WAR_FIELD_PATH .. warFieldFilename)
        end
        return s_WarFieldListDeprecated[warFieldFilename]
    end
end

function WarFieldManager.getWarFieldFilenameList(listName)
    local list = WAR_FIELD_FILENAME_LISTS[listName]
    assert(list, "WarFieldManager.getWarFieldFilenameList() the list doesn't exist.")

    return list
end

function WarFieldManager.getWarFieldName(warFieldFilename)
    return WarFieldManager.getWarFieldData(warFieldFilename).warFieldName
end

function WarFieldManager.getWarFieldAuthorName(warFieldFilename)
    return WarFieldManager.getWarFieldData(warFieldFilename).authorName
end

function WarFieldManager.getPlayersCount(warFieldFilename)
    return WarFieldManager.getWarFieldData(warFieldFilename).playersCount
end

function WarFieldManager.getMapSize(warFieldFilename)
    local data = WarFieldManager.getWarFieldData(warFieldFilename)
    return {width = data.width, height = data.height}
end

return WarFieldManager
