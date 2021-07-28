local inspect = require "PegGrammarInspector"

return function(grammarFactory, startRule, source)

    local id = 0
    local log = {}

    function decorator(Op)
        return function(...)
            id = id + 1
            local operator = Op(...)
            operator.id = id
            local oldParse = operator.parse
            local newParse = function(src, pos)
                table.insert(log, "[" .. tostring(operator.id) .. "," --
                .. tostring(pos) .. "],")
                local len, tree = oldParse(src, pos)
                table.insert(log, "[-" .. tostring(operator.id) .. "," --
                .. tostring(pos) .. "," .. len .. "],")
                return len, tree
            end
            operator.parse = newParse
            return operator
        end
    end

    local grammar = grammarFactory(decorator)
    local numOperators = id

    local deco = function(op, str)
        return '<span id="' .. tostring(op.id) .. '">' .. str .. '</span>'
    end

    local esc = function(str)
        local replace = {
            ["\n"] = "<br>\n",
            ["&"] = "&amp;",
            ["<"] = "&lt;",
            [">"] = "&gt;",
            ['"'] = "&quot;",
            ["'"] = "&apos;"
        }
        local result = str:gsub("([\n%&%<%>%\"%\'])", function(k)
            return replace[k]
        end)
        return result
    end

    local rules = inspect(grammar, deco, esc)

    local ruleList = {}
    for rule, str in pairs(grammar) do
        ruleList[grammar[rule].id] = rule
    end

    local ps = {}
    local ruleListJs = {"{"}
    for i = 1, numOperators do
        local rule = ruleList[i]
        if rule ~= nil then
            table.insert(ps, '<p id="' .. rule .. '">' .. rules[rule] .. '</p>')
            table.insert(ruleListJs, tostring(i) .. ':"' .. rule .. '",')
        end
    end
    table.insert(ruleListJs, "}")

    do
        local file = io.open("rules.html", "w")
        file:write(table.concat(ps, "\n"))
        file:close()
    end

    table.insert(log, "[")
    grammar[startRule].parse(source, 1)
    table.insert(log, "]")

    do
        local file = io.open("log.js", "w")
        file:write(table.concat(ruleListJs) .. "\n" .. table.concat(log))
        file:close()
    end

end
