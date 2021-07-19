return {

    Literal = function(str)
        return {
            type = "Literal",
            config = {
                str = str
            },
            parse = function(src, pos)
                pos = pos or 1
                if src:sub(pos, pos + #str - 1) == str then
                    return #str
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
                pos = pos or 1
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
            type = "Any",
            config = {},
            parse = function(src, pos)
                pos = pos or 1
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
            type = "Sequence",
            config = {
                ops = ops
            },
            parse = function(src, pos)
                pos = pos or 1
                local match = 0
                for i, op in ipairs(ops) do
                    local m = op.parse(src, pos + match)
                    if m == -1 then
                        return -1
                    else
                        match = match + m
                    end
                end
                return match
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
                pos = pos or 1
                for i, op in ipairs(ops) do
                    local m = op.parse(src, pos)
                    if m ~= -1 then
                        return m
                    end
                end
                return -1
            end
        }
    end,
    Repetition = function(op, min, max)
        return {
            type = "Repetition",
            config = {
                op = op,
                min = min,
                max = max
            },
            parse = function(src, pos)
                pos = pos or 1
                local match = 0
                for i = 1, max do
                    local m = op.parse(src, pos + match)
                    if m == -1 then
                        if i > min then
                            return match
                        else
                            return -1
                        end
                    else
                        match = match + m
                    end
                end
                return match
            end
        }
    end,

    LookAhead = function(op, posneg)
        if posneg == nil then
            posneg = true
        end
        return {
            type = "LookAhead",
            config = {
                op = op,
                posneg = posneg
            },
            parse = function(src, pos)
                pos = pos or 1
                local m = op.parse(src, pos)
                if (m ~= -1) == posneg then
                    return 0
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
                pos = pos or 1
                return env[name].parse(src, pos)
            end
        }
    end
}
