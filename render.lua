local colorText = require "colortext"

local LINES = 24
local COLUMNS = 80

local LINES_AROUND_HIGHLIGHT_FIRST = LINES // 3
local LINES_BEFORE_HIGHLIGHT_FIRST = LINES_AROUND_HIGHLIGHT_FIRST // 2
local V_ELLIPSIS = "          ···\n"
local V_ELLIPSIS_HEIGHT = 1
local LINES_AROUND_HIGHLIGHT_PAST = LINES // 3
local LINES_BEFORE_HIGHLIGHT_PAST = LINES_AROUND_HIGHLIGHT_PAST // 2
local LINE_SEPARATOR = --
"================================================================================"
local LINE_SEPARATOR_HEIGHT = 1
local LINES_INPUT = 1
local LINES_STACK = LINES --
- LINES_AROUND_HIGHLIGHT_FIRST --
- 3 * V_ELLIPSIS_HEIGHT --
- LINES_AROUND_HIGHLIGHT_PAST --
- LINE_SEPARATOR_HEIGHT --
- LINES_INPUT

local COLUMNS_LINE_NUMBER = 3
local COLUMN_SEPARATOR = " "
local COLUMN_SEPARATOR_WIDTH = utf8.len(COLUMN_SEPARATOR)
local COLUMNS_AROUND_HIGHLIGHT_FIRST = COLUMNS // 3
local COLUMNS_BEFORE_HIGHLIGHT_FIRST = COLUMNS_AROUND_HIGHLIGHT_FIRST // 3
local H_ELLIPSIS = "…"
local H_ELLIPSIS_WHIDTH = utf8.len(H_ELLIPSIS)
local COLUMNS_AROUND_HIGHLIGHT_PAST = COLUMNS --
- COLUMNS_LINE_NUMBER --
- COLUMN_SEPARATOR_WIDTH --
- COLUMNS_AROUND_HIGHLIGHT_FIRST --
- 3 * H_ELLIPSIS_WHIDTH
local COLUMNS_BEFORE_HIGHLIGHT_PAST = COLUMNS_AROUND_HIGHLIGHT_PAST // 2

local renderer = {}

local clamp = function(val, min, max)
	return math.min(math.max(val, min), max)
end

local combineViews = function(inputLen, -- complete length of input text
		focus1, -- first important position
		window1, -- size of window around focus1
		offset1, -- position of focus1 in window1
		ellipsis, -- length of ellipsis symbol
		focus2, -- second important position
		window2, -- size of window around focus2
		offset2 -- position of focus2 in window2
)
	local maxOutputLen = ellipsis + window1 + ellipsis + window2 + ellipsis

	if inputLen <= maxOutputLen then -- show complete text
		return 1, 1 + inputLen, nil, nil
	end

	local first1 = math.max(focus1 - offset1, 1)
	local past1 = math.min(first1 + window1, inputLen)
	first1 = past1 - window1
	local first2 = math.max(focus2 - offset2, past1 + ellipsis)
	local past2 = math.min(first2 + window2, inputLen)
	first2 = past2 - window2

	if first1 <= 1 + ellipsis then
		-- no ellipsis in the beginning, extend window1 to beginning
		first1 = 1
	end
	if past2 >= 1 + inputLen - ellipsis then
		-- no ellipsis in the end, extend window2 to end
		past2 = 1 + inputLen
	end

	if past1 + ellipsis >= first2 then -- combine windows
		return first1, past2, nil, nil
	else
		return first1, past1, first2, past2
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

dbg = 0
renderer.renderLine = function(buffer, index, colTxt, markFirst, markPast)
	dbg = dbg + 1

	local lineNumber = colorText( --
	string.format("%" .. tostring(COLUMNS_LINE_NUMBER) .. "d", index))

	local adjustedWin1 = COLUMNS_AROUND_HIGHLIGHT_FIRST + COLUMNS_LINE_NUMBER - #lineNumber

	local first1, past1, first2, past2 = combineViews(#colTxt, --
	markFirst, adjustedWin1, COLUMNS_BEFORE_HIGHLIGHT_FIRST, --
	H_ELLIPSIS_WHIDTH, --
	markPast, COLUMNS_AROUND_HIGHLIGHT_PAST, COLUMNS_BEFORE_HIGHLIGHT_PAST)

	table.insert(buffer, tostring(lineNumber))
	table.insert(buffer, tostring(COLUMN_SEPARATOR))

	if first1 ~= 1 then
		table.insert(buffer, tostring(H_ELLIPSIS))
	end

	local part1 = colTxt:clone():range(first1, past1)
	filterInPlace(part1)
	table.insert(buffer, tostring(part1))
	if first2 == nil then
		if past1 < 1 + #colTxt then
			table.insert(buffer, tostring(H_ELLIPSIS))
		end
	else
		table.insert(buffer, tostring(H_ELLIPSIS))
		local part2 = colTxt:clone():range(first2, past2)
		filterInPlace(part2)
		table.insert(buffer, tostring(part2))

		if past2 < 1 + #colTxt then
			table.insert(buffer, tostring(H_ELLIPSIS))
		end
	end
	table.insert(buffer, "\n")
end

renderer.render = function(buffer, colTxt, markFirst, markPast)

	colTxt = colorText(colTxt)

	-- get line and column from start and end of highlighting
	local lines = {}
	local startOfLine = 1
	local lineMarkStart
	local lineMarkEnd
	local columnMarkStart
	local columnPastMarkEnd

	for i, colChar in ipairs(colTxt.txt) do
		if i == markFirst then
			lineMarkStart = 1 + #lines
			columnMarkStart = 1 + i - startOfLine
		end
		if i == markPast then
			lineMarkEnd = 1 + #lines
			columnPastMarkEnd = 1 + i - startOfLine
		end
		if colChar.chr == "\n" or i == #colTxt.txt then
			table.insert(lines, colTxt:range(startOfLine, i + 1))
			startOfLine = i + 1
		end
	end

	local first1, past1, first2, past2 = combineViews(#lines, -- 
	lineMarkStart, -- 
	LINES_AROUND_HIGHLIGHT_FIRST, -- 
	LINES_BEFORE_HIGHLIGHT_FIRST, --
	V_ELLIPSIS_HEIGHT, --
	lineMarkEnd + 1, -- 
	LINES_AROUND_HIGHLIGHT_PAST, -- 
	LINES_BEFORE_HIGHLIGHT_PAST)

	for i = first1, past1 - 1 do
		local f, p
		if i == lineMarkStart then
			f = columnMarkStart
		end
		if i == lineMarkEnd then
			p = columnPastMarkEnd
		end
		renderer.renderLine(buffer, i, lines[i], f, p)
	end
	if first2 ~= nil then
		table.insert(buffer, tostring(V_ELLIPSIS))
		for i = first2, past2 - 1 do
			local f, p
			if i == lineMarkStart then
				f = columnMarkStart
			end
			if i == lineMarkEnd then
				p = columnPastMarkEnd
			end
			renderer.renderLine(buffer, i, lines[i], f, p)
		end
	end
end

for _ = 1, LINES do
	print(colorText("\n"))
end

return renderer
