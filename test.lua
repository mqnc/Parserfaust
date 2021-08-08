makeLoggingGrammar = require "LoggingGrammar"
opf = require "OperatorFactory"
fillPegGrammar = require "PegGrammarFactory"
inspect = (require "inspect").inspect

local function readFile(path)
    local file = io.open(path, "r")
    local data = file:read("*a")
    file:close()
    return data
end

local function writeFile(path, data)
    local file = io.open(path, "w")
    file:write(data)
    file:close()
end

operators = opf.makeFactory()
grammar = makeLoggingGrammar()
fillPegGrammar(grammar, operators)

source = readFile(arg[0]:gsub("test.lua", "peg.peg"))

print(grammar.Grammar.parse(source, 1))

writeFile("test.js", tostring(grammar))
