local utils = require "utils"
local object = require "object"
local tag = require "tag"
local inspect = (require "inspect").inspect


local esc = tag:create("EscapeMarker")
local js = esc:derive("BeginJsString")
local html = esc:derive("BeginHtmlText")
local over = esc:derive("EndOfEscape")

local action = {
	[js] = function(txt)
		return (txt:gsub("[\b\f\n\r\t\v%z\'\"\\]", {
			["\b"] = "\\b",
			["\f"] = "\\f",
			["\n"] = "\\n",
			["\r"] = "\\r",
			["\t"] = "\\t",
			["\v"] = "\\v",
			["\0"] = "\\0",
			["\'"] = "\\\'",
			["\""] = "\\\"",
			["\\"] = "\\\\"
		}))
	end,

	[html] = function(txt)
		return (txt:gsub("[\n%&%<%>%\"%\']", {
			["\n"] = "<br>\n",
			["&"] = "&amp;",
			["<"] = "&lt;",
			[">"] = "&gt;",
			['"'] = "&quot;",
			["'"] = "&apos;"
		}))
	end
}

return function(operatorFactory, stringifier)
	local id = 0
	local buffer = {}
	local output

	local currentFilter = utils.forward
	local previousFilters = {}

	output = function(...)
		for _, v in ipairs({...}) do
			local T = object.getType(v)
			if operatorFactory.Grammar:includes(T) then
				output(over, "<span data-type='GrammarRef' ", --
				"data-target='op", v.id, "'></span>", html)
			elseif operatorFactory.Op:includes(T) then
				output(over, "<span id='op", v.id, --
				"' data-type='", T.label:gsub("[^%.]*%.", ""), "'>")
				output(html)
				stringifier[T](v, output)
				output(over)
				output("</span>", html)
			elseif esc:includes(v) then
				if v == js or v == html then
					local previousFilter = currentFilter
					table.insert(previousFilters, previousFilter)
					currentFilter = function(txt)
						return action[v](previousFilter(txt))
					end
				elseif v == over then
					currentFilter = table.remove(previousFilters)
				end
			elseif type(v) == "string" or type(v) == "number" then
				table.insert(buffer, currentFilter(tostring(v)))
			end
		end
	end

	local opfMt = {
		__index = function(t, k)

			if operatorFactory.Op:includes(k) then
				return function(...)

					local op = operatorFactory[k](...)
					op.id=id

					local opProxy = {}

					opProxy.id = id
					id = id + 1

					local isRef = operatorFactory.Reference:includes(k)
					local isGrm = operatorFactory.Grammar:includes(k)

					opProxy.parse = function(src, pos, ctx)
						local p = pos
						if p == nil then
							p = 1
						end
						output("[", opProxy.id, ",", p, "],")
						local result = {op.parse(src, pos, ctx)}
						if result[1] == operatorFactory.Fail then
							output("F,")
						else
							output(result[1], ",")
						end
						return table.unpack(result)
					end

					if isGrm then
						opProxy.rules = {}
						setmetatable(opProxy.rules, {
							__index = op.rules,
							__newindex = function(_, name, def)
								stringifier.rule(name, def, --
								function(name, arrow, def, br)
									output("{type:'Rule', id:'@op", def.id, --
									"', name:'", name, "', html:'", js, --
									"<tr><td><span id='@op", def.id, --
									"' data-type='Rule'>", --
									name, "</span></td><td> &lt;- </td>", --
									"<td>", html, def, over, "</td></tr>", --
									over, "', parent:'op", opProxy.id, "'},")
								end)
								op.rules[name] = def
							end,
							__pairs = function(_)
								return pairs(op.rules)
							end
						})
						output("{type:'Grammar', id:'op", opProxy.id, --
						"', html:'", js, "<table id='op", opProxy.id, --
						"' data-type='Grammar'></table>", over, "'},")
					end

					utils.proxyfy(op, opProxy)

					return opProxy

				end
			else
				return operatorFactory[k]
			end

		end,

		__newindex = function(t, k, v)
			operatorFactory[k] = v
		end
	}

	local opFactoryProxy = {}
	setmetatable(opFactoryProxy, opfMt)

	local function getLog()
		return "let F = Symbol('fail')\n" --
		.. "let packedProgram=[" .. table.concat(buffer) .. "]"
	end

	return opFactoryProxy, getLog
end
