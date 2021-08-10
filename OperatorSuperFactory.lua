local tag = require "tag"
local utils = require "utils"
local object = require "object"
local Object = object.Object

local osf = {}

osf.OpType = tag:create("Op", {"parse"})

osf.LiteralType = osf.OpType:derive("Literal", {"str"})
osf.RangeType = osf.OpType:derive("Range", {"from", "to"})
osf.AnyType = osf.OpType:derive("Any")

osf.RepetitionType = osf.OpType:derive("Repetition", {"min", "max"})
osf.OptionalType = osf.RepetitionType:derive("Optional")
osf.ZeroOrMoreType = osf.RepetitionType:derive("ZeroOrMore")
osf.OneOrMoreType = osf.RepetitionType:derive("OneOrMore")

osf.LookAheadType = osf.OpType:derive("LookAhead", {"op", "posneg"})
osf.AndType = osf.LookAheadType:derive("And")
osf.NotType = osf.LookAheadType:derive("Not")

osf.SequenceType = osf.OpType:derive("Sequence", {"ops"})
osf.ChoiceType = osf.OpType:derive("Choice", {"ops"})
osf.ActionType = osf.OpType:derive("Action", {"op, action"})

osf.GrammarType = osf.OpType:derive("Grammar", {"rules", "startRule"})
osf.ReferenceType = osf.OpType:derive("Reference", {"grammar", "rule"})

function osf.makeOperatorFactory(ruleDeco, opDeco, parseDeco)

    if ruleDeco == nil then
        ruleDeco = function(name, op)
            return op
        end
    end

    if opDeco == nil then
        opDeco = function(op)
            return op
        end
    end

    if parseDeco == nil then
        parseDeco = function(op, fn)
            return fn
        end
    end

    return {

        Grammar = function(startRule)
            local self = Object(osf.GrammarType)
            self.rules = {}
            self.startRule = startRule
            self.defRule = function(name, op)
                self.rules[name] = ruleDeco(name, op)
            end
            self.parse = parseDeco(self, function(src, pos)
                if pos == nil then
                    pos = 1
                end
                return self.rules[self.startRule].parse(src, pos)
            end)
            return opDeco(self)
        end,

        Reference = function(grammar, rule)
            local self = Object(osf.ReferenceType, {
                grammar = grammar,
                rule = rule
            })
            if rule == nil then
                self.parse = parseDeco(self, function(src, pos)
                    local len, tree = grammar.parse(src, pos)
                    return len, {pos, len, op, tree}
                end)
            else
                self.parse = parseDeco(self, function(src, pos)
                    local len, tree = grammar.rules[rule].parse(src, pos)
                    return len, {pos, len, op, tree}
                end)
            end
            return opDeco(self)
        end,

        Literal = function(str)
            local self = Object(osf.LiteralType, {
                str = str
            })
            if str == "" then
                self.parse = parseDeco(self, function()
                    return 0
                end)
            else
                self.parse = parseDeco(self, function(src, pos)
                    if src:sub(pos, pos + #str - 1) == str then
                        return #str
                    else
                        return -1
                    end
                end)
            end
            return opDeco(self)
        end,

        Range = function(from, to)
            if from ~= nil and to == nil then
                to = from
            end
            local self = Object(osf.RangeType, {
                from = from,
                to = to
            })
            if from == nil and to == nil then
                self.parse = parseDeco(self, function()
                    return -1
                end)
            else
                self.parse = parseDeco(self, function(src, pos)
                    local c = src:sub(pos, pos)
                    if from <= c and c <= to then
                        return 1
                    else
                        return -1
                    end
                end)
            end
            return opDeco(self)
        end,

        Any = function()
            local self = Object(osf.AnyType)
            self.parse = parseDeco(self, function(src, pos)
                if pos > #src then
                    return -1
                else
                    return 1
                end
            end)
            return opDeco(self)
        end,

        Repetition = function(op, min, max)
            local opType
            if min == 0 and max == 1 then
                opType = osf.OptionalType
            elseif min == 0 and max == math.huge then
                opType = osf.ZeroOrMoreType
            elseif min == 1 and max == math.huge then
                opType = osf.OneOrMoreType
            else
                opType = osf.RepetitionType
            end
            local self = Object(opType, {
                op = op,
                min = min,
                max = max
            })
            self.parse = parseDeco(self, function(src, pos)
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
            end)
            return opDeco(self)
        end,

        LookAhead = function(op, posneg)
            local opType
            if posneg then
                opType = osf.AndType
            else
                opType = osf.NotType
            end
            local self = Object(opType, {
                op = op,
                posneg = posneg
            })
            self.parse = parseDeco(self, function(src, pos)
                local len = op.parse(src, pos)
                if (len ~= -1) == posneg then
                    return 0
                else
                    return -1
                end
            end)
            return opDeco(self)
        end,

        Sequence = function(...)
            local ops = {...}
            local self = Object(osf.SequenceType, {
                ops = ops
            })
            self.parse = parseDeco(self, function(src, pos)
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
            end)
            return opDeco(self)
        end,

        Choice = function(...)
            local ops = {...}
            local self = Object(osf.ChoiceType, {
                ops = ops
            })
            self.parse = parseDeco(self, function(src, pos)
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
            end)
            return opDeco(self)
        end,

        Action = function(op, action)
            if action == nil then
                action = function(src, pos, len, tree)
                    return {pos, len, op, tree}
                end
            end
            local self = Object(osf.ActionType, {
                op = op,
                action = action
            })
            self.parse = parseDeco(self, function(src, pos)
                local len, tree = op.parse(src, pos)
                if len ~= -1 then
                    return len, action(src, pos, len, tree)
                else
                    return -1
                end
            end)
            return opDeco(self)
        end
    }
end

return osf
