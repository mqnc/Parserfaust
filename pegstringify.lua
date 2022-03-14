local pegEscapeMap = {
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\'"] = "\\'",
	["\""] = '\\"',
	["["] = "\\[",
	["]"] = "\\]",
	["\\"] = "\\\\"
}
for d2 = 0, 3 do
	for d1 = 0, 7 do
		for d0 = 0, 7 do
			local codeStr = d2 .. d1 .. d0
			local code = tonumber(codeStr, 8)
			local char = string.char(code)
			if code < 32 and pegEscapeMap[char] == nil or code >= 127 then
				pegEscapeMap[char] = "\\" .. codeStr
			end
		end
	end
end

local escape = function(txt)
	return (txt:gsub("([\0-\31\127-\255%\'%\"%[%]%\\])", pegEscapeMap))
end

local stringifyRule = function(rule, opDecorator)
	if opDecorator == nil then
		opDecorator = function(op, formatted)
			return formatted
		end
	end

	local formatters = {}

	local format = function(op)
		local formatted = formatters[op.__type[#op.__type]](op)
		return opDecorator(op, formatted)
	end

	formatters.Reference = function(op)
		-- if op == rule then -- top level is reference, expand
		-- 	return op.ruleName .. " <- " .. format(op.getChild())
		-- else
		return op.ruleName
		-- end
	end

	formatters.Literal = function(op)
		return '"' .. escape(op.getString()) .. '"'
	end

	formatters.Range = function(op)
		local from, to = op.getFromTo()
		if from == nil then
			return "[]"
		end
		if from == to then
			return '[' .. escape(from) .. ']'
		end
		return '[' .. escape(from) .. '-' .. escape(to) .. ']'
	end

	formatters.Any = function(op)
		return '.'
	end

	formatters.Optional = function(op)
		return '(' .. format(op.getChild()) .. ')?'
	end

	formatters.ZeroOrMore = function(op)
		return '(' .. format(op.getChild()) .. ')*'
	end

	formatters.OneOrMore = function(op)
		return '(' .. format(op.getChild()) .. ')+'
	end

	formatters.And = function(op)
		return '&(' .. format(op.getChild()) .. ')'
	end

	formatters.Not = function(op)
		return '!(' .. format(op.getChild()) .. ')'
	end

	formatters.Sequence = function(op)
		-- table.concat does not call the __concat metamethod
		local stream = ""
		for i, child in ipairs(op.getChildren()) do
			if i ~= 1 then
				stream = stream .. " "
			end
			stream = stream .. format(child)
		end
		return '(' .. stream .. ')'
	end

	formatters.Choice = function(op)
		-- table.concat does not call the __concat metamethod
		local stream = ""
		for i, child in ipairs(op.getChildren()) do
			if i ~= 1 then
				stream = stream .. " / "
			end
			stream = stream .. format(child)
		end
		return '(' .. stream .. ')'
	end

	formatters.Context = function(op)
		return '<' .. format(op.getChild()) .. '>'
	end

	formatters.Action = function(op)
		local info = debug.getinfo(op.action)
		local name = info.short_src:match("^.+[/\\](.+)$") --
		.. ":" .. info.linedefined
		return '(' .. format(op.getChild()) .. '){' .. name .. '}'
	end

	return format(rule)
end

local stringifyGrammar = function(start, opDecorator)
	if opDecorator == nil then
		opDecorator = function(op, formatted)
			return formatted
		end
	end

	local processed = {}

	local scan
	scan = function(op)
		if processed[op] == nil then
			processed[op] = false
			for _, child in ipairs(op.getChildren()) do
				scan(child)
			end
		end
	end

	-- local result = {}

	-- if start.__type[2] == "Reference" then
	-- 	format(start)
	-- else
	-- 	table.insert(result, format(start))
	-- end

	-- while true do
	-- 	local name, op = next(opsTodo)
	-- 	if name == nil then
	-- 		break
	-- 	end
	-- 	table.insert(result, name .. " <- " .. format(op))
	-- 	opsTodo[name] = nil
	-- end

	-- table.sort(result)

	-- return table.concat(result, '\n')
end

return {stringifyRule = stringifyRule, stringifyGrammar = stringifyGrammar}
