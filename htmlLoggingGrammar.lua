local object = require "object"
local Object = object.Object
local getType = object.getType
local Grammar = require "Grammar"
local stringifyInto = require "PegStringifier"
local osf = require "OperatorSuperFactory"
local utils = require "utils"

local icon = {
    [osf.GrammarType] = '🖹',
    [osf.ReferenceType] = '@',
    [osf.LiteralType] = '"',
    [osf.RangeType] = '𝄩',
    [osf.AnyType] = '.',
    [osf.OptionalType] = '?',
    [osf.ZeroOrMoreType] = '*',
    [osf.OneOrMoreType] = '+',
    [osf.RepetitionType] = '⟲',
    [osf.AndType] = '&',
    [osf.NotType] = '!',
    [osf.SequenceType] = '⋯',
    [osf.ChoiceType] = '/',
    [osf.ActionType] = 'f'
}

local escapeJs = "[\b\f\n\r\t\v\0\'\"\\]"
local escapeJsMap = {
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
}

local escapeHtml = "[\n%&%<%>%\"%\']"
local escapeHtmlMap = {
    ["\n"] = "<br>\n",
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&apos;"
}

return function(operatorSuperFactory, stringifier)

	local operatorFactory = operatorSuperFactory(html.ruleDeco, html.opDeco, html.parseDeco)

    local log = utils.stringStream()

    function html.ruleDeco(name, op)
        log.append(name, " <- ")
        stringifyInto(op, log)
        return op
    end

    local id = 0
    function html.opDeco(op)
        id = id + 1
        op.id = id
        return op
    end

    function html.parseDeco(op, fn)
        return function(src, pos)
            -- log.append("[", op.id, ",", pos, "]")
            local match = fn(src, pos)
            -- log.append("[", op.id, ",", pos, ",", match, "]")
            return match
        end
    end

    function html.print()
        print(table.concat(log))
    end

end
--[[
return function()

    local id = 0
    local log = {}

    local grammar = Grammar.create()

    local stringify = Stringifier()

    for typeTag, original in pairs(stringify) do
        if typeTag ~= Grammar.type and typeTag ~= object.string then
            stringify[typeTag] = function(op)
                return "\01" .. op.id .. "\02" .. original(op) .. "\03"
            end
        end
    end

    local mt = {}

    local function deco(op)
        local T = getType(op)
        if op.id ~= nil then
            return
        end
        id = id + 1
        op.id = id
        op.icon = icon[T]

        local oldParse = op.parse
        local newParse = function(src, pos)
            table.insert(log, "[" .. op.id .. "," .. pos .. "]")
            if T == osf.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "]")
            end
            local len, tree = oldParse(src, pos)
            if T == osf.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "," .. len .. "]")
            end
            table.insert(log, "[" .. op.id .. "," .. pos .. "," .. len .. "]")
            return len, tree
        end
        op.parse = newParse
    end

    mt.__index = function(t, rule)
        return grammar[rule]
    end

    mt.__newindex = function(t, k, v)
        if type(k) == "string" --
        and osf.OpType:includes(object.getType(v)) then
            Grammar.decorate(v, deco)
            table.insert(log, '{"' .. k .. '":"' .. --
            stringify(v) --
            :gsub(escapeHtml, escapeHtmlMap) --
            :gsub(escapeJs, escapeJsMap) .. '"}')
        end
        rawset(t, k, v)
    end

    mt.__tostring = function()
        return "let program=[" .. table.concat(log, ",\n") .. "]"
    end

    local proxy = {}
    setmetatable(proxy, mt)

    return proxy
end
]]
