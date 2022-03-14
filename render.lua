local color = require "color"

local LINES = 24
local COLUMNS = 80

local LINES_AROUND_HIGHLIGHT_BEGIN = LINES // 3
local LINES_BEFORE_HIGHLIGHT_BEGIN = LINES_AROUND_HIGHLIGHT_BEGIN // 2
local LINESEP1 = "          ···\n"
local LINES_SEP1 = 1
local LINES_AROUND_HIGHLIGHT_END = LINES // 3
local LINES_BEFORE_HIGHLIGHT_END = LINES_AROUND_HIGHLIGHT_END // 2
local LINESEP2 = --
"================================================================================\n"
local LINES_SEP2 = 1
local LINES_INPUT = 1
local LINES_STACK = LINES --
- LINES_AROUND_HIGHLIGHT_BEGIN --
- LINES_SEP1 --
- LINES_AROUND_HIGHLIGHT_END --
- LINES_SEP2 --
- LINES_INPUT

local COLUMNS_LINE_NUMBER = 3
local COLUMNSEP1 = " "
local COLUMNS_SEP1 = utf8.len(COLUMNSEP1)
local COLUMNS_AROUND_HIGHLIGHT_BEGIN = COLUMNS // 3
local COLUMNS_BEFORE_HIGHLIGHT_BEGIN = COLUMNS_AROUND_HIGHLIGHT_BEGIN // 3
local COLUMNSEP2 = "…"
local COLUMNS_SEP2 = utf8.len(COLUMNSEP2)
local COLUMNS_AROUND_HIGHLIGHT_END = COLUMNS --
- COLUMNS_LINE_NUMBER --
- COLUMNS_SEP1 --
- COLUMNS_AROUND_HIGHLIGHT_BEGIN --
- utf8.len(COLUMNSEP2)
local COLUMNS_BEFORE_HIGHLIGHT_END = COLUMNS_AROUND_HIGHLIGHT_END // 2

local dsp = {}

local calcWindows = function(inputLen, -- complete length of text
		mark1, -- first important position
		window1, -- size of window around mark1
		offset1, -- position of mark1 in window1
		sep, -- length of separator in case windows are split
		mark2, -- second important position
		window2, -- size of window around mark2
		offset2 -- position of mark1 in window1
)

	if mark1 == nil and mark2 == nil then -- nothing marked
		return 1, inputLen, nil, nil
	elseif mark1 == nil then -- mark from begin until mark2
		mark1 = 1
	elseif mark2 == nil then -- mark from mark1 until end
		mark2 = inputLen
	end

	if inputLen <= window1 + sep + window2 then -- render complete text
		return 1, inputLen, nil, nil
	end

	local posWin1 = math.max(mark1 - offset1, 1)
	local posWin2 = math.min(mark2 - offset2, inputLen - window2)

	if posWin2 <= posWin1 + window1 + sep then -- combine windows
		return posWin1, window1 + sep + window2, nil, nil
	else
		return posWin1, window1, posWin2, window2
	end
end

local filterInPlace = function(colTxt)
	local map = {["\t"] = "→", ["\r"] = "←", ["\n"] = "↵", [" "] = "·"}
	for _, colChar in ipairs(colTxt.txt) do
		local mapped = map[colChar.chr]
		if mapped ~= nil then
			colChar.chr = mapped
		end
	end
end

dsp.renderLine = function(buffer, index, colTxt, markStart, markEnd)

	local lineNumber = color( --
	string.format("%" .. tostring(COLUMNS_LINE_NUMBER) .. "d", index))

	local adjustedWin1 = COLUMNS_AROUND_HIGHLIGHT_BEGIN + COLUMNS_LINE_NUMBER - #lineNumber

	local p1, l1, p2, l2 = calcWindows(#colTxt, --
	markStart, adjustedWin1, COLUMNS_BEFORE_HIGHLIGHT_BEGIN, --
	COLUMNS_SEP2, --
	markEnd, COLUMNS_AROUND_HIGHLIGHT_END, COLUMNS_BEFORE_HIGHLIGHT_END)

	table.insert(buffer, tostring(lineNumber))
	table.insert(buffer, tostring(COLUMNSEP1))
	local part1 = colTxt:clone():from(p1):take(l1)
	filterInPlace(part1)
	table.insert(buffer, tostring(part1))
	if p2 ~= nil then
		local part2 = colTxt:clone():from(p2):take(l2)
		filterInPlace(part2)
		table.insert(buffer, tostring(part2))
	end
	table.insert(buffer, "\n")
end

dsp.render = function(buffer, colTxt, markStart, markEnd)
	local lines = {}
	local startOfLine = 1
	local lineMarkStart
	local lineMarkEnd
	local columnMarkStart
	local columnMarkEnd

	for i, colChar in ipairs(colTxt.txt) do
		if i == markStart then
			lineMarkStart = #lines + 1
			columnMarkStart = i - startOfLine + 1
		end
		if i == markEnd then
			lineMarkEnd = #lines + 1
			columnMarkEnd = i - startOfLine + 1
		end
		if colChar.chr == "\n" or i == #colTxt.txt then
			table.insert(lines, colTxt:fromTo(startOfLine, i))
			startOfLine = i + 1
		end
	end

	local p1, l1, p2, l2 = calcWindows(#lines, -- 
	lineMarkStart, -- 
	LINES_AROUND_HIGHLIGHT_BEGIN, -- 
	LINES_BEFORE_HIGHLIGHT_BEGIN, --
	LINES_SEP1, --
	lineMarkEnd, -- 
	LINES_AROUND_HIGHLIGHT_END, -- 
	LINES_BEFORE_HIGHLIGHT_END)

	for i = p1, p1 + l1 - 1 do
		local s, e
		if i == lineMarkStart then
			s = columnMarkStart
		end
		if i == lineMarkEnd then
			e = columnMarkEnd
		end
		dsp.renderLine(buffer, i, lines[i], s, e)
	end
	if p2 ~= nil then
		table.insert(buffer, tostring(LINESEP1))
		for i = p2, p2 + l2 - 1 do
			local s, e
			if i == lineMarkStart then
				s = columnMarkStart
			end
			if i == lineMarkEnd then
				e = columnMarkEnd
			end
			dsp.renderLine(buffer, i, lines[i], s, e)
		end
	end
end

for _ = 1, LINES do
	print(color("\n"))
end

return dsp
