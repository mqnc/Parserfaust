
local explore
explore = function(op, opList)
	opList = opList or {}
	if opList[op] == nil then
		opList[op] = true
		for _, child in ipairs(op.getChildren()) do
			explore(child, opList)
		end
	end
	return opList
end
