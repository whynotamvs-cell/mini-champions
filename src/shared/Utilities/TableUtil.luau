--!strict
-- Small table helpers. No Roblox dependencies.

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = TableUtil.deepCopy(v)
	end
	return copy :: any
end

return TableUtil
