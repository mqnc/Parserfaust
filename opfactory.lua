if _G.installDebugHooks == nil then
	_G.installDebugHooks = function(...)
		return ...
	end
end

local opf = {}

opf.Empty = {"empty"} -- used for empty slots in arrays
opf.Rejected = {"rejected"}

local emptyIfNil = function(arg)
	if arg ~= nil then
		return arg
	else
		return opf.Empty
	end
end

opf.makeOperator = function()
	local children = {}
	local ruleName

	local op = {}

	op.__type = {"Operator"}

	op.fixRuleName = function(name)
		assert(ruleName == nil)
		ruleName = name
	end

	op.getRuleName = function()
		return ruleName
	end

	op.setChild = function(c)
		assert(c.__type[1] == "Operator")
		children = {c}
	end

	op.setChildren = function(cs)
		assert(type(cs) == "table")
		for _, c in ipairs(cs) do
			assert(c.__type[1] == "Operator")
		end
		children = cs
	end

	op.getChild = function()
		assert(#children == 1)
		return children[1]
	end

	op.getChildren = function()
		return children
	end

	op.parse = function(src, pos, ctx)
		error("parse function not defined")
	end

	return op
end

local makeReference = function(ruleTable, ruleName)
	assert(type(ruleTable) == "table")

	local op = opf.makeOperator()
	table.insert(op.__type, "Reference")

	op.ruleTable = ruleTable
	op.ruleName = ruleName

	op.setChild = function(c)
		op.ruleTable = {start = c}
		op.ruleName = "start"
	end

	op.setChildren = function(cs)
		op.ruleTable = cs
		op.ruleName = next(cs)
	end

	op.getChild = function()
		return op.ruleTable[op.ruleName]
	end

	op.getChildren = function()
		return {op.ruleTable[op.ruleName]}
	end

	op.parse = function(src, pos, ctx)
		if pos == nil then
			pos = 1
		end
		return op.ruleTable[op.ruleName].parse(src, pos, ctx)
	end

	return _G.installDebugHooks(op)
end

opf.makeGrammar = function()
	local rules = {}
	local ordered = {}
	local grammar = {}

	grammar.__type = {"Grammar"}

	setmetatable(grammar, {

		__index = function(_, key)
			return makeReference(rules, key)
		end,

		__newindex = function(_, rule, op)
			if op == nil then
				rules[rule] = nil
				for i, v in ipairs(ordered) do
					if v == rule then
						table.remove(ordered, i)
						break
					end
				end
			end
			if op.getRuleName() == nil then
				op.fixRuleName(rule)
			end
			assert(op.getRuleName() == rule)
			if rules[rule] == nil then
				table.insert(ordered, rule)
			end
			rules[rule] = op
		end,

		__pairs = function()
			local i = 0
			local function iter()
				i = i + 1
				local ruleName = ordered[i]
				if ruleName then
					return ruleName, rules[ruleName]
				end
			end
			return iter
		end
	})

	return grammar
end

opf.makeLiteral = function(str)
	assert(type(str) == "string")

	local op = opf.makeOperator()
	table.insert(op.__type, "Literal")

	op.getString = function()
		return str
	end

	if str == "" then
		op.parse = function()
			return 0
		end
	else
		op.parse = function(src, pos, ctx)
			if src:sub(pos, pos + #str - 1) == str then
				return #str
			else
				return opf.Rejected
			end
		end
	end

	return _G.installDebugHooks(op)
end

opf.makeRange = function(from, to)
	assert(from == nil or type(from) == "string" and #from == 1)
	assert(to == nil or type(to) == "string" and #to == 1)

	local op = opf.makeOperator()
	table.insert(op.__type, "Range")

	if from ~= nil and to == nil then
		to = from
	end
	op.getFromTo = function()
		return from, to
	end

	if from == nil and to == nil then
		op.parse = function()
			return opf.Rejected
		end
	else
		op.parse = function(src, pos, ctx)
			local c = src:sub(pos, pos)
			if from <= c and c <= to then
				return 1
			else
				return opf.Rejected
			end
		end
	end

	return _G.installDebugHooks(op)
end

opf.makeAny = function()
	local op = opf.makeOperator()
	table.insert(op.__type, "Any")

	op.parse = function(src, pos, ctx)
		if pos > #src then
			return opf.Rejected
		else
			return 1
		end
	end

	return _G.installDebugHooks(op)
end

opf.makeRepetition = function(expr, min, max)
	assert(expr.__type[1] == "Operator")
	assert(type(min) == "number")
	assert(type(max) == "number")
	assert(min < max)

	local op = opf.makeOperator()
	table.insert(op.__type, "Repetition")

	if min == 0 and max == 1 then
		table.insert(op.__type, "Optional")
	elseif min == 0 and max == math.huge then
		table.insert(op.__type, "ZeroOrMore")
	elseif min == 1 and max == math.huge then
		table.insert(op.__type, "OneOrMore")
	end

	op.setChild(expr)
	op.getMinMax = function()
		return min, max
	end

	op.parse = function(src, pos, ctx)
		local totalLen = 0
		local vals = {}
		for i = 1, max do
			local start = pos + totalLen
			local len, childVals = op.getChild().parse(src, start, ctx)
			if len == opf.Rejected then
				if i > min then
					return totalLen, vals
				else
					return opf.Rejected
				end
			else
				vals[i] = emptyIfNil(childVals)
				totalLen = totalLen + len
			end
		end
		return totalLen, vals
	end

	return _G.installDebugHooks(op)
end

opf.makeLookAhead = function(expr, isPositive)
	assert(expr.__type[1] == "Operator")
	assert(type(isPositive) == "boolean")

	local op = opf.makeOperator()
	table.insert(op.__type, "LookAhead")

	if isPositive then
		table.insert(op.__type, "And")
	else
		table.insert(op.__type, "Not")
	end

	op.setChild(expr)
	op.isPositive = function()
		return isPositive
	end

	op.parse = function(src, pos, ctx)
		local len = op.getChild().parse(src, pos, ctx)
		if (len ~= opf.Rejected) == isPositive then
			return 0
		else
			return opf.Rejected
		end
	end

	return _G.installDebugHooks(op)
end

opf.makeSequence = function(...)
	local children = {...}
	for _, c in ipairs(children) do
		assert(c.__type[1] == "Operator")
	end

	local op = opf.makeOperator()
	table.insert(op.__type, "Sequence")

	op.setChildren(children)

	op.parse = function(src, pos, ctx)
		local totalLen = 0
		local vals = {}

		for i, child in ipairs(op.getChildren()) do
			local start = pos + totalLen
			local len, childVals = child.parse(src, start, ctx)
			if len == opf.Rejected then
				return opf.Rejected
			else
				vals[i] = emptyIfNil(childVals)
				totalLen = totalLen + len
			end
		end

		return totalLen, vals
	end

	return _G.installDebugHooks(op)
end

opf.makeChoice = function(...)
	local children = {...}
	for _, c in ipairs(children) do
		assert(c.__type[1] == "Operator")
	end

	local op = opf.makeOperator()
	table.insert(op.__type, "Choice")

	op.setChildren(children)

	op.parse = function(src, pos, ctx)
		for i, child in ipairs(op.getChildren()) do
			local len, childVals = child.parse(src, pos, ctx)
			if len ~= opf.Rejected then
				return len, {[i] = emptyIfNil(childVals)}
			end
		end
		return opf.Rejected
	end

	return _G.installDebugHooks(op)
end

opf.makeContext = function(expr, ctx)
	assert(expr.__type[1] == "Operator")
	assert(type(ctx) == "table")

	local op = opf.makeOperator()
	table.insert(op.__type, "Context")

	op.setChild(expr)
	op.ctx = ctx

	op.parse = function(src, pos, ctx)
		local newCtx = {}
		for k, v in pairs(op.ctx) do
			newCtx[k] = v
		end
		setmetatable(newCtx, {__index = ctx})
		return op.getChild().parse(src, pos, newCtx)
	end

	return _G.installDebugHooks(op)
end

opf.makeAction = function(expr, action)
	assert(expr.__type[1] == "Operator")
	assert(type(action) == "function")

	local op = opf.makeOperator()
	table.insert(op.__type, "Action")

	op.setChild(expr)
	op.action = action

	op.parse = function(src, pos, ctx)
		local len, vals = op.getChild().parse(src, pos, ctx)
		if len == opf.Rejected then
			return opf.Rejected
		else
			return len, op.action({src = src, pos = pos, len = len, vals = vals, ctx = ctx})
		end
	end

	return _G.installDebugHooks(op)
end

return opf
