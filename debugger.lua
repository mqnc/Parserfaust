local inspect = (require "inspect").inspect
local stringify = require "pegstringify"
local opf = require "opfactory"
local dsp = require "render"
local colorText = require "colortext"
local colorSpace = require "colorspace"

local FG_COLOR_SELECTED = {0, 64, 255}
local BG_COLOR_SELECTED = {255, 255, 255}
local FG_COLOR_ACCEPTED = {0, 128, 0}
local BG_COLOR_ACCEPTED = {128, 255, 160}
local FG_COLOR_REJECTED = {192, 0, 0}
local BG_COLOR_REJECTED = {255, 160, 160}

_G.stack = {}

local pause = function()
	local userInput = io.read()
	if userInput == "q" then
		print("terminated")
		os.exit(0)
	end
end

local phi = (math.sqrt(5) + 1) / 2
local paletteCache = {}

local function palette(i)
	if paletteCache[i] == nil then
		paletteCache[i] = { --
			colorSpace.RGB_to_sRGB( --
			colorSpace.OKLab_to_RGB( --
			colorSpace.OKLCh_to_OKLab(0.5, 0.2, i * phi * 2 * math.pi + 2)))
		}
	end
	return paletteCache[i]
end

local renderStack = function(buffer, matchLen)
	local stack = _G.stack

	local highlighted = stack[#stack].op
	local highlightTag = {"highlight"}

	local lines = {}
	local marks = {}

	for i = #stack, 1, -1 do
		if i == 1 or stack[i - 1].op.__type[2] == "Reference" then
			local line = colorText(stringify.stringifyRule(stack[i].op, --
			function(op, formatted)
				if op == highlighted then
					return colorText(formatted):tag(highlightTag)
				else
					return formatted
				end
			end))

			local mark1, mark2
			local hlBefore = false
			for pos, char in ipairs(line.txt) do
				local hl = char.tag == highlightTag
				if hl and not hlBefore then
					mark1 = pos
				elseif hlBefore and not hl then
					mark2 = pos
				elseif pos == #line and mark2 == nil then
					mark2 = pos + 1
				end
				hlBefore = hl
			end

			table.insert(lines, line)
			table.insert(marks, {mark1, mark2})

			if i > 1 then
				highlighted = stack[i - 1].op
			end
		end
	end

	for i = 1, dsp.getNumStackLines() - #lines do
		dsp.renderLine(buffer)
	end

	for i, line in ipairs(lines) do
		local level = 1 + #lines - i
		local highlightBackground = palette(level + 1)
		local highlightForeground = {255, 255, 255}
		if i == 1 then
			highlightBackground = BG_COLOR_SELECTED
			highlightForeground = FG_COLOR_SELECTED
			if matchLen == opf.Rejected then
				highlightBackground = BG_COLOR_REJECTED
				highlightForeground = FG_COLOR_REJECTED
			elseif matchLen ~= nil then
				highlightBackground = BG_COLOR_ACCEPTED
				highlightForeground = FG_COLOR_ACCEPTED
			end
		end

		line:fg({255, 255, 255}):bg(palette(level))
		line:range(marks[i][1], marks[i][2]):bg(highlightBackground):fg(highlightForeground)
		dsp.renderLine(buffer, level, line, marks[i][1], marks[i][2])
		if i >= dsp.getNumStackLines() then
			break
		end
	end
	table.insert(buffer, "\n")

end

_G.installDebugHooks = function(op)
	local parse = op.parse
	op.parse = function(src, pos, ctx)
		pos = pos or 1

		table.insert(stack, {op = op, pos = pos, ctx = ctx})

		local cText = colorText(src)

		local level = 0
		for i, layer in ipairs(stack) do
			if i == 1 or stack[i - 1].op.__type[2] == "Reference" then
				level = level + 1
				cText:range(layer.pos, pos):fg({255, 255, 255}):bg(palette(level))
			end
		end

		cText:from(pos):take(1):fg(FG_COLOR_SELECTED):bg(BG_COLOR_SELECTED)

		local buffer = {}
		dsp.render(buffer, cText, pos, pos)
		dsp.renderSeparator(buffer)
		renderStack(buffer)
		io.write(table.concat(buffer))
		pause()

		local len, vals = parse(src, pos, ctx)

		cText = colorText(src)
		level = 0
		for i, layer in ipairs(stack) do
			if i == 1 or stack[i - 1].op.__type[2] == "Reference" then
				level = level + 1
				cText:range(layer.pos, pos):fg({255, 255, 255}):bg(palette(level))
			end
		end

		local past
		if len == opf.Rejected then
			past = pos + 1
			cText:range(pos, past):fg(FG_COLOR_REJECTED):bg(BG_COLOR_REJECTED)
		else
			past = pos + math.max(len, 1)
			cText:range(pos, past):fg(FG_COLOR_ACCEPTED):bg(BG_COLOR_ACCEPTED)
		end

		buffer = {}
		dsp.render(buffer, cText, pos, past)
		dsp.renderSeparator(buffer)
		renderStack(buffer, len)
		io.write(table.concat(buffer))
		pause()

		table.remove(stack)

		return len, vals
	end
	return op
end
