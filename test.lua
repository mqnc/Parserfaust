local opf = require "operatorFactory"
local pgf = require "PegGrammarFactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local object = require "object"
local html = require "htmlLogger"
local str = require "PegStringify"

lopf = html(opf, str)
parser = pgf(lopf)

source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))
len, tree = parser.parse(source)

print()

-- print(grammar(source))

-- utils.writeFile("test.js", tostring(grammar))
