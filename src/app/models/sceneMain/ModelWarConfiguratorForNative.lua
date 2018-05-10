
local ModelWarConfiguratorForNative = class("ModelWarConfiguratorForNative")

local Actor				 = requireFW("src.global.actors.Actor")
local ActorManager		  = requireFW("src.global.actors.ActorManager")
local ActionCodeFunctions   = requireFW("src.app.utilities.ActionCodeFunctions")
local AuxiliaryFunctions	= requireFW("src.app.utilities.AuxiliaryFunctions")
local LocalizationFunctions = requireFW("src.app.utilities.LocalizationFunctions")
local SingletonGetters	  = requireFW("src.app.utilities.SingletonGetters")
local NativeWarManager	  = requireFW("src.app.utilities.NativeWarManager")
local WarFieldManager	   = requireFW("src.app.utilities.WarFieldManager")
local WebSocketManager	  = requireFW("src.app.utilities.WebSocketManager")

local string		   = string
local pairs			= pairs
local getLocalizedText = LocalizationFunctions.getLocalizedText

local ACTION_CODE_NEW_WAR	   = ActionCodeFunctions.getActionCode("ActionNewWar")
local ACTION_CODE_RUN_SCENE_WAR = ActionCodeFunctions.getActionCode("ActionRunSceneWar")
local ENERGY_GAIN_MODIFIERS	 = {0, 50, 100, 150, 200, 300, 500}
local INCOME_MODIFIERS		  = {0, 50, 100, 150, 200, 300, 500}
local STARTING_ENERGIES		 = {0, 10000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 90000, 100000}
local STARTING_FUNDS			= {0, 5000, 10000, 20000, 30000, 40000, 50000, 100000, 150000, 200000, 300000, 400000, 500000}

--------------------------------------------------------------------------------
-- The util functions.
--------------------------------------------------------------------------------
local function generatePlayerColorText(playerIndex)
	if	 (playerIndex == 1) then return string.format("1 (%s)", getLocalizedText(34, "Red"))
	elseif (playerIndex == 2) then return string.format("2 (%s)", getLocalizedText(34, "Blue"))
	elseif (playerIndex == 3) then return string.format("3 (%s)", getLocalizedText(34, "Yellow"))
	elseif (playerIndex == 4) then return string.format("4 (%s)", getLocalizedText(34, "Black"))
	else						   error("ModelWarConfiguratorForNative-generatePlayerColorText() invalid playerIndex: " .. (playerIndex or ""))
	end
end

local function getPlayerIndexForWarConfiguration(warConfiguration)
	for playerIndex, player in pairs(warConfiguration.players) do
		if (player.account == "Player") then
			return playerIndex
		end
	end

	error("ModelWarConfiguratorForNative-getPlayerIndexForWarConfiguration() failed to find the playerIndex.")
end

--------------------------------------------------------------------------------
-- The overview text generators.
--------------------------------------------------------------------------------
local function generateTextForStartingFund(startingFund)
	if (startingFund == 0) then
		return nil
	else
		return string.format("%s:		 %d", getLocalizedText(14, "StartingFund"), startingFund)
	end
end

local function generateTextForIncomeModifier(incomeModifier)
	if (incomeModifier == 100) then
		return nil
	else
		return string.format("%s:		 %d%%", getLocalizedText(14, "IncomeModifier"), incomeModifier)
	end
end

local function generateTextForStartingEnergy(startingEnergy)
	if (startingEnergy == 0) then
		return nil
	else
		return string.format("%s:		 %d", getLocalizedText(14, "StartingEnergy"), startingEnergy)
	end
end

local function generateTextForEnergyModifier(energyGainModifier)
	if (energyGainModifier == 100) then
		return nil
	else
		return string.format("%s:		 %d%%", getLocalizedText(14, "EnergyGainModifier"), energyGainModifier)
	end
end

