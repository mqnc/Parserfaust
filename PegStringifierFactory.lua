require "object"
local opf = require "OperatorFactory"
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

return function()
    local str = Dispatcher()

    str[object.string] = function(txt)
        local result = txt:gsub("([\0-\31\127-\255%\'%\"%[%]\\])", pegEscape)
        return result
    end

    str[opf.LiteralType] = function(op)
        return '"' .. str(op.str) .. '"'
    end

    str[opf.RangeType] = function(op)
        local from = op.from
        local to = op.to
        if from == to then
            return "[" .. str(from) .. "]"
        else
            return "[" .. str(from) .. "-" .. str(to) .. "]"
        end
    end

    str[opf.AnyType] = function(op)
        return "*"
    end

    str[opf.OptionalType] = function(op)
        return "(" .. str(op.op) .. ")?"
    end

    str[opf.ZeroOrMoreType] = function(op)
        return "(" .. str(op.op) .. ")*"
    end

    str[opf.OneOrMoreType] = function(op)
        return "(" .. str(op.op) .. ")+"
    end

    str[opf.AndType] = function(op)
        return "&(" .. str(op.op) .. ")"
    end

    str[opf.NotType] = function(op)
        return "!(" .. str(op.op) .. ")"
    end

    str[opf.SequenceType] = function(op)
        local stream = {}
        for i, child in ipairs(op.ops) do
            table.insert(stream, str(child))
        end
        return "(" .. table.concat(stream, " ") .. ")"
    end

    str[opf.ChoiceType] = function(op)
        local stream = {}
        for i, child in ipairs(op.ops) do
            table.insert(stream, str(child))
        end
        return "(" .. table.concat(stream, " / ") .. ")"
    end

    str[opf.ActionType] = function(op)
        local info = debug.getinfo(op.action)
        local name = info.short_src .. ":" .. info.linedefined
        return "(" .. str(op.op) .. ") # {" .. name .. "}\n"
    end

    str[opf.ReferenceType] = function(op)
        return op.target
    end

    str[Grammar.type] = function(grammar)
        local result = {}
        for rule, op in pairs(grammar) do
            table.insert(result, rule .. " <- " .. str(op) .. "\n")
        end
        return (table.concat(result):gsub("\n\n", "\n"))
    end

    return str
end
