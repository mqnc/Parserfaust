local DEFAULT_FG_COLOR = {224, 224, 224}
local DEFAULT_BG_COLOR = {0, 0, 0}

local colorText
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
			table.insert(result.txt, { --
				chr = char.chr,
				fg = char.fg,
				bg = char.bg,
				tag = char.tag
			})
		end
		setmetatable(result, colorTextMt)
		return result
	end,

	range = function(self, first, past)
		assert(first >= 1 and first <= 1 + self.viewLen)
		assert(past >= first and past <= 1 + self.viewLen)
		local result = { --
			txt = self.txt,
			viewPos = self.viewPos + first - 1,
			viewLen = past - first
		}
		setmetatable(result, colorTextMt)
		return result
	end,

	__index = function(self, index)
		return self.range(index, index + 1)
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

	tag = function(self, userData)
		for i = self.viewPos, self.viewPos + self.viewLen - 1 do
			self.txt[i].tag = userData
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
			local fg = colChar.fg or DEFAULT_FG_COLOR
			local bg = colChar.bg or DEFAULT_BG_COLOR
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
			txt = colorText(txt)
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

colorText = function(txt)
	if isColorTxt(txt) then
		return txt
	end

	txt = tostring(txt)

	local result = {txt = {}}
	setmetatable(result, colorTextMt)
	for i = 1, utf8.len(txt) do
		table.insert(result.txt, { --
			chr = txt:sub(utf8.offset(txt, i), utf8.offset(txt, i + 1) - 1)
		})
	end
	result.viewPos = 1
	result.viewLen = #result.txt
	return result
end

return colorText
