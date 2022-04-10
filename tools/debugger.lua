local stringify = require "pegstringify"
local opf = require "opfactory"
local dsp = require "render"
local colorText = require "colortext"
local colorSpace = require "colorspace"

local FG_COLOR_SELECTED = {0, 64, 255}
local BG_COLOR_SELECTED = {255, 255, 255}
local FG_COLOR_ACCEPTED = {0, 64, 0}
local BG_COLOR_ACCEPTED = {128, 255, 160}
local FG_COLOR_REJECTED = {96, 0, 0}
local BG_COLOR_REJECTED = {255, 160, 160}

local function breakPoint(step, src, pos, ln, col, ctx, stack, inside, ref, match, vals)
	return true
end

local function processUserInput()

	::retry::
	io.write("break if: ")
	local userInput = io.read()
	print("")

	if userInput == "" then
		return
	elseif userInput == "q" then
		print("terminated")
		os.exit(0)
	else
		local before = "function(step, src, pos, ln, col, ctx, stack, inside, ref, match, vals)\n\treturn "
		local after = "\nend"

		local code = "return " .. before .. userInput .. after
		local breakPointFactory, err = --
		load(code, "user-defined break condition")
		if breakPointFactory == nil then
			print(code)
			print(err)
			goto retry -- oh yes I did
		else
			breakPoint = breakPointFactory()
		end
	end
end

local phi = (math.sqrt(5) + 1) / 2
local paletteCache = {}

local function palette(i)
	if paletteCache[i] == nil then
		local lumi = 0.5 + ((i + 1) % 2) * 0.1
		local chroma = 0.2
		local hue = i * phi * 2 * math.pi
		paletteCache[i] = { --
			colorSpace.RGB_to_sRGB( --
			colorSpace.OKLab_to_RGB( --
			colorSpace.OKLCh_to_OKLab(lumi, chroma, hue)))
		}
	end
	return paletteCache[i]
end