local function generateTextForEnablePassiveSkill(isPassiveSkillEnabled)
	if (isPassiveSkillEnabled) then
		return nil
	else
		return string.format("%s:	 %s", getLocalizedText(14, "EnablePassiveSkill"), getLocalizedText(14, (isPassiveSkillEnabled) and ("Yes") or ("No")))
	end
end

local function generateTextForEnableActiveSkill(isActiveSkillEnabled)
	if (isActiveSkillEnabled) then
		return nil
	else
		return string.format("%s:	 %s", getLocalizedText(14, "EnableActiveSkill"), getLocalizedText(14, (isActiveSkillEnabled) and ("Yes") or ("No")))
	end
end

local function generateTextForMoveRangeModifier(moveRangeModifier)
	if (moveRangeModifier == 0) then
		return nil
	else
		return string.format("%s:	 %d", getLocalizedText(14, "MoveRangeModifier"), moveRangeModifier)
	end
end

local function generateTextForAttackModifier(attackModifier)
	if (attackModifier == 0) then
		return nil
	else
		return string.format("%s:	 %d%%", getLocalizedText(14, "AttackModifier"), attackModifier)
	end
end

local function generateTextForVisionModifier(visionModifier)
	if (visionModifier == 0) then
		return nil
	else
		return string.format("%s:		 %d", getLocalizedText(14, "VisionModifier"), visionModifier)
	end
end

