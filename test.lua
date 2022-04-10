package.path = "tools/?.lua;" .. package.path

require "debugger"
local inspect = (require "inspect").inspect
local fileio = require "fileio"
local stringify = require "pegstringify"

local makePegGrammar = require "pegfactory"

local parser = makePegGrammar()

print(table.concat(stringify.stringifyGrammar(parser), "\n"))

local source = fileio.readFile(arg[0]:gsub("test.lua", "peg.peg"))

local _, parser2 = parser["Grammar"].parse(source)

print(table.concat(stringify.stringifyGrammar(parser2), "\n"))

local _, ast = parser2["Grammar"].parse(source)

print(inspect(ast, {depth = 5}))
