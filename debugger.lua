local inspect = (require "inspect").inspect
local stringify = require "pegstringify"
local opf = require "opfactory"
local dsp = require "render"
local color = require "color"

_G.stack = {}

local pause = function()
	local userInput = io.read()
	if userInput == "q" then
		print("terminated")
		os.exit(0)
	end
end

local phiColor = function(index)
	local colors = {
		{128, 0, 0}, --
		{128, 128, 0}, --
		{0, 128, 0}, --
		{0, 128, 128}, --
		{0, 0, 128}, --
		{128, 0, 128} --
	}
	return colors[(index % 6) + 1]
end

local renderStack = function(buffer, matchLen)
	local stack = _G.stack

	local highlight = stack[#stack].op

	local highlightColor = {255, 192, 0}

	if matchLen == opf.Rejected then
		highlightColor = {255, 0, 0}
	elseif matchLen ~= nil then
		highlightColor = {0, 221, 0}
	end

	local lines = {}
	local marks = {}

	for i = #stack, 1, -1 do
		if i == 1 or stack[i - 1].op.__type[2] == "Reference" then
			local line = color(stringify.stringifyRule(stack[i].op, --
			function(op, formatted)
				if op == highlight then
					return color(formatted):fg({0, 0, 0}):bg(highlightColor)
				else
					return formatted
				end
			end))

			local mark1, mark2
			local hlBefore = false
			for pos, char in ipairs(line.txt) do
				local hl = char.bg == highlightColor
				if hl and not hlBefore then
					mark1 = pos
				elseif hlBefore and not hl then
					mark2 = pos - 1
				end
				hlBefore = hl
			end

			table.insert(lines, line)
			table.insert(marks, {mark1, mark2})

			if i > 1 then
				highlight = stack[i - 1].op
				highlightColor = {255, 192, 0}
			end
		end
	end

	for i = 1, #lines do
		dsp.renderLine(buffer, #lines - i + 1, lines[i], marks[i][1], marks[i][2])
	end
	table.insert(buffer, "\n")

end

_G.installDebugHooks = function(op)
	local parse = op.parse
	op.parse = function(src, pos, ctx)

		table.insert(stack, {op = op, pos = pos, ctx = ctx})

		local from = pos or 1
		local colorText = color(src)
		colorText:from(from):take(1):fg({0, 0, 0}):bg({255, 192, 0})

		local buffer = {}
		dsp.render(buffer, colorText, from, from)
		renderStack(buffer)
		io.write(table.concat(buffer))
		pause()

		local len, vals = parse(src, pos, ctx)

		colorText = color(src)
		local to
		if len == opf.Rejected then
			to = from
			colorText:fromTo(from, to):fg({0, 0, 0}):bg({255, 0, 0})
		else
			to = from + len - 1
			colorText:fromTo(from, to):fg({0, 0, 0}):bg({0, 221, 0})
		end

		buffer = {}
		dsp.render(buffer, colorText, from, to)
		renderStack(buffer, len)
		io.write(table.concat(buffer))
		pause()

		table.remove(stack)

		return len, vals
	end
	return op
end
