--战场管理器
local writablePath=cc.FileUtils:getInstance():getWritablePath()
local WarFieldManager = {}

local WAR_FIELD_FILENAME_LISTS = requireFW('res.data.templateWarField.WarFieldFilenameLists')

--显示消息(消息内容),这个函数需要依赖Babygogogo少年写的东西
local function showMessage(message)
	if WarFieldManager.indicator then WarFieldManager.indicator:showMessage(message) end
end

--加载地图的过程
local function loadMap(name,showIfError)
	local func,err=loadfile(name)--使用lua的loadfile来加载,返回函数和错误信息
	if type(func)=='function' then--如果加载成功则执行一遍地图代码(可以在地图代码里下毒)
		return func()
	elseif not func then--执行不成功时候,提示错误信息
		if showIfError then showMessage(err) end
	end
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function WarFieldManager.isRandomWarField(warFieldFilename)
	return (string.find(warFieldFilename, "Random", 1, true) == 1)
end

function WarFieldManager.getWarFieldData(warFieldFilename)
	print(debug.traceback())
	print('调用WarFieldManager.getWarFieldData('..warFieldFilename..')')
	--加载DLC地图文件
	local dlcMapFullName=writablePath.. 'data/downloadMaps/' .. warFieldFilename
	package.loaded[dlcMapFullName]=nil--这样的话可以让lua强行加载一遍
	local warField=loadMap(dlcMapFullName)
	--加载默认地图文件(如果DLC没有的话)
	if not warField then
		warField=loadMap('Resources/res/data/templateWarField/'..warFieldFilename..'.lua',true)
	end
	return warField
end

function WarFieldManager.getWarFieldFilenameList(listName)
	return WAR_FIELD_FILENAME_LISTS[listName]
end

function WarFieldManager.getWarFieldName(warFieldFilename)
	local warField=WarFieldManager.getWarFieldData(warFieldFilename)
	if warField then
		return warField.warFieldName
	else
		return '????'
	end
end

function WarFieldManager.getWarFieldAuthorName(warFieldFilename)
	local warField=WarFieldManager.getWarFieldData(warFieldFilename)
	if warField then
		return warField.authorName
	else
		return '????'
	end
end

function WarFieldManager.getPlayersCount(warFieldFilename)
	local warField=WarFieldManager.getWarFieldData(warFieldFilename)
	if warField then
		return warField.playersCount
	else
		return 0
	end
end

function WarFieldManager.getMapSize(warFieldFilename)
	local data = WarFieldManager.getWarFieldData(warFieldFilename)
	if data then
		return {width = data.width, height = data.height}
	end
end

return WarFieldManager
