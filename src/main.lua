
--[[--------------------------------------------------------------------------------
-- main.lua是lua程序的入口，在程序运行时被引擎自动调用。
--
-- 主要职责：
--   读取游戏资源文件
--   运行主场景
--
-- 使用场景举例：
--   只在程序运行时被引擎调用，不应该自行调用本文件。
--
-- 其他：
--   - 这个文件用到了游戏引擎的功能，因此服务器上的程序需要另写一个入口函数。
--]]--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- The global variables.
--------------------------------------------------------------------------------
requireFW = require

__G__TRACKBACK__ = function(msg)
	local msg = debug.traceback(msg, 3)
	print(msg)

	local scene = display.getRunningScene()
	if (scene ~= nil) then
		scene:addChild(requireFW("app.views.common.ViewErrorIndicator"):create(msg), 999)
	end

	return msg
end

--------------------------------------------------------------------------------
-- The app initializers.
--------------------------------------------------------------------------------
local fileUtils = cc.FileUtils:getInstance()
fileUtils:setPopupNotify(false)
fileUtils:addSearchPath("src/")
fileUtils:addSearchPath("res/")

require "config"
require "cocos.init"

local function main()
	print('正在读取plist文件')
	display.loadSpriteFrames("FreeWarsTextureTile.plist","FreeWarsTextureTile.pvr.ccz")
	display.loadSpriteFrames("FreeWarsTextureUnit.plist","FreeWarsTextureUnit.pvr.ccz")
	display.loadSpriteFrames("FreeWarsTextureUI.plist","FreeWarsTextureUI.pvr.ccz")
	display.loadSpriteFrames("FreeWarsTextureGallery.plist","FreeWarsTextureGallery.pvr.ccz")
	print('正在启动工具模块')
	requireFW("src.app.utilities.AnimationLoader").load()
	requireFW("src.app.utilities.GameConstantFunctions").init()
	requireFW("src.app.utilities.SerializationFunctions").init()
	requireFW("src.app.utilities.NativeWarManager").init()
	math.randomseed(os.time())

	cc.Director:getInstance():setDisplayStats(true)
	local actor=requireFW("src.global.actors.Actor")
	--启动主界面
	local actorSceneMain = actor.createWithModelAndViewName("sceneMain.ModelSceneMain", nil, "sceneMain.ViewSceneMain")
	requireFW("src.global.actors.ActorManager").setAndRunRootActor(actorSceneMain)
	--消息指示器
	local indicator=actorSceneMain:getModel():getModelMessageIndicator()
	indicator:showMessage(requireFW("src.app.utilities.LocalizationFunctions").getLocalizedText(30, "StartConnecting"))
	requireFW("src.app.utilities.WebSocketManager").init()--初始化网络
	--给战场管理器设置指示器
	local wfManager=requireFW("src.app.utilities.WarFieldManager")
	wfManager.indicator=indicator
	--让下载器准备进行热更新
	local downloader=requireFW("src.global.functions.download")
	downloader.indicator=indicator
	downloader.httpDownload('localhost:1024/','./')
end

local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
	print(msg)
end
