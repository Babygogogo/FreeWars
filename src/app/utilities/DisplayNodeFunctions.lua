
--[[--------------------------------------------------------------------------------
-- DisplayNodeFunctions是一系列关于显示节点的工具函数。
--]]--------------------------------------------------------------------------------

local DisplayNodeFunctions = {}

function DisplayNodeFunctions.isTouchWithinNode(touch, node)
	local location = node:convertToNodeSpace(touch:getLocation())
	local x, y = location.x, location.y

	local contentSize = node:getContentSize()
	local width, height = contentSize.width, contentSize.height

	return (x >= 0) and (y >= 0) and (x <= width) and (y <= height)
end
return DisplayNodeFunctions