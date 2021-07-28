function pegEscape(str)
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
    local result = str:gsub("([\n\r\t%\'%\"%[%]\\])", function(k)
        return replace[k]
    end)
    return result
end

function walk(op, opDeco, esc)

    if op.getType() == "Literal" then
        return opDeco(op, esc('"' .. pegEscape(op.getConfig().str) .. '"'))

    elseif op.getType() == "Range" then
        local from = op.getConfig().from
        local to = op.getConfig().to
        if from == to then
            return opDeco(op, esc("[" .. pegEscape(from) .. "]"))
        else
            return opDeco(op, esc("[" .. pegEscape(from) .. "-" .. pegEscape(to) .. "]"))
        end

    elseif op.getType() == "Any" then
        return opDeco(op, esc("."))

    elseif op.getType() == "Sequence" then
        local stream = {}
        for i, child in ipairs(op.getConfig().ops) do
            table.insert(stream, walk(child, opDeco, esc))
        end
        return opDeco(op, esc("(") .. table.concat(stream, esc(" ")) .. esc(")"))

    elseif op.getType() == "OrderedChoice" then
        local stream = {}
        for i, child in ipairs(op.getConfig().ops) do
            table.insert(stream, walk(child, opDeco, esc))
        end
        return opDeco(op, esc("(") .. table.concat(stream, esc(" / ")) .. esc(")"))

    elseif op.getType() == "Repetition" then
        local min = op.getConfig().min
        local max = op.getConfig().max
        local inner = walk(op.getConfig().op, opDeco, esc)
        if min == 0 and max == 1 then
            return opDeco(op, esc("(") .. inner .. esc(")?"))
        elseif min == 0 and max == math.huge then
            return opDeco(op, esc("(") .. inner .. esc(")*"))
        elseif min == 1 and max == math.huge then
            return opDeco(op, esc("(") .. inner .. esc(")+"))
        else
            return opDeco(op, esc("(") .. inner .. esc(")*") --
            .. tostring(min) .. esc(":") .. tostring(max))
        end

    elseif op.getType() == "LookAhead" then
        if op.getConfig().posneg == true then
            return opDeco(op, esc("&(") .. walk(op.getConfig().op, opDeco, esc) .. esc(")"))
        else
            return opDeco(op, esc("!(") .. walk(op.getConfig().op, opDeco, esc) .. esc(")"))
        end

    elseif op.getType() == "Rule" then
        local info = debug.getinfo(op.getConfig().action)
        local name = info.short_src .. ":" .. tostring(info.linedefined)
        return opDeco(op, walk(op.getConfig().op, opDeco, esc) .. esc(" # " .. name .. "()"))

    elseif op.getType() == "Reference" then
        return opDeco(op, esc(op.getConfig().target))

    else
        return opDeco(op, esc("<?>"))

    end
end

return function(grammar, opDeco, esc)

    if opDeco == nil then
        opDeco = function(op, str)
            return str
        end
    end

    if esc == nil then
        esc = function(str)
            return str
        end
    end

    local result = {}

    for rule, op in pairs(grammar) do
		result[rule] = opDeco(op, esc(rule .. " <- ") --
        .. walk(op, opDeco, esc))
    end

    return result
end
