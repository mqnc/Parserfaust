makeGrammar = require "PegGrammarFactory"
inspect = require "inspect"

print(debug.getinfo(1).source)
print(inspect(arg))

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

source = readFile(arg[0]:gsub("test.lua", "peg.peg"))

function decorator(Op)
    return function(...)
        local operator = Op(...)
        if operator.type == "Pointer" then
            local oldParse = operator.parse
            local newParse = function(src, pos)
                print(operator.config.name)
                return oldParse(src, pos)
            end
            operator.parse = newParse
        end
        return operator
    end
end
decorator = nil

rules = makeGrammar(decorator)
print(inspect(rules, {
    depth = 1
}))

--[[
indent = 0
for name, rule in pairs(rules) do
    local oldParse = rule.parse
    local newParse = function(src, pos)
        pos = pos or 1

        local tabs = ""
        for i = 1, indent do
            tabs = tabs .. "|  "
        end

        print(tabs .. "? >" .. string.sub(src, pos, pos + 20):gsub("\n", "↵") .. ".. == " .. name)

        indent = indent + 1
        local result = oldParse(src, pos)
        indent = indent - 1

        if result == -1 then
            print(tabs .. "X >" .. string.sub(src, pos, pos + 20):gsub("\n", "↵") .. ".. != " .. name)
        else
            print(tabs .. "v >" .. string.sub(src, pos, pos + 20):gsub("\n", "↵") .. ".. == " .. name)
        end
        return result
    end
    rule.parse = newParse
end
]]

match, tree = rules.Grammar.parse(source, 1)
print(match, "=", #source)

print(inspect(tree))