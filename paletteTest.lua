-- require "debugger"
-- local makePegGrammar = require "pegfactory"
-- local inspect = (require "inspect").inspect
-- local utils = require "utils"
-- local stringify = require "pegstringify"
-- local parser = makePegGrammar()
-- local source = utils.readFile(arg[0]:gsub("test.lua", "peg.peg"))
-- local len, parser2 = parser.parse(source)
-- -- print(stringify(parser))
-- print('--------------------------------------------------')
-- -- print(stringify(parser2))
-- -- local list = analyze(parser)
-- -- -- print(inspect(list))
-- -- -- print(inspect(parser))
-- -- local len, parser2 = parser.parse(source)
-- -- print(stringify(parser2))
-- -- print('--------------------------------------------------')
-- -- local len, parser3 = parser2.parse(source)
-- -- -- print(stringify(parser3))
-- print("\027[m")
local space = require "colorspace"
local ct = require "colortext"

local phi = (math.sqrt(5) + 1) / 2
local paletteCache = {}

local function OKLCh2sRGB(L, C, h)
	return space.RGB_to_sRGB( --
	space.OKLab_to_RGB( --
	space.OKLCh_to_OKLab(L, C, h)))
end

local function palette(i)
	if paletteCache[i] == nil then
		paletteCache[i] = --
		space.RGB_to_sRGB( --
		space.OKLab_to_RGB( --
		space.OKLCh_to_OKLab(0.6, 0.2, i * phi)))
	end
	return paletteCache[i]
end

local nx = 100
local ny = 24
local xmin = -math.pi
local xmax = 3 * math.pi
local ymin = 0.2
local ymax = 0.2
local z = 0.6

local txt = ct(string.rep(string.rep("G", nx) .. "\n", ny))

for y = 0, ny - 1 do
	for x = 0, nx - 1 do
		local i = y * (nx + 1) + x + 1
		-- local vx = x / (nx - 1) * (xmax - xmin) + xmin
		local vx = phi * (x // 4) * 2 * math.pi
		local vy = y / (ny - 1) * (ymax - ymin) + ymin
		local bg = {OKLCh2sRGB(z, vy, vx)}
		local fg
		if y < (ny - 1) / 3 then
			fg = {0, 0, 0}
		elseif y < 2 * (ny - 1) / 3 then
			fg = bg
		else
			fg = {255, 255, 255}
		end
		txt:range(i, i + 1):bg(bg):fg(fg)
	end
end
print(txt)
