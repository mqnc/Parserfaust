makeGrammar = require "PegGrammarFactory"
inspect = require "inspect"

--[[
local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

source = readFile("peg.peg")
]]

source = [[
# Hierarchical syntax
Grammar    <- Spacing Definition+ EndOfFile
Definition <- Identifier LEFTARROW Expression

Expression <- Sequence (SLASH Sequence)*
Sequence   <- Prefix*
Prefix     <- (AND / NOT)? Suffix
Suffix     <- Primary (QUESTION / STAR / PLUS)?
Primary    <- Identifier !LEFTARROW
            / OPEN Expression CLOSE
            / Literal / Class / DOT

# Lexical syntax
Identifier <- IdentStart IdentCont* Spacing
IdentStart <- [a-zA-Z_]
IdentCont  <- IdentStart / [0-9]

Literal    <- ['] (!['] Char)* ['] Spacing
            / ["] (!["] Char)* ["] Spacing
Class      <- '[' (!']' Range)* ']' Spacing
Range      <- Char '-' Char / Char
Char       <- '\\' [nrt'"\[\]\\]
            / '\\' [0-2][0-7][0-7]
            / '\\' [0-7][0-7]?
            / !'\\' .

LEFTARROW  <- '<-' Spacing
SLASH      <- '/' Spacing
AND        <- '&' Spacing
NOT        <- '!' Spacing
QUESTION   <- '?' Spacing
STAR       <- '*' Spacing
PLUS       <- '+' Spacing
OPEN       <- '(' Spacing
CLOSE      <- ')' Spacing
DOT        <- '.' Spacing

Spacing    <- (Space / Comment)*
Comment    <- '#' (!EndOfLine .)* EndOfLine
Space      <- ' ' / '\t' / EndOfLine
EndOfLine  <- '\r\n' / '\n' / '\r'
EndOfFile  <- !.
]]

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

print(rules.Grammar.parse(source))
print(#source)