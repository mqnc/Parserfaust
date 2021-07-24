return {

    Literal = function(str)
        return {
            getType = function()
                return "Literal"
            end,
            getConfig = function()
                return {
                    str = str
                }
            end,
            parse = function(src, pos)
                if src:sub(pos, pos + #str - 1) == str then
                    return #str
                else
                    return -1
                end
            end
        }
    end,

    Range = function(from, to)
        if to == nil then
            to = from
        end
        return {
            getType = function()
                return "Range"
            end,
            getConfig = function()
                return {
                    from = from,
                    to = to
                }
            end,
            parse = function(src, pos)
                local c = src:sub(pos, pos)
                if from <= c and c <= to then
                    return 1
                else
                    return -1
                end
            end
        }
    end,

    Any = function()
        return {
            getType = function()
                return "Any"
            end,
            getConfig = function()
                return {}
            end,
            parse = function(src, pos)
                if pos > #src then
                    return -1
                else
                    return 1
                end
            end
        }
    end,

    Sequence = function(...)
        local ops = {...}
        return {
            getType = function()
                return "Sequence"
            end,
            getConfig = function()
                return {
                    ops = ops
                }
            end,
            parse = function(src, pos)
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
        }
    end,

    OrderedChoice = function(...)
        local ops = {...}
        return {
            getType = function()
                return "OrderedChoice"
            end,
            getConfig = function()
                return {
                    ops = ops
                }
            end,
            parse = function(src, pos)
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
        }
    end,

    Repetition = function(op, min, max)
        return {
            getType = function()
                return "Repetition"
            end,
            getConfig = function()
                return {
                    op = op,
                    min = min,
                    max = max
                }
            end,
            parse = function(src, pos)
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
        }
    end,

    LookAhead = function(op, posneg)
        return {
            getType = function()
                return "LookAhead"
            end,
            getConfig = function()
                return {
                    op = op,
                    posneg = posneg
                }
            end,
            parse = function(src, pos)
                local len = op.parse(src, pos)
                if (len ~= -1) == posneg then
                    return 0
                else
                    return -1
                end
            end
        }
    end,

    Rule = function(op, action)
        if action == nil then
            action = function(src, pos, len, tree)
                return {pos, len, op, tree}
            end
        end
        return {
            getType = function()
                return "Rule"
            end,
            getConfig = function()
                return {
                    op = op,
                    action = action
                }
            end,
            parse = function(src, pos)
                if pos == nil then
                    pos = 1
                end
                local len, tree = op.parse(src, pos)
                if len ~= -1 then
                    return len, action(src, pos, len, tree)
                else
                    return -1
                end
            end
        }
    end,

    Reference = function(target, env)
        env = env or _G
        return {
            getType = function()
                return "Reference"
            end,
            getConfig = function()
                return {
                    target = target,
                    env = env
                }
            end,
            parse = function(src, pos)
                local op = env[target]
                local len, tree = op.parse(src, pos)
                return len, {pos, len, op, tree}
            end
        }
    end
}
