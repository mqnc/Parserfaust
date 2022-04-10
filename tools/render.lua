local colorText = require "colortext"

local LINES = 24
local COLUMNS = 80
local COLUMNS_LINE_NUMBER = 3

local LINES_AROUND_HIGHLIGHT_FIRST = LINES // 3
local LINES_BEFORE_HIGHLIGHT_FIRST = LINES_AROUND_HIGHLIGHT_FIRST // 2
local V_ELLIPSIS = "⋮"
local V_ELLIPSIS_HEIGHT = 1
local LINES_AROUND_HIGHLIGHT_PAST = LINES // 3
local LINES_BEFORE_HIGHLIGHT_PAST = LINES_AROUND_HIGHLIGHT_PAST // 2
local LINE_SEPARATOR =
string.rep("─", COLUMNS_LINE_NUMBER) .. "┼"
.. string.rep("─", COLUMNS - COLUMNS_LINE_NUMBER - 1)
local LINE_SEPARATOR_HEIGHT = 1
local LINES_INPUT = 1
local LINES_STACK = LINES
- LINES_AROUND_HIGHLIGHT_FIRST
- LINES_AROUND_HIGHLIGHT_PAST
- LINE_SEPARATOR_HEIGHT
- LINES_INPUT

local COLUMN_SEPARATOR = "│"
local COLUMN_SEPARATOR_WIDTH = utf8.len(COLUMN_SEPARATOR)
local COLUMNS_AROUND_HIGHLIGHT_FIRST = COLUMNS // 3
local COLUMNS_BEFORE_HIGHLIGHT_FIRST = COLUMNS_AROUND_HIGHLIGHT_FIRST // 3
local H_ELLIPSIS = colorText("…"):bg({128, 128, 128}):fg({255, 255, 0})
local H_ELLIPSIS_WHIDTH = #H_ELLIPSIS
local COLUMNS_AROUND_HIGHLIGHT_PAST = COLUMNS
- COLUMNS_LINE_NUMBER
- COLUMN_SEPARATOR_WIDTH
- COLUMNS_AROUND_HIGHLIGHT_FIRST
local COLUMNS_BEFORE_HIGHLIGHT_PAST = COLUMNS_AROUND_HIGHLIGHT_PAST // 2

local renderer = {}

local function clamp(val, min, max)
	return math.min(math.max(val, min), max)
end

