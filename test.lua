require "debugger"
local makePegGrammar = require "pegfactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local stringify = require "pegstringify"
local parser = makePegGrammar()
local source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))
local len, parser2 = parser.parse(source)
-- print(stringify(parser))
print('--------------------------------------------------')
-- print(stringify(parser2))
-- local list = analyze(parser)
-- -- print(inspect(list))
-- -- print(inspect(parser))
-- local len, parser2 = parser.parse(source)
-- print(stringify(parser2))
-- print('--------------------------------------------------')
-- local len, parser3 = parser2.parse(source)
-- -- print(stringify(parser3))
print("\027[m")
