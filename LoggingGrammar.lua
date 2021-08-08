require "object"
local Object = object.Object
local getType = object.getType
local Grammar = require "Grammar"
local decorate = require "decorateGrammar"
local Stringifier = require "PegStringifierFactory"
local opf = require "OperatorFactory"

local icon = {
    [opf.LiteralType] = '"',
    [opf.RangeType] = '𝄩',
    [opf.AnyType] = '.',
    [opf.OptionalType] = '?',
    [opf.ZeroOrMoreType] = '*',
    [opf.OneOrMoreType] = '+',
    [opf.RepetitionType] = '𝄇',
    [opf.AndType] = '&',
    [opf.NotType] = '!',
    [opf.SequenceType] = '⋯',
    [opf.ChoiceType] = '/',
    [opf.ActionType] = 'f',
    [opf.ReferenceType] = '@'
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

local replaceHtml = "[\01\02\03\n%&%<%>%\"%\']"
local replaceHtmlMap = {
    -- we don't want <, > and " of the span tags to be html escaped
    -- so we insert placeholders first
    ["\01"] = '<span id="',
    ["\02"] = '">',
    ["\03"] = '</span>',
    ["\n"] = "<br>\n",
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&apos;"
}

return function()

    local id = 0
    local log = {}

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
            if T == opf.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "]")
            end
            local len, tree = oldParse(src, pos)
            if T == opf.ReferenceType then
                table.insert(log, --
                "['" .. op.target .. "'," .. pos .. "," .. len .. "]")
            end
            table.insert(log, "[" .. op.id .. "," .. pos .. "," .. len .. "]")
            return len, tree
        end
        op.parse = newParse
    end

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

    mt.__index = function(t, rule)
        return grammar[rule]
    end

    mt.__newindex = function(t, k, v)
        local T = object.getType(v)
        if opf.OpType:includes(object.getType(v)) then
            decorate(v, deco)
            table.insert(log, '{"' .. k .. '":"' .. --
            stringify(v) --
            :gsub(replaceHtml, replaceHtmlMap) --
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
