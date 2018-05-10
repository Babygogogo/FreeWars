--[[Modified:NewCO
ModelConfirmBox用于构造一个操作确认框，给玩家进一步确认。
本类设有Yes和No两个按钮（以及“取消”操作，在玩家点击框外空白地方时激发），默认的点击行为是使得确认框消失，具体行为需要本类的调用者传入。
本类的文字描述也可以由调用者定制。
主要职责及使用场景举例：
	玩家点击“结束回合”等敏感按钮时时，会弹出本确认框让玩家再次确认，以免误操作。
--]]

local ModelConfirmBox = class("ModelConfirmBox")
local Actor		   = requireFW("src.global.actors.Actor")

--------------------------------------------------------------------------------
-- The constructor and initializers.
--------------------------------------------------------------------------------
function ModelConfirmBox:ctor(param)
	if (param) then
		if (param.confirmText)	 then self:setConfirmText(param.confirmText)		 end
		if (param.onConfirmYes)	then self:setOnConfirmYes(param.onConfirmYes)	   end
		if (param.onConfirmNo)	 then self:setOnConfirmNo(param.onConfirmNo)		 end
		if (param.onConfirmCancel) then self:setOnConfirmCancel(param.onConfirmCancel) end
	end
	return self
end

--------------------------------------------------------------------------------
-- The public functions.
--------------------------------------------------------------------------------
function ModelConfirmBox:setConfirmText(text)
	if (self.m_View) then
		self.m_View:setConfirmText(text)
	end
	return self
end

function ModelConfirmBox:setOnConfirmYes(callback)
	self.m_OnConfirmYes = callback
	return self
end

function ModelConfirmBox:onConfirmYes()
	if (self.m_OnConfirmYes) then
		self.m_OnConfirmYes()
	end
	return self
end

function ModelConfirmBox:setOnConfirmNo(callback)
	self.m_OnConfirmNo = callback
	return self
end

function ModelConfirmBox:onConfirmNo()
	if (self.m_OnConfirmNo) then
		self.m_OnConfirmNo()
	end
	return self
end

function ModelConfirmBox:setOnConfirmCancel(callback)
	self.m_OnConfirmCancel = callback
	return self
end

function ModelConfirmBox:onConfirmCancel()
	if (self.m_OnConfirmCancel) then
		self.m_OnConfirmCancel()
	end
	return self
end

function ModelConfirmBox:setEnabled(enabled)
	if (self.m_View) then
		self.m_View:setEnabled(enabled)
	end
	return self
end

return ModelConfirmBox