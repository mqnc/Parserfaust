local object = require "object"
local osf = require "OperatorSuperFactory"
local Grammar = require "Grammar"
local Dispatcher = object.Dispatcher

local pegEscape = {
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
            if code < 32 and pegEscape[char] == nil or code >= 127 then
                pegEscape[char] = "\\" .. codeStr
            end
        end
    end
end

local stringifyInto = Dispatcher()

stringifyInto[object.string] = function(txt, ss)
    ss.append((txt:gsub("([\0-\31\127-\255%\'%\"%[%]\\])", pegEscape)))
end

stringifyInto[osf.GrammarType] = function(op, ss)
    for name, def in pairs(grammar.rules) do
        ss.append(rule, " <- ")
        stringifyInto(def, ss)
        ss.append("\n")
    end
end

stringifyInto[osf.ReferenceType] = function(op, ss)
    ss.append(op.rule)
end

stringifyInto[osf.LiteralType] = function(op, ss)
    ss.append('"')
    stringifyInto(op.str, ss)
    ss.append('"')
end

stringifyInto[osf.RangeType] = function(op, ss)
    local from = op.from
    local to = op.to
    ss.append('[')
    if from ~= nil then
        stringifyInto(from, ss)
    end
    if from ~= to then
        ss.append('-')
        stringifyInto(to, ss)
    end
    ss.append(']')
end

stringifyInto[osf.AnyType] = function(op, ss)
    ss.append('.')
end

stringifyInto[osf.OptionalType] = function(op, ss)
    ss.append('(')
    stringifyInto(op.op, ss)
    ss.append(')?')
end

stringifyInto[osf.ZeroOrMoreType] = function(op, ss)
    ss.append('(')
    stringifyInto(op.op, ss)
    ss.append(')*')
end

stringifyInto[osf.OneOrMoreType] = function(op, ss)
    ss.append('(')
    stringifyInto(op.op, ss)
    ss.append(')+')
end

stringifyInto[osf.AndType] = function(op, ss)
    ss.append('&(')
    stringifyInto(op.op, ss)
    ss.append(')')
end

stringifyInto[osf.NotType] = function(op, ss)
    ss.append('!(')
    stringifyInto(op.op, ss)
    ss.append(')')
end

stringifyInto[osf.SequenceType] = function(op, ss)
    ss.append('(')
    local first = true
    for _, child in ipairs(op.ops) do
        if not first then
            ss.append(" ")
		else
            first = false
        end
        stringifyInto(child, ss)
    end
    ss.append(')')
end

stringifyInto[osf.ChoiceType] = function(op, ss)
    ss.append('(')
    local first = true
    for _, child in ipairs(op.ops) do
        if not first then
            ss.append(" / ")
		else
            first = false
        end
        stringifyInto(child, ss)
    end
    ss.append(')')
end

stringifyInto[osf.ActionType] = function(op, ss)
    local info = debug.getinfo(op.action)
    local name = info.short_src:match("^.+[/\\](.+)$") --
    .. ":" .. info.linedefined
    ss.append('(')
    stringifyInto(op.op, ss)
    ss.append('){', name, "}")
end

return stringifyInto
