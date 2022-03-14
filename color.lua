local DEFAULT_FG_COLOR = {221, 221, 221}
local DEFAULT_BG_COLOR = {0, 0, 0}

local color
local colorTextMt

local isColorTxt = function(txt)
	return type(txt) == "table" and getmetatable(txt) == colorTextMt
end

colorTextMt = {

	clone = function(self)
		local result = { --
			txt = {},
			viewPos = self.viewPos,
			viewLen = self.viewLen
		}
		for _, char in ipairs(self.txt) do
			table.insert(result.txt, {chr = char.chr, fg = char.fg, bg = char.bg})
		end
		setmetatable(result, colorTextMt)
		return result
	end,

	fromTo = function(self, from, to)
		local result = { --
			txt = self.txt,
			viewPos = self.viewPos + from - 1,
			viewLen = to - from + 1
		}
		setmetatable(result, colorTextMt)
		return result
	end,

	from = function(self, from)
		return self:fromTo(from, self.viewLen - from + 1)
	end,

	take = function(self, len)
		return self:fromTo(1, len)
	end,

	fg = function(self, rgb)
		for i = self.viewPos, self.viewPos + self.viewLen - 1 do
			self.txt[i].fg = rgb
		end
		return self
	end,

	bg = function(self, rgb)
		for i = self.viewPos, self.viewPos + self.viewLen - 1 do
			self.txt[i].bg = rgb
		end
		return self
	end,

	__len = function(self)
		return self.viewLen
	end,

	__tostring = function(self)

		local result = {}

		local ansiSeq = function(sgr, rgb)
			return table.concat({"\027[", sgr, ";2;", table.concat(rgb, ";"), "m"})
		end

		local lastFgAnsi
		local lastBgAnsi
		for i = self.viewPos, self.viewPos + self.viewLen - 1 do
			local colChar = self.txt[i]
			local fg = colChar.fg
			local bg = colChar.bg
			if colChar.chr == "\n" then
				fg = DEFAULT_FG_COLOR
				bg = DEFAULT_BG_COLOR
			end
			local fgAnsi = ansiSeq(38, fg)
			local bgAnsi = ansiSeq(48, bg)
			if fgAnsi ~= lastFgAnsi then
				table.insert(result, fgAnsi)
				lastFgAnsi = fgAnsi
			end
			if bgAnsi ~= lastBgAnsi then
				table.insert(result, bgAnsi)
				lastBgAnsi = bgAnsi
			end
			table.insert(result, colChar.chr)
		end
		table.insert(result, ansiSeq(38, DEFAULT_FG_COLOR))
		table.insert(result, ansiSeq(48, DEFAULT_BG_COLOR))

		return table.concat(result)
	end,

	__concat = function(txt1, txt2)
		local result = {txt = {}}
		setmetatable(result, colorTextMt)
		for _, txt in ipairs({txt1, txt2}) do
			txt = color(txt)
			for _, colChar in ipairs(txt.txt) do
				table.insert(result.txt, colChar)
			end
		end
		result.viewPos = 1
		result.viewLen = #result.txt
		return result
	end

}
colorTextMt.__index = colorTextMt

color = function(txt)
	if isColorTxt(txt) then
		return txt
	end

	txt = tostring(txt)

	local result = {txt = {}}
	setmetatable(result, colorTextMt)
	for i = 1, utf8.len(txt) do
		table.insert(result.txt, { --
			chr = txt:sub(utf8.offset(txt, i), utf8.offset(txt, i + 1) - 1),
			fg = DEFAULT_FG_COLOR,
			bg = DEFAULT_BG_COLOR
		})
	end
	result.viewPos = 1
	result.viewLen = #result.txt
	return result
end

return color
