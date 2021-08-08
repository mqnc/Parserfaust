local tag = require "tag"
require "object"
local Object = object.Object

local opf = {}

opf.OpType = tag:derive("Op", {"parse"})

opf.LiteralType = opf.OpType:derive("Literal", {"str"})
opf.RangeType = opf.OpType:derive("Range", {"from", "to"})
opf.AnyType = opf.OpType:derive("Any")

opf.RepetitionType = opf.OpType:derive("Repetition", {"min", "max"})
opf.OptionalType = opf.RepetitionType:derive("Optional")
opf.ZeroOrMoreType = opf.RepetitionType:derive("ZeroOrMore")
opf.OneOrMoreType = opf.RepetitionType:derive("OneOrMore")

opf.LookAheadType = opf.OpType:derive("LookAhead", {"op", "posneg"})
opf.AndType = opf.LookAheadType:derive("And")
opf.NotType = opf.LookAheadType:derive("Not")

opf.SequenceType = opf.OpType:derive("Sequence", {"ops"})
opf.ChoiceType = opf.OpType:derive("Choice", {"ops"})
opf.ActionType = opf.OpType:derive("Action", {"op, action"})
opf.ReferenceType = opf.OpType:derive("Reference", {"target", "env"})

function opf.makeFactory()
    return {

        Literal = function(str)
            local self = Object(opf.LiteralType, {
                str = str
            })
            if str == "" then
                self.parse = function()
                    return 0
                end
            else
                self.parse = function(src, pos)
                    if src:sub(pos, pos + #str - 1) == str then
                        return #str
                    else
                        return -1
                    end
                end
            end
            return self
        end,

        Range = function(from, to)
            if from ~= nil and to == nil then
                to = from
            end
            local self = Object(opf.RangeType, {
                from = from,
                to = to
            })
            if from == nil and to == nil then
                self.parse = function()
                    return -1
                end
            else
                self.parse = function(src, pos)
                    local c = src:sub(pos, pos)
                    if from <= c and c <= to then
                        return 1
                    else
                        return -1
                    end
                end
            end
            return self
        end,

        Any = function()
            local self = Object(opf.AnyType)
            self.parse = function(src, pos)
                if pos > #src then
                    return -1
                else
                    return 1
                end
            end
            return self
        end,

        Repetition = function(op, min, max)
            local opType
            if min == 0 and max == 1 then
                opType = opf.OptionalType
            elseif min == 0 and max == math.huge then
                opType = opf.ZeroOrMoreType
            elseif min == 1 and max == math.huge then
                opType = opf.OneOrMoreType
            else
                opType = opf.RepetitionType
            end
            local self = Object(opType, {
                op = op,
                min = min,
                max = max
            })
            self.parse = function(src, pos)
                local totalLen = 0
                local tree = {}
                for i = 1, max do
                    local start = pos + totalLen
                    local len, twig = op.parse(src, start)
                    if len == -1 then
                        if i > min then
                            return totalLen, tree
                        else
                            return -1
                        end
                    else
                        table.insert(tree, {
                            pos = start,
                            len = len,
                            op = op,
                            tree = twig
                        })
                        totalLen = totalLen + len
                    end
                end
                return totalLen, tree
            end
            return self
        end,

        LookAhead = function(op, posneg)
            local opType
            if posneg then
                opType = opf.AndType
            else
                opType = opf.NotType
            end
            local self = Object(opType, {
                op = op,
                posneg = posneg
            })
            self.parse = function(src, pos)
                local len = op.parse(src, pos)
                if (len ~= -1) == posneg then
                    return 0
                else
                    return -1
                end
            end
            return self
        end,

        Sequence = function(...)
            local ops = {...}
            local self = Object(opf.SequenceType, {
                ops = ops
            })
            self.parse = function(src, pos)
                local totalLen = 0
                local tree = {}

                for i, op in ipairs(ops) do
                    local start = pos + totalLen
                    local len, twig = op.parse(src, start)
                    if len == -1 then
                        return -1
                    else
                        table.insert(tree, {
                            pos = start,
                            len = len,
                            op = op,
                            tree = twig
                        })
                        totalLen = totalLen + len
                    end
                end
                return totalLen, tree
            end
            return self
        end,

        Choice = function(...)
            local ops = {...}
            local self = Object(opf.ChoiceType, {
                ops = ops
            })
            self.parse = function(src, pos)
                for i, op in ipairs(ops) do
                    local len, twig = op.parse(src, pos)
                    if len ~= -1 then
                        return len, {
                            pos = pos,
                            len = len,
                            op = op,
                            tree = twig
                        }
                    end
                end
                return -1
            end
            return self
        end,

        Action = function(op, action)
            if action == nil then
                action = function(src, pos, len, tree)
                    return {pos, len, op, tree}
                end
            end
            local self = Object(opf.ActionType, {
                op = op,
                action = action
            })
            self.parse = function(src, pos)
                local len, tree = op.parse(src, pos)
                if len ~= -1 then
                    return len, action(src, pos, len, tree)
                else
                    return -1
                end
            end
            return self
        end,

        Reference = function(target, env)
            env = env or _G
            local self = Object(opf.ReferenceType, {
                target = target,
                env = env
            })
            self.parse = function(src, pos)
                local op = env[target]
                local len, tree = op.parse(src, pos)
                return len, {pos, len, op, tree}
            end
            return self
        end
    }
end

return opf