local function generateTextForAdvancedSettings(self)
	local textList = {getLocalizedText(14, "Advanced Settings") .. ":"}
	textList[#textList + 1] = generateTextForStartingFund(	  self.m_StartingFund)
	textList[#textList + 1] = generateTextForIncomeModifier(	self.m_IncomeModifier)
	textList[#textList + 1] = generateTextForStartingEnergy(	self.m_StartingEnergy)
	textList[#textList + 1] = generateTextForEnergyModifier(	self.m_EnergyGainModifier)
	textList[#textList + 1] = generateTextForEnablePassiveSkill(self.m_IsPassiveSkillEnabled)
	textList[#textList + 1] = generateTextForEnableActiveSkill( self.m_IsActiveSkillEnabled)
	textList[#textList + 1] = generateTextForMoveRangeModifier( self.m_MoveRangeModifier)
	textList[#textList + 1] = generateTextForAttackModifier(	self.m_AttackModifier)
	textList[#textList + 1] = generateTextForVisionModifier(	self.m_VisionModifier)

	if (#textList == 1) then
		textList[#textList + 1] = getLocalizedText(14, "None")
	end
	return table.concat(textList, "\n")
end

local function generateOverviewText(self)
	return string.format("%s:\n\n%s:%s%s\n%s:%s%s (%s: %s)\n%s:%s%s\n\n%s",
		getLocalizedText(14, "Overview"),
		getLocalizedText(14, "WarFieldName"),	  "		 ",	 WarFieldManager.getWarFieldName(self.m_WarConfiguration.warFieldFileName),
		getLocalizedText(14, "PlayerIndex"),	   "		 ",	 generatePlayerColorText(self.m_PlayerIndex),
		getLocalizedText(14, "TeamIndex"),						  AuxiliaryFunctions.getTeamNameWithTeamIndex(self.m_TeamIndex),
		getLocalizedText(14, "FogOfWar"),		  "		 ",	 getLocalizedText(14, (self.m_IsFogOfWarByDefault) and ("Yes") or ("No")),
		generateTextForAdvancedSettings(self)
	)
end

--------------------------------------------------------------------------------
-- The dynamic item generators.
--------------------------------------------------------------------------------
local function createItemsForStateMain(self)
	local mode = self.m_Mode
	if (mode == "modeCreateCampaign") then
		return {self.m_ItemPlaceHolder}

	elseif (mode == "modeCreateFreeGame") then
		return {
			self.m_ItemPlayerIndex,
			self.m_ItemFogOfWar,
			self.m_ItemAdvancedSettings,
		}

	elseif (mode == "modeContinue") then
		return {self.m_ItemPlaceHolder}

	else
		error("ModelWarConfiguratorForNative-createItemsForStateMain() the mode of the configurator is invalid: " .. (mode or ""))
	end
end

local setStateMain

local function createItemsForStatePlayerIndex(self)
	local warConfiguration = self.m_WarConfiguration
	local players			  = warConfiguration.players
	local items				= {}

	for playerIndex = 1, WarFieldManager.getPlayersCount(warConfiguration.warFieldFileName) do
		if ((not players) or (not players[playerIndex])) then
			items[#items + 1] = {
				playerIndex = playerIndex,
				name		= generatePlayerColorText(playerIndex),
				callback	= function()
					self.m_PlayerIndex = playerIndex
					setStateMain(self)
				end,
			}
		end
	end

	assert(#items > 0)
	return items
end

--------------------------------------------------------------------------------
-- The functions for sending actions.
--------------------------------------------------------------------------------
local function createAndEnterWar(self)
	local warData = NativeWarManager.createInitialWarData({
		attackModifier			= self.m_AttackModifier,
		energyGainModifier		= self.m_EnergyGainModifier,
		incomeModifier			= self.m_IncomeModifier,
		isActiveSkillEnabled	  = self.m_IsActiveSkillEnabled,
		isCampaign				= self.m_Mode == "modeCreateCampaign",
		isPassiveSkillEnabled	 = self.m_IsPassiveSkillEnabled,
		isFogOfWarByDefault	   = self.m_IsFogOfWarByDefault,
		moveRangeModifier		 = self.m_MoveRangeModifier,
		playerIndex			   = self.m_PlayerIndex,
		startingEnergy			= self.m_StartingEnergy,
		startingFund			  = self.m_StartingFund,
		teamIndex				 = self.m_TeamIndex,
		visionModifier			= self.m_VisionModifier,
		warFieldFileName=self.m_WarConfiguration.warFieldFileName,
		warFieldData	=self.m_WarConfiguration.warFieldData
	})
	local actorWarNative = Actor.createWithModelAndViewName("warNative.ModelWarNative", warData, "common.ViewSceneWar")
	ActorManager.setAndRunRootActor(actorWarNative, "FADE", 1)
end

local function loadAndEnterWar(saveIndex)
	local warData		= NativeWarManager.loadWarData(saveIndex)
	warData.warFieldData=WarFieldManager.getWarFieldData(warData.warFieldFileName)
	local actorWarNative = Actor.createWithModelAndViewName("warNative.ModelWarNative", warData, "common.ViewSceneWar")
	ActorManager.setAndRunRootActor(actorWarNative, "FADE", 1)
end

--------------------------------------------------------------------------------
-- The state setters.
--------------------------------------------------------------------------------
local function setStateAdvancedSettings(self)
	self.m_State = "stateAdvancedSettings"
	self.m_View:setMenuTitleText(getLocalizedText(14, "Advanced Settings"))
		:setItems(self.m_ItemsForStateAdvancedSettings)
		:setOverviewText(generateOverviewText(self))
end

local function setStateAttackModifier(self)
	self.m_State = "stateAttackModifier"
	self.m_View:setMenuTitleText(getLocalizedText(14, "AttackModifier"))
		:setItems(self.m_ItemsForStateAttackModifier)
		:setOverviewText(getLocalizedText(35, "HelpForAttackModifier"))
end

local function setStateEnableActiveSkill(self)
	self.m_State = "stateEnableActiveSkill"
	self.m_View:setMenuTitleText(getLocalizedText(14, "EnableActiveSkill"))
		:setItems(self.m_ItemsForStateEnableActiveSkill)
		:setOverviewText(getLocalizedText(35, "HelpForEnableActiveSkill"))
end

local function setStateEnablePassiveSkill(self)
	self.m_State = "stateEnablePassiveSkill"
	self.m_View:setMenuTitleText(getLocalizedText(14, "EnablePassiveSkill"))
		:setItems(self.m_ItemsForStateEnablePassiveSkill)
		:setOverviewText(getLocalizedText(35, "HelpForEnablePassiveSkill"))
end

local function setStateEnergyGainModifier(self)
	self.m_State = "stateEnergyModifier"
	self.m_View:setMenuTitleText(getLocalizedText(14, "Energy Gain Modifier"))
		:setItems(self.m_ItemsForStateEnergyGainModifier)
		:setOverviewText(getLocalizedText(35, "HelpForEnergyGainModifier"))
end

local function setStateFogOfWar(self)
	self.m_State = "stateFogOfWar"
	self.m_View:setMenuTitleText(getLocalizedText(34, "FogOfWar"))
		:setItems(self.m_ItemsForStateFogOfWar)
		:setOverviewText(getLocalizedText(35, "HelpForFogOfWar"))
end

local function setStateIncomeModifier(self)
	self.m_State = "stateIncomeModifier"
	self.m_View:setMenuTitleText(getLocalizedText(14, "Income Modifier"))
		:setItems(self.m_ItemsForStateIncomeModifier)
		:setOverviewText(getLocalizedText(35, "HelpForIncomeModifier"))
end

setStateMain = function(self)
	self.m_State = "stateMain"
	self.m_View:setMenuTitleText(self.m_MenuTitleTextForMode)
		:setItems(createItemsForStateMain(self))
		:setOverviewText(generateOverviewText(self))
end

local function setStateMoveRangeModifier(self)
	self.m_State = "stateMoveRangeModifier"
	self.m_View:setMenuTitleText(getLocalizedText(14, "MoveRangeModifier"))
		:setItems(self.m_ItemsForStateMoveRangeModifier)
		:setOverviewText(getLocalizedText(35, "HelpForMoveRangeModifier"))
end

local function setStatePlayerIndex(self)
	self.m_State = "statePlayerIndex"
	self.m_View:setMenuTitleText(getLocalizedText(34, "PlayerIndex"))
		:setItems(self.m_ItemsForStatePlayerIndex)
		:setOverviewText(getLocalizedText(35, "HelpForPlayerIndex"))
end

local function setStateStartingEnergy(self)
	self.m_State = "stateStartingEnergy"
	self.m_View:setMenuTitleText(getLocalizedText(14, "Starting Energy"))
		:setItems(self.m_ItemsForStateStartingEnergy)
		:setOverviewText(getLocalizedText(35, "HelpForStartingEnergy"))
end

local function setStateStartingFund(self)
	self.m_State = "stateStartingFund"
	self.m_View:setMenuTitleText(getLocalizedText(14, "Starting Fund"))
		:setItems(self.m_ItemsForStateStartingFund)
		:setOverviewText(getLocalizedText(35, "HelpForStartingFund"))
end

local function setStateVisionModifier(self)
	self.m_State = "stateVisionModifier"
	self.m_View:setMenuTitleText(getLocalizedText(14, "VisionModifier"))
		:setItems(self.m_ItemsForStateVisionModifier)
		:setOverviewText(getLocalizedText(35, "HelpForVisionModifier"))
end

--------------------------------------------------------------------------------
-- The composition elements.
--------------------------------------------------------------------------------
local function initItemAdvancedSettings(self)
	self.m_ItemAdvancedSettings = {
		name	 = getLocalizedText(14, "Advanced Settings"),
		callback = function()
			setStateAdvancedSettings(self)
		end,
	}
end

local function initItemAttackModifier(self)
	self.m_ItemAttackModifier = {
		name	 = getLocalizedText(14, "AttackModifier"),
		callback = function()
			setStateAttackModifier(self)
		end,
	}
end

local function initItemEnableActiveSkill(self)
	self.m_ItemEnableActiveSkill = {
		name	 = getLocalizedText(14, "EnableActiveSkill"),
		callback = function()
			setStateEnableActiveSkill(self)
		end,
	}
end

local function initItemEnablePassiveSkill(self)
	self.m_ItemEnablePassiveSkill = {
		name	 = getLocalizedText(14, "EnablePassiveSkill"),
		callback = function()
			setStateEnablePassiveSkill(self)
		end,
	}
end

local function initItemEnergyGainModifier(self)
	self.m_ItemEnergyModifier = {
		name	 = getLocalizedText(14, "Energy Gain Modifier"),
		callback = function()
			setStateEnergyGainModifier(self)
		end,
	}
end

local function initItemFogOfWar(self)
	self.m_ItemFogOfWar = {
		name	 = getLocalizedText(34, "FogOfWar"),
		callback = function()
			setStateFogOfWar(self)
		end,
	}
end

local function initItemIncomeModifier(self)
	self.m_ItemIncomeModifier = {
		name	 = getLocalizedText(14, "Income Modifier"),
		callback = function()
			setStateIncomeModifier(self)
		end,
	}
end

local function initItemMoveRangeModifier(self)
	self.m_ItemMoveRangeModifier = {
		name	 = getLocalizedText(14, "MoveRangeModifier"),
		callback = function()
			setStateMoveRangeModifier(self)
		end,
	}
end

local function initItemPlayerIndex(self)
	self.m_ItemPlayerIndex = {
		name	 = getLocalizedText(34, "PlayerIndex"),
		callback = function()
			setStatePlayerIndex(self)
		end,
	}
end

local function initItemPlaceHolder(self)
	self.m_ItemPlaceHolder = {
		name	 = "(" .. getLocalizedText(14, "NoAvailableOption") .. ")",
		callback = function()
		end,
	}
end

local function initItemStartingEnergy(self)
	self.m_ItemStartingEnergy = {
		name	 = getLocalizedText(14, "Starting Energy"),
		callback = function()
			setStateStartingEnergy(self)
		end,
	}
end

local function initItemStartingFund(self)
	self.m_ItemStartingFund = {
		name	 = getLocalizedText(14, "Starting Fund"),
		callback = function()
			setStateStartingFund(self)
		end,
	}
end

local function initItemVisionModifier(self)
	self.m_ItemVisionModifier = {
		name	 = getLocalizedText(14, "VisionModifier"),
		callback = function()
			setStateVisionModifier(self)
		end,
	}
end

local function initItemsForStateAdvancedSettings(self)
	self.m_ItemsForStateAdvancedSettings = {
		self.m_ItemStartingFund,
		self.m_ItemIncomeModifier,
		self.m_ItemStartingEnergy,
		self.m_ItemEnergyModifier,
		self.m_ItemEnablePassiveSkill,
		self.m_ItemEnableActiveSkill,
		self.m_ItemMoveRangeModifier,
		self.m_ItemAttackModifier,
		self.m_ItemVisionModifier,
	}
end

local function initItemsForStateAttackModifier(self)
	local items = {}
	for modifier = 30, -30, -30 do
		items[#items + 1] = {
			name	 = "" .. modifier .. "%",
			callback = function()
				self.m_AttackModifier = modifier
				setStateMain(self)
			end,
		}
	end

	self.m_ItemsForStateAttackModifier = items
end

local function initItemsForStateEnableActiveSkill(self)
	self.m_ItemsForStateEnableActiveSkill = {
		{
			name	 = getLocalizedText(14, "Yes"),
			callback = function()
				self.m_IsActiveSkillEnabled = true
				setStateMain(self)
			end,
		},
		{
			name	 = getLocalizedText(14, "No"),
			callback = function()
				self.m_IsActiveSkillEnabled = false
				setStateMain(self)
			end,
		}
	}
end

local function initItemsForStateEnablePassiveSkill(self)
	self.m_ItemsForStateEnablePassiveSkill = {
		{
			name	 = getLocalizedText(14, "Yes"),
			callback = function()
				self.m_IsPassiveSkillEnabled = true
				setStateMain(self)
			end,
		},
		{
			name	 = getLocalizedText(14, "No"),
			callback = function()
				self.m_IsPassiveSkillEnabled = false
				setStateMain(self)
			end,
		}
	}
end

local function initItemsForStateEnergyGainModifier(self)
	local items = {}
	for _, modifier in ipairs(ENERGY_GAIN_MODIFIERS) do
		items[#items + 1] = {
			name	 = (modifier ~= 100) and (string.format("%d%%", modifier)) or (string.format("%d%%(%s)", modifier, getLocalizedText(14, "Default"))),
			callback = function()
				self.m_EnergyGainModifier = modifier
				setStateMain(self)
			end,
		}
	end

	self.m_ItemsForStateEnergyGainModifier = items
end

local function initItemsForStateFogOfWar(self)
	self.m_ItemsForStateFogOfWar = {
		{
			name	 = getLocalizedText(14, "No"),
			callback = function()
				self.m_IsFogOfWarByDefault = false

				setStateMain(self)
			end,
		},
		{
			name	 = getLocalizedText(14, "Yes"),
			callback = function()
				self.m_IsFogOfWarByDefault = true

				setStateMain(self)
			end,
		},
	}
end

local function initItemsForStateIncomeModifier(self)
	local items = {}
	for _, modifier in ipairs(INCOME_MODIFIERS) do
		items[#items + 1] = {
			name	 = (modifier ~= 100) and (string.format("%d%%", modifier)) or (string.format("%d%%(%s)", modifier, getLocalizedText(14, "Default"))),
			callback = function()
				self.m_IncomeModifier = modifier
				setStateMain(self)
			end,
		}
	end

	self.m_ItemsForStateIncomeModifier = items
end

local function initItemsForStateMoveRangeModifier(self)
	local items = {}
	for modifier = 1, -1, -1 do
		items[#items + 1] = {
			name	 = "" .. modifier,
			callback = function()
				self.m_MoveRangeModifier = modifier
				setStateMain(self)
			end,
		}
	end

	self.m_ItemsForStateMoveRangeModifier = items
end

local function initItemsForStateStartingEnergy(self)
	local items = {}
	for _, energy in ipairs(STARTING_ENERGIES) do
		items[#items + 1] = {
			name	 = (energy ~= 0) and ("" .. energy) or (string.format("%d(%s)", energy, getLocalizedText(14, "Default"))),
			callback = function()
				self.m_StartingEnergy = energy
				setStateMain(self)
			end
		}
	end

	self.m_ItemsForStateStartingEnergy = items
end

local function initItemsForStateStartingFund(self)
	local items = {}
	for _, fund in ipairs(STARTING_FUNDS) do
		items[#items + 1] = {
			name	 = (fund ~= 0) and ("" .. fund) or (string.format("%d(%s)", fund, getLocalizedText(14, "Default"))),
			callback = function()
				self.m_StartingFund = fund
				setStateMain(self)
			end
		}
	end

	self.m_ItemsForStateStartingFund = items
end

local function initItemsForStateVisionModifier(self)
	local items = {}
	for modifier = 1, -1, -1 do
		items[#items + 1] = {
			name	 = "" .. modifier,
			callback = function()
				self.m_VisionModifier = modifier
				setStateMain(self)
			end
		}
	end

	self.m_ItemsForStateVisionModifier = items
end

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelWarConfiguratorForNative:ctor()
	initItemAdvancedSettings(	  self)
	initItemAttackModifier(		self)
	initItemEnableActiveSkill(	 self)
	initItemEnablePassiveSkill(	self)
	initItemEnergyGainModifier(	self)
	initItemFogOfWar(			  self)
	initItemIncomeModifier(		self)
	initItemMoveRangeModifier(	 self)
	initItemPlayerIndex(		   self)
	initItemPlaceHolder(		   self)
	initItemStartingEnergy(		self)
	initItemStartingFund(		  self)
	initItemVisionModifier(		self)

	initItemsForStateAdvancedSettings(	  self)
	initItemsForStateAttackModifier(		self)
	initItemsForStateEnableActiveSkill(	 self)
	initItemsForStateEnablePassiveSkill(	self)
	initItemsForStateEnergyGainModifier(	self)
	initItemsForStateFogOfWar(			  self)
	initItemsForStateIncomeModifier(		self)
	initItemsForStateMoveRangeModifier(	 self)
	initItemsForStateStartingEnergy(		self)
	initItemsForStateStartingFund(		  self)
	initItemsForStateVisionModifier(		self)

	return self
end

function ModelWarConfiguratorForNative:setCallbackOnButtonBackTouched(callback)
	self.m_OnButtonBackTouched = callback

	return self
end

--设定确认按钮,进入战场
function ModelWarConfiguratorForNative:setConfirmBox()
	self.m_CallbackOnButtonConfirmTouched = function()
		local modelConfirmBox = SingletonGetters.getModelConfirmBox(self.m_ModelSceneMain)
		modelConfirmBox:setConfirmText(getLocalizedText(8, "NewWarConfirmation"))
			:setOnConfirmYes(function()
				modelConfirmBox:setEnabled(false)
				createAndEnterWar(self)
			end)
			:setEnabled(true)
	end
end

function ModelWarConfiguratorForNative:setModeCreateCampaign()
	self.m_Mode					= "modeCreateCampaign"
	self.m_MenuTitleTextForMode	= getLocalizedText(1, "Campaign")
	self:setConfirmBox()
	return self
end

function ModelWarConfiguratorForNative:setModeCreateFreeGame()
	self.m_Mode					= "modeCreateFreeGame"
	self.m_MenuTitleTextForMode	= getLocalizedText(1, "Free Game")
	self:setConfirmBox()
	return self
end

function ModelWarConfiguratorForNative:setModeCreateSenarioGame()
	self.m_Mode					= "modeCreateSenarioGame"
	self.m_MenuTitleTextForMode	= '剧情模式'
	self:setConfirmBox()
	return self
end

function ModelWarConfiguratorForNative:setModeContinue()
	self.m_Mode						   = "modeContinue"
	self.m_MenuTitleTextForMode		   = getLocalizedText(1, "Load Game")
	self.m_CallbackOnButtonConfirmTouched = function()
		SingletonGetters.getModelMessageIndicator(self.m_ModelSceneMain):showMessage(getLocalizedText(14, "RetrievingWarData"))
		loadAndEnterWar(self.m_WarConfiguration.saveIndex)
	end

	return self
end

function ModelWarConfiguratorForNative:onStartRunning(modelSceneMain)
	self.m_ModelSceneMain = modelSceneMain

	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelWarConfiguratorForNative:resetWithWarConfiguration(warConfiguration)
	self.m_WarConfiguration = warConfiguration
	local mode = self.m_Mode
	if (mode == "modeCreateCampaign") then
		local advancedSettings = WarFieldManager.getWarFieldData(warConfiguration.warFieldFileName).advancedSettings or {}
		self.m_AttackModifier			= advancedSettings.attackModifier			  or 0
		self.m_EnergyGainModifier		= advancedSettings.energyGainModifier		  or 100
		self.m_IncomeModifier			= advancedSettings.incomeModifier			  or 100
		self.m_IsActiveSkillEnabled	  = advancedSettings.isActiveSkillEnabled
		self.m_IsFogOfWarByDefault	   = advancedSettings.isFogOfWarByDefault
		self.m_IsPassiveSkillEnabled	 = advancedSettings.isPassiveSkillEnabled
		self.m_ItemsForStatePlayerIndex  = nil
		self.m_MoveRangeModifier		 = advancedSettings.moveRangeModifier		   or 0
		self.m_PlayerIndex			   = advancedSettings.playerIndex				 or 1
		self.m_StartingEnergy			= advancedSettings.startingEnergy			  or 0
		self.m_StartingFund			  = advancedSettings.startingFund				or 0
		self.m_TeamIndex				 = 1
		self.m_VisionModifier			= advancedSettings.visionModifier			  or 0

		if (type(self.m_IsActiveSkillEnabled)	  ~= "boolean") then self.m_IsActiveSkillEnabled	  = true  end
		if (type(self.m_IsFogOfWarByDefault)	   ~= "boolean") then self.m_IsFogOfWarByDefault	   = false end
		if (type(self.m_IsPassiveSkillEnabled)	 ~= "boolean") then self.m_IsPassiveSkillEnabled	 = true  end

		self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmCreateWar"))

	elseif (mode == "modeCreateFreeGame") then
		self.m_AttackModifier			= 0
		self.m_EnergyGainModifier		= 100
		self.m_IncomeModifier			= 100
		self.m_IsActiveSkillEnabled	  = true
		self.m_IsFogOfWarByDefault	   = false
		self.m_IsPassiveSkillEnabled	 = true
		self.m_ItemsForStatePlayerIndex  = createItemsForStatePlayerIndex(self)
		self.m_MoveRangeModifier		 = 0
		self.m_PlayerIndex			   = 1
		self.m_StartingEnergy			= 0
		self.m_StartingFund			  = 0
		self.m_TeamIndex				 = 1
		self.m_VisionModifier			= 0

		self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmCreateWar"))

	elseif (mode == "modeContinue") then
		self.m_AttackModifier			= warConfiguration.attackModifier
		self.m_EnergyGainModifier		= warConfiguration.energyGainModifier
		self.m_IncomeModifier			= warConfiguration.incomeModifier
		self.m_IsActiveSkillEnabled	  = warConfiguration.isActiveSkillEnabled
		self.m_IsFogOfWarByDefault	   = warConfiguration.isFogOfWarByDefault
		self.m_IsPassiveSkillEnabled	 = warConfiguration.isPassiveSkillEnabled
		self.m_ItemsForStatePlayerIndex  = nil
		self.m_MoveRangeModifier		 = warConfiguration.moveRangeModifier
		self.m_PlayerIndex			   = getPlayerIndexForWarConfiguration(warConfiguration)
		self.m_StartingEnergy			= warConfiguration.startingEnergy
		self.m_StartingFund			  = warConfiguration.startingFund
		self.m_TeamIndex				 = 1
		self.m_VisionModifier			= warConfiguration.visionModifier

		self.m_View:setButtonConfirmText(getLocalizedText(14, "ConfirmContinueWar"))

	else
		error("ModelWarConfiguratorForNative:resetWithWarConfiguration() the mode of the configurator is invalid: " .. (mode or ""))
	end

	setStateMain(self)

	return self
end

function ModelWarConfiguratorForNative:isEnabled()
	return self.m_IsEnabled
end

function ModelWarConfiguratorForNative:setEnabled(enabled)
	self.m_IsEnabled = enabled

	if (self.m_View) then
		self.m_View:setVisible(enabled)
	end

	return self
end

function ModelWarConfiguratorForNative:onButtonBackTouched()
	local state = self.m_State
	if	 (state == "stateAdvancedSettings")	   then setStateMain(self)
	elseif (state == "stateAttackModifier")		 then setStateAdvancedSettings(self)
	elseif (state == "stateEnableActiveSkill")	  then setStateAdvancedSettings(self)
	elseif (state == "stateEnablePassiveSkill")	 then setStateAdvancedSettings(self)
	elseif (state == "stateEnergyModifier")		 then setStateAdvancedSettings(self)
	elseif (state == "stateFogOfWar")			   then setStateMain(self)
	elseif (state == "stateIncomeModifier")		 then setStateAdvancedSettings(self)
	elseif (state == "stateMoveRangeModifier")	  then setStateAdvancedSettings(self)
	elseif (state == "statePlayerIndex")			then setStateMain(self)
	elseif (state == "stateStartingEnergy")		 then setStateAdvancedSettings(self)
	elseif (state == "stateStartingFund")		   then setStateAdvancedSettings(self)
	elseif (state == "stateVisionModifier")		 then setStateAdvancedSettings(self)
	elseif (self.m_OnButtonBackTouched)			 then self.m_OnButtonBackTouched()
	end

	return self
end

function ModelWarConfiguratorForNative:onButtonConfirmTouched()
	if (self.m_CallbackOnButtonConfirmTouched) then
		self.m_CallbackOnButtonConfirmTouched()
	end

	return self
end

return ModelWarConfiguratorForNative
