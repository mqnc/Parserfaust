return {

    Literal = function(str)
        return {
            type = "Literal",
            config = {
                str = str
            },
            parse = function(src, pos)
                if src:sub(pos, pos + #str - 1) == str then
                    return #str, {
                        ['"'] = str
                    }
                else
                    return -1
                end
            end
        }
    end,

    Range = function(from, to)
        return {
            type = "Range",
            config = {
                from = from,
                to = to
            },
            parse = function(src, pos)
                local c = src:sub(pos, pos)
                if from <= c and c <= to then
                    return 1, {
                        ['-'] = c
                    }
                else
                    return -1
                end
            end
        }
    end,

    Any = function()
        return {
            type = "Any",
            config = {},
            parse = function(src, pos)
                if pos > #src then
                    return -1
                else
                    return 1, {
                        ['.'] = src:sub(pos, pos)
                    }
                end
            end
        }
    end,

    Sequence = function(...)
        local ops = {...}
        return {
            type = "Sequence",
            config = {
                ops = ops
            },
            parse = function(src, pos)
                local match = 0
                local tree = {}

                for i, op in ipairs(ops) do
                    local m, twig = op.parse(src, pos + match)
                    if m == -1 then
                        return -1
                    else
                        match = match + m
                        table.insert(tree, {m, twig})
                    end
                end
                return match, {
                    [','] = tree
                }
            end
        }
    end,

    OrderedChoice = function(...)
        local ops = {...}
        return {
            type = "OrderedChoice",
            config = {
                ops = ops
            },
            parse = function(src, pos)
                for i, op in ipairs(ops) do
                    local m, twig = op.parse(src, pos)
                    if m ~= -1 then
                        return m, {
                            ['/'] = twig
                        }
                    end
                end
                return -1
            end
        }
    end,
    Repetition = function(op, min, max)
        local icon = '^'
        if min == 0 and max == 1 then
            icon = '?'
        elseif min == 0 and max == math.huge then
            icon = '*'
        elseif min == 1 and max == math.huge then
            icon = '+'
        end
        return {
            type = "Repetition",
            config = {
                op = op,
                min = min,
                max = max
            },
            parse = function(src, pos)
                local match = 0
                local tree = {}
                for i = 1, max do
                    local m, twig = op.parse(src, pos + match)
                    if m == -1 then
                        if i > min then
                            return match, {
                                [icon] = tree
                            }
                        else
                            return -1
                        end
                    else
                        match = match + m
                        table.insert(tree, {m, twig})
                    end
                end
                return match, {
                    [icon] = tree
                }
            end
        }
    end,

    LookAhead = function(op, posneg)
        if posneg == nil then
            posneg = true
        end
        local icon = '&'
        if posneg == false then
            icon = '!'
        end
        return {
            type = "LookAhead",
            config = {
                op = op,
                posneg = posneg
            },
            parse = function(src, pos)
                local m = op.parse(src, pos)
                if (m ~= -1) == posneg then
                    return 0, {
                        [icon] = true
                    }
                else
                    return -1
                end
            end
        }
    end,

    Pointer = function(name, env)
        env = env or _G
        return {
            type = "Pointer",
            config = {
                name = name,
                env = env
            },
            parse = function(src, pos)
                local m, tree = env[name].parse(src, pos)
                return m, {
                    ['@' .. name] = tree
                }
            end
        }
    end
}