local function combineViews(inputLen, -- complete length of input text
		focus1, -- first important position
		window1, -- size of window around focus1
		offset1, -- position of focus1 in window1
		ellipsis, -- length of ellipsis symbol
		focus2, -- second important position
		window2, -- size of window around focus2
		offset2 -- position of focus2 in window2
)

	local maxOutputLen = window1 + window2

	if inputLen <= maxOutputLen then -- show complete text
		return 0, 1, 1 + inputLen, 0, 1 + inputLen, 1 + inputLen, 0
	end

	if focus1 == nil and focus2 == nil then
		focus1 = 1
		focus2 = 1
	elseif focus1 == nil then
		focus1 = focus2
	elseif focus2 == nil then
		focus2 = focus1
	end

	local first1 = math.max(focus1 - offset1, 1)
	local past1 = math.min(first1 + window1, 1 + inputLen)
	first1 = math.max(past1 - window1, 1)

	local first2 = math.max(focus2 - offset2, 1)
	local past2 = math.min(first2 + window2, 1 + inputLen)
	first2 = math.max(past2 - window2, 1)

	local firstFirst = math.min(first1, first2)
	local secondFirst = math.max(first1, first2)
	local firstPast = math.min(past1, past2)
	local lastPast = math.max(past1, past2)

	if secondFirst <= firstPast then -- merge intervals
		local rest = maxOutputLen - (lastPast - firstFirst)
		firstFirst = math.max(firstFirst - rest // 2, 1)
		lastPast = math.min(firstFirst + maxOutputLen, 1 + inputLen)
		firstFirst = lastPast - maxOutputLen

		local elliStart = (firstFirst ~= 1) and ellipsis or 0
		firstFirst = firstFirst + elliStart
		local elliEnd = (lastPast ~= 1 + inputLen) and ellipsis or 0
		lastPast = lastPast - elliEnd

		assert(elliStart + (lastPast - firstFirst) + elliEnd
		== maxOutputLen)
		assert(firstFirst - elliStart >= 1)
		assert(lastPast + elliEnd <= 1 + inputLen)

		return elliStart, firstFirst, lastPast, 0, lastPast, lastPast, elliEnd
	else
		local elliStart = (firstFirst ~= 1) and ellipsis or 0
		firstFirst = firstFirst + elliStart
		local elliMiddle = ellipsis
		firstPast = firstPast - elliMiddle // 2
		secondFirst = secondFirst + (elliMiddle - elliMiddle // 2)
		local elliEnd = (lastPast ~= 1 + inputLen) and ellipsis or 0
		lastPast = lastPast - elliEnd

		assert(elliStart + (firstPast - firstFirst) + elliMiddle
		+ (lastPast - secondFirst) + elliEnd
		== maxOutputLen)
		assert(firstFirst - elliStart >= 1)
		assert(lastPast + elliEnd <= 1 + inputLen)

		return elliStart, firstFirst, firstPast, elliMiddle, secondFirst, lastPast, elliEnd
	end

end

local function filterInPlace(colTxt)
	local map = {["\t"] = "→", ["\r"] = "←", ["\n"] = "↵", [" "] = "·"}
	for _, colChar in ipairs(colTxt.txt) do
		local mapped = map[colChar.chr]
		if mapped ~= nil then
			colChar.chr = mapped
			colChar.fg = {128, 128, 128}
		end
	end
end

function renderer.renderSeparator(buffer)
	table.insert(buffer, tostring(LINE_SEPARATOR) .. "\n")
end

function renderer.getNumColumns()
	return COLUMNS
end

function renderer.getNumStackLines()
	return LINES_STACK
end

function renderer.renderLine(buffer, index, colTxt, markFirst, markPast, fill)

	local lineNumber
	if type(index) == "number" then
		lineNumber = colorText(
		string.format("%" .. tostring(COLUMNS_LINE_NUMBER) .. "d", index))
		:fg({255, 255, 0})
	elseif type(index) == "string" then
		lineNumber = colorText(string.rep(" ", COLUMNS_LINE_NUMBER - utf8.len(index)) .. index)
	elseif index == nil then
		lineNumber = colorText(string.rep(" ", COLUMNS_LINE_NUMBER))
	end

	table.insert(buffer, tostring(lineNumber))
	table.insert(buffer, tostring(COLUMN_SEPARATOR))

	if colTxt == nil then
		table.insert(buffer, "\n")
		return
	end

	local adjustedWin1 = COLUMNS_AROUND_HIGHLIGHT_FIRST + COLUMNS_LINE_NUMBER - #lineNumber

	local elliStart, first1, past1, elliMiddle, first2, past2, elliEnd =
	combineViews(#colTxt,
	markFirst,
	adjustedWin1,
	COLUMNS_BEFORE_HIGHLIGHT_FIRST,
	H_ELLIPSIS_WHIDTH,
	markPast,
	COLUMNS_AROUND_HIGHLIGHT_PAST,
	COLUMNS_BEFORE_HIGHLIGHT_PAST)

	if elliStart > 0 then
		table.insert(buffer, tostring(H_ELLIPSIS))
	end
	local part1 = colTxt:clone():range(first1, past1)
	filterInPlace(part1)
	table.insert(buffer, tostring(part1))
	if elliMiddle > 0 then
		table.insert(buffer, tostring(H_ELLIPSIS))
	end
	local part2 = colTxt:clone():range(first2, past2)
	filterInPlace(part2)
	table.insert(buffer, tostring(part2))
	if elliEnd > 0 then
		table.insert(buffer, tostring(H_ELLIPSIS))
	end

	if fill then
		local spacer = string.rep(" ",
		COLUMNS - #lineNumber - COLUMN_SEPARATOR_WIDTH - elliStart - #part1
		- elliMiddle - #part2 - elliEnd)
		table.insert(buffer, tostring(colorText(spacer):bg(fill)))
	end

	table.insert(buffer, "\n")
end

function renderer.render(buffer, colTxt, markFirst, markPast)

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
	if lineMarkEnd == nil then
		lineMarkEnd = 1 + #lines
	end

	local elliStart, first1, past1, elliMiddle, first2, past2, elliEnd =
	combineViews(#lines,
	lineMarkStart,
	LINES_AROUND_HIGHLIGHT_FIRST,
	LINES_BEFORE_HIGHLIGHT_FIRST,
	V_ELLIPSIS_HEIGHT,
	lineMarkEnd + 1,
	LINES_AROUND_HIGHLIGHT_PAST,
	LINES_BEFORE_HIGHLIGHT_PAST)

	if elliStart > 0 then
		renderer.renderLine(buffer, V_ELLIPSIS)
	end

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

	if elliMiddle > 0 then
		renderer.renderLine(buffer, V_ELLIPSIS)
	end

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

	if elliEnd > 0 then
		renderer.renderLine(buffer, V_ELLIPSIS)
	end

end

return renderer
