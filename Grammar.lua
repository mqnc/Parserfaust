local tag = require "tag"
require "object"
local Object = object.Object
local opf = require "OperatorFactory"

local g = {}

g.type = tag:derive("Grammar", {"create", "setStart"})

function g.create()
    local grammar = Object("Grammar", nil, object.CHRONOLOGICAL_ORDER)
end

function g.setStart(grammar, ruleName)
    local start = opf.makeFactory().Reference(ruleName, grammar)

    grammar[CALL] = start
end

return g