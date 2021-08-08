require "object"
local T = object.typeKey
local makeStringifier = require "PegStringify"

local icon = {
    ["Op/Literal"] = '"',
    ["Op/Range"] = '𝄩',
    ["Op/Any"] = '.',
    ["Op/Repetition/Optional"] = '?',
    ["Repetition/ZeroOrMore"] = '*',
    ["Repetition/OneOrMore"] = '+',
    ["Op/Repetition"] = '𝄇',
    ["LookAhead/And"] = '&',
    ["LookAhead/Not"] = '!',
    ["Op/Sequence"] = '⋯',
    ["Op/Choice"] = '/',
    ["Op/Action"] = 'f',
    ["Op/Reference"] = '@'
}

return function(grammar, startRule, source)

    local id = 0
    local log = {}

    local types = {}

    function decorator(Op)
        return function(...)
            id = id + 1
            local operator = Op(...)
            operator.id = id
            types[id] = icon[operator[T]]
            local oldParse = operator.parse
            local newParse = function(src, pos)
                if operator[T] == "Reference" then
                    table.insert(log, --
                    "[" .. operator.target .. "," .. pos .. "],")
                end
                table.insert(log, "[" .. operator.id .. "," .. pos .. "],")
                local len, tree = oldParse(src, pos)
                table.insert(log, "[" .. operator.id .. "," .. pos .. "," .. len .. "],")
                if operator[T] == "Reference" then
                    table.insert(log, --
                    "['" .. operator.target .. "'," .. pos .. "," .. len .. "],")
                end
                return len, tree
            end
            operator.parse = newParse
            return operator
        end
    end

    local grammar = grammarFactory(decorator)
    local numOperators = id

    print(table.concat(types, "','"))

    local stringify = makeStringifier()

    stringify.Grammar = function(grammar)
        local result = {}
        for rule, op in pairs(grammar) do
            table.insert(result, "\01" .. rule .. "\02" .. rule .. --
            "\03 <- " .. stringify(op) .. "\n")
        end
        return (table.concat(result):gsub("\n\n", "\n"))
    end

    for operator, original in pairs(stringify) do
        if operator ~= "Grammar" and operator ~= T .. "string" then
            stringify[operator] = function(op)
                return "\01" .. op.id .. "\02" .. original(op) .. "\03"
            end
        end
    end

    local replace = {
        ["\01"] = '<span id="',
        ["\02"] = '">',
        ["\03"] = '</span>',
        ["\n"] = "<br>\n",
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&apos;"
    }

    print((stringify(grammar):gsub("[\01\02\03\n%&%<%>%\"%\']", replace)))
end
