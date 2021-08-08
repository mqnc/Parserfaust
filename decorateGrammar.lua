require "object"
local Dispatcher = object.Dispatcher
local Grammar = require "Grammar"
local opf = require "OperatorFactory"

local walk = Dispatcher()

walk[opf.OpType] = function(op, decorate)
    decorate(op)
    if op.op ~= nil then
        walk(op.op, decorate)
    end
    if op.ops ~= nil then
        for _, child in ipairs(op.ops) do
            walk(child, decorate)
        end
    end
end

walk[Grammar.type] = function(grammar, decorate)
    for rule, op in pairs(grammar) do
        walk(op, decorate)
    end
end

return walk
