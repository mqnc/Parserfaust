local inspect = (require "inspect").inspect
local stringify = require "pegstringify"
local opf = require "opfactory"
local dsp = require "render"
local colorText = require "colortext"
local colorSpace = require "colorspace"

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
	local highlightTag = {}

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
					mark2 = pos - 1
				elseif pos == #line and mark2 == nil then
					mark2 = pos
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

	for i, line in ipairs(lines) do
		local level = #lines - i + 1
		local highlightBackground = palette(level + 1)
		local highlightForeground = {255, 255, 255}
		if i == 1 then
			highlightBackground = {255, 192, 0}
			highlightForeground = {0, 0, 0}
			if matchLen == opf.Rejected then
				highlightBackground = {255, 0, 0}
			elseif matchLen ~= nil then
				highlightBackground = {0, 230, 0}
			end
		end

		line:fg({255, 255, 255}):bg(palette(level))
		line:fromTo(marks[i][1], marks[i][2]):bg(highlightBackground):fg(highlightForeground)
		dsp.renderLine(buffer, level, line, marks[i][1], marks[i][2])
	end
	table.insert(buffer, "\n")

end

_G.installDebugHooks = function(op)
	local parse = op.parse
	op.parse = function(src, pos, ctx)

		table.insert(stack, {op = op, pos = pos, ctx = ctx})

		local from = pos or 1
		local cText = colorText(src)
		cText:from(from):take(1):fg({0, 0, 0}):bg({255, 192, 0})

		local buffer = {}
		dsp.render(buffer, cText, from, from)
		renderStack(buffer)
		io.write(table.concat(buffer))
		pause()

		local len, vals = parse(src, pos, ctx)

		cText = colorText(src)
		local to
		if len == opf.Rejected then
			to = from
			cText:fromTo(from, to):fg({0, 0, 0}):bg({255, 0, 0})
		else
			to = from + len - 1
			cText:fromTo(from, to):fg({0, 0, 0}):bg({0, 221, 0})
		end

		buffer = {}
		dsp.render(buffer, cText, from, to)
		renderStack(buffer, len)
		io.write(table.concat(buffer))
		pause()

		table.remove(stack)

		return len, vals
	end
	return op
end
