local tag = require "tag"
local object = require "object"
local operators = require "operatorFactory"

local g = {}

g.type = tag:create("Grammar", {"create", "setStart", "decorate"})

function g.create()
    local grammar = object.Object(g.type, nil, object.CHRONOLOGICAL_ORDER)
end

function g.setStart(grammar, ruleName)
    local start = operators.makeOperatorFactory().Reference(ruleName, grammar)
    object.setCall(grammar, function(src)
        return start(src, 1)
    end)
end

g.decorate = object.Dispatcher()

g.decorate[operators.OpType] = function(op, decorator)
    decorator(op)
    if op.op ~= nil then
        g.decorate(op.op, decorator)
    end
    if op.ops ~= nil then
        for _, child in ipairs(op.ops) do
            g.decorate(child, decorator)
        end
    end
end

g.decorate[g.type] = function(grammar, decorator)
    for rule, op in pairs(grammar) do
        g.decorate(op, decorator)
    end
end

return g