local function renderStack(buffer, stack, matchLen)

	local highlighted = stack[#stack].op
	local highlightTag = {"highlight"}

	local lines = {}
	local marks = {}
	local levels = {}

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
			table.insert(levels, i)

			if i > 1 then
				highlighted = stack[i - 1].op
			end
		end
	end

	for _ = 1, dsp.getNumStackLines() - #lines do
		dsp.renderLine(buffer)
	end

	for i, line in ipairs(lines) do
		local displayLevel = 1 + #lines - i
		local highlightBackground = palette(displayLevel + 1)
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

		line:fg({255, 255, 255}):bg(palette(displayLevel))
		line:range(marks[i][1], marks[i][2]):bg(highlightBackground):fg(highlightForeground)
		dsp.renderLine(buffer, levels[i], line, marks[i][1], marks[i][2], palette(displayLevel))
		if i >= dsp.getNumStackLines() then
			break
		end
	end

end

local function renderSnapshot(src, matchLen, stack)

	local pos = stack[#stack].pos

	local cText = colorText(src .. "∎")

	local level = 0
	for i, layer in ipairs(stack) do
		if i == 1 or stack[i - 1].op.__type[2] == "Reference" then
			level = level + 1
			cText:range(layer.pos, pos):fg({255, 255, 255}):bg(palette(level))
		end
	end

	local past
	if matchLen == nil then
		past = pos + 1
		cText:range(pos, past):fg(FG_COLOR_SELECTED):bg(BG_COLOR_SELECTED)
	elseif matchLen == opf.Rejected then
		past = pos + 1
		cText:range(pos, past):fg(FG_COLOR_REJECTED):bg(BG_COLOR_REJECTED)
	else
		past = pos + math.max(matchLen, 1)
		cText:range(pos, past):fg(FG_COLOR_ACCEPTED):bg(BG_COLOR_ACCEPTED)
	end

	local buffer = {}
	dsp.render(buffer, cText, pos, past)
	dsp.renderSeparator(buffer)
	renderStack(buffer, stack, matchLen)
	io.write(table.concat(buffer))

end

local lnColCache = {}
local function lnCol(src, pos)
	if lnColCache[src] == nil then
		lnColCache[src] = {}
	end
	if lnColCache[src][pos] == nil then
		local ln = 1
		local col = 1
		for i = 1, #src do
			local c = src:sub(i, i)
			if i == pos then
				return ln, col
			end
			col = col + 1
			if c == "\n" then
				ln = ln + 1
				col = 1
			end
		end
		lnColCache[src][pos] = {ln, col}
	end
	return table.unpack(lnColCache[src][pos])
end

local state

local function initState()
	assert(state == nil)
	state = { --
		stack = {},
		step = 0,
		furthest = { --
			stack = {},
			step = 0,
			pos = 0,
			len = 0
		}
	}
end

local function cleanupState()
	state = nil
end

function _G.installDebugHooks(op)
	local parse = op.parse
	function op.parse(src, pos, ctx)

		if state == nil then
			initState()
		end

		pos = pos or 1

		table.insert(state.stack, {op = op, pos = pos, ctx = ctx})

		local ref = nil
		local inside = {}
		if op.__type[2] == "Reference" then
			ref = op.ruleName
		end
		for _, layer in ipairs(state.stack) do
			if layer.op.__type[2] == "Reference" then
				inside[layer.op.ruleName] = true
			end
		end

		local ln, col = lnCol(src, pos)

		local function info(step, pos, msg)
			local ln, col = lnCol(src, pos)
			io.write("⏵" .. tostring(step) .. --
			" @" .. tostring(pos) .. --
			" (" .. tostring(ln) .. ":" .. tostring(col) .. "); ")
			if msg then
				print(msg)
			end
		end

		state.step = state.step + 1
		if breakPoint(state.step, src, pos, ln, col, ctx, --
		state.stack, inside, ref, nil, nil) then
			renderSnapshot(src, nil, state.stack)
			info(state.step, pos)
			processUserInput()
		end

		local len, vals = parse(src, pos, ctx)

		if pos >= state.furthest.pos then
			state.furthest.step = state.step
			state.furthest.pos = pos
			state.furthest.len = len
			state.furthest.stack = {}
			for _, layer in ipairs(state.stack) do
				table.insert(state.furthest.stack, --
				{op = layer.op, pos = layer.pos})
			end
		end

		local match
		if len == opf.Rejected then
			match = false
		else
			match = string.sub(src, pos, pos + len - 1)
		end

		state.step = state.step + 1
		if breakPoint(state.step, src, pos, ln, col, ctx, --
		state.stack, inside, ref, match, vals) then
			renderSnapshot(src, len, state.stack)
			info(state.step, pos)
			processUserInput()
		end

		table.remove(state.stack)

		if #state.stack == 0 then
			if len == #src then
				renderSnapshot(src, len, {{op = op, pos = pos}})
				info(state.step, pos, --
				colorText("Successfully parsed complete input!") --
				:fg(FG_COLOR_ACCEPTED):bg(BG_COLOR_ACCEPTED))
			elseif len ~= opf.Rejected then
				renderSnapshot(colorText(src) --
				:fg(BG_COLOR_REJECTED):bg(FG_COLOR_REJECTED), -- 
				len, {{op = op, pos = pos}})
				info(state.step, pos, --
				colorText("Successfully parsed part") --
				:fg(FG_COLOR_ACCEPTED):bg(BG_COLOR_ACCEPTED) .. colorText(" of input.") --
				:fg(BG_COLOR_REJECTED):bg(FG_COLOR_REJECTED))
			else
				renderSnapshot(src, state.furthest.len, state.furthest.stack)
				info(state.furthest.step, state.furthest.pos, --
				colorText("Parsing failed! See furthest advancement above.") --
				:fg(FG_COLOR_REJECTED):bg(BG_COLOR_REJECTED))
			end

			cleanupState()
		end

		return len, vals
	end
	return op
end
