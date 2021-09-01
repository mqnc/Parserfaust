local object = require "object"
local opf = require "operatorFactory"
local utils = require "utils"

local strfy = {}

strfy.icons = {
    [opf.Grammar] = '🖹',
    [opf.Reference] = '@',
    [opf.Literal] = '"',
    [opf.Range] = '𝄩',
    [opf.Any] = '.',
    [opf.Optional] = '?',
    [opf.ZeroOrMore] = '*',
    [opf.OneOrMore] = '+',
    [opf.And] = '&',
    [opf.Not] = '!',
    [opf.Sequence] = '⋯',
    [opf.Choice] = '/',
    [opf.Action] = 'f'
}

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

strfy.escape = function(txt)
    return (txt:gsub("([\0-\31\127-\255%\'%\"%[%]\\])", pegEscapeMap))
end

strfy.rule = function(name, op, outputFn)
    outputFn(name, " <- ", op, "\n")
end

strfy[opf.Grammar] = function(op, outputFn)
    for name, def in pairs(op.rules) do
        strfy.rule(name, def, outputFn)
    end
end

strfy[opf.Reference] = function(op, outputFn)
    outputFn(op.rule)
end

strfy[opf.Literal] = function(op, outputFn)
    outputFn('"', strfy.escape(op.str), '"')
end

strfy[opf.Range] = function(op, outputFn)
    local from = op.from
    local to = op.to
    outputFn('[')
    if from ~= nil then
        outputFn(strfy.escape(from))
    end
    if from ~= to then
        outputFn('-', strfy.escape(to))
    end
    outputFn(']')
end

strfy[opf.Any] = function(op, outputFn)
    outputFn('.')
end

strfy[opf.Optional] = function(op, outputFn)
    outputFn('(', op.op, ')?')
end

strfy[opf.ZeroOrMore] = function(op, outputFn)
	outputFn('(', op.op, ')*')
end

strfy[opf.OneOrMore] = function(op, outputFn)
	outputFn('(', op.op, ')+')
end

strfy[opf.And] = function(op, outputFn)
	outputFn('&(', op.op, ')')
end

strfy[opf.Not] = function(op, outputFn)
    outputFn('!(', op.op, ')')
end

strfy[opf.Sequence] = function(op, outputFn)
    outputFn('(')
    local first = true
    for _, child in ipairs(op.ops) do
        if not first then
            outputFn(" ")
        else
            first = false
        end
        outputFn(child)
    end
    outputFn(')')
end

strfy[opf.Choice] = function(op, outputFn)
    outputFn('(')
    local first = true
    for _, child in ipairs(op.ops) do
        if not first then
            outputFn(" / ")
        else
            first = false
        end
        outputFn(child)
    end
    outputFn(')')
end

strfy[opf.Action] = function(op, outputFn)
    local info = debug.getinfo(op.action)
    local name = info.short_src:match("^.+[/\\](.+)$") --
    .. ":" .. info.linedefined
    outputFn('(', op.op, '){', name, "}")
end

return strfy