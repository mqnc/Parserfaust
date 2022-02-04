local opf = require "operatorFactory"
local pgf = require "PegGrammarFactory"
local inspect = (require "inspect").inspect
local utils = require "utils"
local object = require "object"
local html = require "htmlLogger"
local strfy = require "PegStringify"

local lopf, get = html(opf, strfy)
local parser = pgf(opf)

local source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))

local len, result = parser.parse(source)
strfy(result)
--print(inspect(result, {depth=10}))
-- utils.writeFile("test.js", get())

--to do: I think the problem is that meta tables are overridden and the type systems include thing doesn't work
--[[
idea
screw the html output, make a console output
debugging via lua debug call hook
if the first argument is the source string and the second a position, were likely in a parse function
then we can also step from there
and we can stop when we reached a certain position in the source
we can also access the functions upvalue "self" and see if were in self.parse
ah, when parsing we should always be inside an operator with a parse function
and the operator has a unique address which we can remember when we stringify it, so we can highlight where in the grammar we are
]]