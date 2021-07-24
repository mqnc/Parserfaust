function escape(str)
    local replace = {
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
        ["\'"] = "\\'",
        ["\""] = '\\"',
        ["["] = "\\[",
        ["]"] = "\\]",
        ["\\"] = "\\\\"
    }
    return str:gsub("([\n\r\t%\'%\"%[%]\\])", function(k)
        return replace[k]
    end)
end

function walk(op)

    if op.getType() == "Literal" then
        return '"' .. escape(op.getConfig().str) .. '"'

    elseif op.getType() == "Range" then
        local from = op.getConfig().from
        local to = op.getConfig().to
        if from == to then
            return "[" .. escape(from) .. "]"
        else
            return "[" .. escape(from) .. "-" .. escape(to) .. "]"
        end

    elseif op.getType() == "Any" then
        return "."

    elseif op.getType() == "Sequence" then
        local stream = {}
        for i, child in ipairs(op.getConfig().ops) do
            table.insert(stream, walk(child))
        end
        return "(" .. table.concat(stream, " ") .. ")"

    elseif op.getType() == "OrderedChoice" then
        local stream = {}
        for i, child in ipairs(op.getConfig().ops) do
            table.insert(stream, walk(child))
        end
        return "(" .. table.concat(stream, " / ") .. ")"

    elseif op.getType() == "Repetition" then
        local min = op.getConfig().min
        local max = op.getConfig().max
        local inner = walk(op.getConfig().op)
        if min == 0 and max == 1 then
            return "(" .. inner .. ")?"
        elseif min == 0 and max == math.huge then
            return "(" .. inner .. ")*"
        elseif min == 1 and max == math.huge then
            return "(" .. inner .. ")+"
        else
            return "(" .. inner .. ")*" --
            .. tostring(min) .. ":" .. tostring(max)
        end

    elseif op.getType() == "LookAhead" then
        if op.getConfig().posneg == true then
            return "&(" .. walk(op.getConfig().op) .. ")"
        else
            return "!(" .. walk(op.getConfig().op) .. ")"
        end

    elseif op.getType() == "Rule" then
        local info = debug.getinfo(op.getConfig().action)
        local name = info.short_src .. ":" .. tostring(info.linedefined)
        return walk(op.getConfig().op) .. " # " .. name .. "()"

    elseif op.getType() == "Reference" then
        return op.getConfig().target

    else
        return "<?>"

    end
end

return function(grammar)
    local stream = {}
    for rule, definition in pairs(grammar) do
        table.insert(stream, rule .. " <- " --
        .. walk(definition) .. "\n")
    end
    return table.concat(stream, "")
end
