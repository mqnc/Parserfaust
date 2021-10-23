local opf = require "operatorFactory"
local pgf = require "PegGrammarFactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local object = require "object"
local html = require "htmlLogger"
local str = require "PegStringify"

lopf, get = html(opf, str)
parser = pgf(lopf)

source = utils.readFile(arg[0]:gsub("test.lua", "grammar.peg"))

len, tree = parser.parse(source)

utils.writeFile("test.js", get())
