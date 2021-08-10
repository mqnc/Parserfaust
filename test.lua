local osf = require "OperatorSuperFactory"
local pgf = require "PegGrammarFactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local object = require "object"
local html = require "htmlLoggingGrammar"

-- fillPegGrammar(grammar, operators)

source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))
len, tree = parser.parse(source)

html.print()

-- print(grammar(source))

-- utils.writeFile("test.js", tostring(grammar))
