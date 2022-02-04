local tag = require "tag"
local Object = (require "object").Object
local ctxf = require "contextFactory"
local inspect = (require "inspect").inspect

local opf = {}

opf.Op = tag:create("Op")

opf.Grammar = opf.Op:derive("Grammar")
opf.Reference = opf.Op:derive("Reference")

opf.Literal = opf.Op:derive("Literal")
opf.Range = opf.Op:derive("Range")
opf.Any = opf.Op:derive("Any")

opf.Repetition = opf.Op:derive("Repetition")
opf.Optional = opf.Repetition:derive("Optional")
opf.ZeroOrMore = opf.Repetition:derive("ZeroOrMore")
opf.OneOrMore = opf.Repetition:derive("OneOrMore")

opf.LookAhead = opf.Op:derive("LookAhead")
opf.And = opf.LookAhead:derive("And")
opf.Not = opf.LookAhead:derive("Not")

opf.Sequence = opf.Op:derive("Sequence")
opf.Choice = opf.Op:derive("Choice")
opf.Action = opf.Op:derive("Action")

opf.Fail = tag:create("Fail")
opf.Empty = tag:create("Empty")
local emptyIfNil=function(arg)
	if arg ~= nil then
		return arg
	else
		return opf.Empty
	end
end

opf[opf.Grammar] = function(startRule)
	local self = Object(opf.Grammar, {startRule = startRule})
	self.rules = {}
	self.parse = function(src, pos, ctx)
		if pos == nil then
			pos = 1
		end
		ctx = ctx or ctxf.makeContext()
		return self.rules[self.startRule].parse(src, pos, ctx)
	end
	return self
end

opf[opf.Reference] = function(rule, grammar)
	local self = Object(opf.Reference,
			{rule = rule, grammar = grammar})
	self.parse = function(src, pos, ctx)
		local grm = self.grammar or ctx.activeGrammar
		local rul = self.rule or grm.startRule
		-- print(rul)
		-- local result = {grm.rules[rul].parse(src, pos, ctx)}
		-- print(rul, inspect(result))
		-- return table.unpack(result)
		return grm.rules[rul].parse(src, pos, ctx)
	end
	return self
end

opf[opf.Literal] = function(str)
	local self = Object(opf.Literal, {str = str})
	if str == "" then
		self.parse = function()
			return 0
		end
	else
		self.parse = function(src, pos, ctx)
			if src:sub(pos, pos + #str - 1) == str then
				return #str
			else
				return opf.Fail
			end
		end
	end
	return self
end

opf[opf.Range] = function(from, to)
	if from ~= nil and to == nil then
		to = from
	end
	local self = Object(opf.Range, {from = from, to = to})
	if from == nil and to == nil then
		self.parse = function()
			return opf.Fail
		end
	else
		self.parse = function(src, pos, ctx)
			local c = src:sub(pos, pos)
			if from <= c and c <= to then
				return 1
			else
				return opf.Fail
			end
		end
	end
	return self
end

opf[opf.Any] = function()
	local self = Object(opf.Any)
	self.parse = function(src, pos, ctx)
		if pos > #src then
			return opf.Fail
		else
			return 1
		end
	end

	return self
end

opf[opf.Repetition] = function(op, min, max)
	local opType
	if min == 0 and max == 1 then
		opType = opf.Optional
	elseif min == 0 and max == math.huge then
		opType = opf.ZeroOrMore
	elseif min == 1 and max == math.huge then
		opType = opf.OneOrMore
	else
		opType = opf.Repetition
	end
	local self =
			Object(opType, {op = op, min = min, max = max})
	self.parse = function(src, pos, ctx)
		local totalLen = 0
		local vals = {}
		for i = 1, max do
			local start = pos + totalLen
			local len, childVals = op.parse(src, start, ctx)
			if len == opf.Fail then
				if i > min then
					return totalLen, vals
				else
					return opf.Fail
				end
			else
				vals[i] = emptyIfNil(childVals)
				totalLen = totalLen + len
			end
		end
		return totalLen, vals
	end

	return self
end

opf[opf.LookAhead] = function(op, posneg)
	local opType
	if posneg then
		opType = opf.And
	else
		opType = opf.Not
	end
	local self = Object(opType, {op = op, posneg = posneg})
	self.parse = function(src, pos, ctx)
		local len = op.parse(src, pos, ctx)
		if (len ~= opf.Fail) == posneg then
			return 0
		else
			return opf.Fail
		end
	end
	return self
end

opf[opf.Sequence] = function(...)
	local ops = {...}
	local self = Object(opf.Sequence, {ops = ops})
	self.parse = function(src, pos, ctx)
		local totalLen = 0
		local vals = {}

		for i, op in ipairs(ops) do
			local start = pos + totalLen
			local len, childVals = op.parse(src, start, ctx)
			if len == opf.Fail then
				return opf.Fail
			else
				vals[i] = emptyIfNil(childVals)
				totalLen = totalLen + len
			end
		end
		return totalLen, vals
	end
	return self
end

opf[opf.Choice] = function(...)
	local ops = {...}
	local self = Object(opf.Choice, {ops = ops})
	self.parse = function(src, pos, ctx)
		for i, op in ipairs(ops) do
			local len, childVals = op.parse(src, pos, ctx)
			if len ~= opf.Fail then
				return len, {[i] = emptyIfNil(childVals)}
			end
		end
		return opf.Fail
	end
	return self
end

opf[opf.Action] = function(op, action)
	assert(action ~= nil)
	local self = Object(opf.Action, {op = op, action = action})
	self.parse = function(src, pos, ctx)
		local len, vals = op.parse(src, pos, ctx)
		if len == opf.Fail then
			return opf.Fail
		else
			return len, action({
				src = src,
				pos = pos,
				len = len,
				vals = vals,
				ctx = ctx
			})
		end
	end
	return self
end

return opf
