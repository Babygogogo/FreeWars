
local ModelNewWarSelectorForNative = class("ModelNewWarSelectorForNative")

local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local NativeWarManager	  = requireFW("src.app.utilities.NativeWarManager")
local SingletonGetters	  = requireFW("src.app.utilities.SingletonGetters")
local WarFieldManager	   = requireFW("src.app.utilities.WarFieldManager")
local Actor				 = requireFW("src.global.actors.Actor")

local getLocalizedText = LocalizationFunctions.getLocalizedText
local ipairs		   = ipairs

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function getActorWarFieldPreviewer(self)
	if (not self.m_ActorWarFieldPreviewer) then
		local actor = Actor.createWithModelAndViewName("sceneMain.ModelWarFieldPreviewer", nil, "sceneMain.ViewWarFieldPreviewer")

		self.m_ActorWarFieldPreviewer = actor
		self.m_View:setViewWarFieldPreviewer(actor:getView())
	end

	return self.m_ActorWarFieldPreviewer
end

local function getActorWarConfiguratorForNative(self)
	if (not self.m_ActorWarConfiguratorForNative) then
		local model = Actor.createModel("sceneMain.ModelWarConfiguratorForNative")
		local view  = Actor.createView( "sceneMain.ViewWarConfiguratorForNative")

		model:setEnabled(false)
			:setCallbackOnButtonBackTouched(function()
				model:setEnabled(false)
				getActorWarFieldPreviewer(self):getModel():setEnabled(false)

				self.m_View:setMenuVisible(true)
					:setButtonNextVisible(false)
			end)

		self.m_ActorWarConfiguratorForNative = Actor.createWithModelAndViewInstance(model, view)
		self.m_View:setViewWarConfiguratorForNative(view)
	end

	return self.m_ActorWarConfiguratorForNative
end

local function createWarFieldList(self, listName)
	local list = {}
	for _, warFieldFileName in ipairs(WarFieldManager.getWarFieldFilenameList(listName)) do
		local data=WarFieldManager.getWarFieldData(warFieldFileName)
		if data then
			table.insert(list,{
				name=data.warFieldName,
				campaignScore=(listName == "Campaign") and (NativeWarManager.getCampaignHighScore(warFieldFileName)) or (nil),
				callback=function()
					self.m_WarFieldFileName = warFieldFileName
					self.m_WarFieldData=data
					getActorWarFieldPreviewer(self):getModel():setWarField(data)
						:setEnabled(true)
					self.m_View:setButtonNextVisible(true)
			end})
		end
	end

	return list
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelNewWarSelectorForNative:ctor(param)
	return self
end

--------------------------------------------------------------------------------
-- The callback function on start running.
--------------------------------------------------------------------------------
function ModelNewWarSelectorForNative:onStartRunning(modelSceneMain)
	self.m_ModelSceneMain = modelSceneMain
	getActorWarConfiguratorForNative(self):getModel():onStartRunning(modelSceneMain)

	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
--进入战役模式
function ModelNewWarSelectorForNative:setModeCampaign()
	getActorWarConfiguratorForNative(self):getModel():setModeCreateCampaign()
	if (self.m_View) then
		self.m_View:setMenuTitleText(getLocalizedText(1, "Campaign"))
			:removeAllItems()
			:showListWarField(createWarFieldList(self, "Campaign"))
	end

	return self
end

--进入自由模式
function ModelNewWarSelectorForNative:setModeFreeGame()
	getActorWarConfiguratorForNative(self):getModel():setModeCreateFreeGame()
	if (self.m_View) then
		self.m_View:setMenuTitleText(getLocalizedText(1, "Free Game"))
			:removeAllItems()
			:showListWarField(createWarFieldList(self, "SinglePlayerGame"))
	end
	return self
end

local writablePath=cc.FileUtils:getInstance():getWritablePath()
--进入剧情模式
function ModelNewWarSelectorForNative:setModeSenario()
	local filenameTable={}
	--扫描特定目录的剧情文件
	os.execute('ls '..writablePath..'data/downloadMaps >tmpfile')
	local lines=io.lines('tmpfile')
	os.execute('rm tmpfile')
	--根据lines生成地图名列表
	for filename in lines do
		local data=WarFieldManager.getWarFieldData(filename)
		if data then
			table.insert(filenameTable,{name=data.warFieldName,campaignScore=nil,callback=function()
				self.m_WarFieldFileName = filename
				self.m_WarFieldData=data
				getActorWarFieldPreviewer(self):getModel():setWarField(data)
					:setEnabled(true)
				self.m_View:setButtonNextVisible(true)
			end})
		end
	end
	getActorWarConfiguratorForNative(self):getModel():setModeCreateFreeGame()
	if (self.m_View) then
		self.m_View:setMenuTitleText('剧情模式')
			:removeAllItems()
			:showListWarField(filenameTable)
	end
	return self
end

function ModelNewWarSelectorForNative:isEnabled()
	return self.m_IsEnabled
end

function ModelNewWarSelectorForNative:setEnabled(enabled)
	self.m_IsEnabled = enabled
	getActorWarFieldPreviewer(self):getModel():setEnabled(false)
	getActorWarConfiguratorForNative(self):getModel():setEnabled(false)

	if (self.m_View) then
		self.m_View:setVisible(enabled)
			:setButtonNextVisible(false)
			:setMenuVisible(true)
	end

	return self
end

function ModelNewWarSelectorForNative:onButtonBackTouched()
	self:setEnabled(false)
	SingletonGetters.getModelMainMenu(self.m_ModelSceneMain):setMenuEnabled(true)

	return self
end

function ModelNewWarSelectorForNative:onButtonNextTouched()
	getActorWarFieldPreviewer(self):getModel():setEnabled(false)
	getActorWarConfiguratorForNative(self):getModel():resetWithWarConfiguration({
		warFieldFileName = self.m_WarFieldFileName,
		warFieldData = self.m_WarFieldData
		}):setEnabled(true)

	self.m_View:setMenuVisible(false)
		:setButtonNextVisible(false)

	return self
end

return ModelNewWarSelectorForNative
