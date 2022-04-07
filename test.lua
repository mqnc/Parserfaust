require "debugger"
local makePegGrammar = require "pegfactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local stringify = require "pegstringify"

local parser = makePegGrammar()

print(table.concat(stringify.stringifyGrammar(parser), "\n"))

local source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))

local _, parser2 = parser["Grammar"].parse(source)

print(table.concat(stringify.stringifyGrammar(parser2), "\n"))

local _, ast = parser2["Grammar"].parse(source)

print(inspect(ast, {depth = 5}))
