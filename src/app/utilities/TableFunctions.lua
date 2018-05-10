local TableFunctions = {}

local pairs = pairs

function TableFunctions.union(t1, t2)
	if ((t1 == nil) and (t2 == nil)) then
		return nil
	end

	local t = {}
	for k, v in pairs(t1 or {}) do
		t[k] = v
	end
	for k, v in pairs(t2 or {}) do
		t[k] = v
	end

	return t
end

function TableFunctions.clone(t, ignoredKeys)
	local clonedTable = {}
	for k, v in pairs(t) do
		clonedTable[k] = v
	end

	if (ignoredKeys) then
		for _, ignoredKey in pairs(ignoredKeys) do
			clonedTable[ignoredKey] = nil
		end
	end

	return clonedTable
end

function TableFunctions.deepClone(t)
	if (type(t) ~= "table") then
		return t
	else
		local clonedTable = {}
		for k, v in pairs(t) do
			clonedTable[TableFunctions.deepClone(k)] = TableFunctions.deepClone(v)
		end
		return clonedTable
	end
end

return TableFunctions