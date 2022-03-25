local colorSpace = {}

function colorSpace.RGB_to_sRGB(R, G, B)
	-- https://en.wikipedia.org/wiki/SRGB#From_CIE_XYZ_to_sRGB

	RGB = {R, G, B}
	local sRGB = {}
	for i = 1, 3 do
		if RGB[i] <= 0.0031308 then
			sRGB[i] = 12.92 * RGB[i]
		else
			sRGB[i] = 1.055 * RGB[i] ^ (1.0 / 2.4) - 0.055
		end
		sRGB[i] = math.floor(255 * sRGB[i] + 0.5)
		if sRGB[i] < 0 then
			sRGB[i] = 0
		elseif sRGB[i] > 255 then
			sRGB[i] = 255
		end
	end
	return table.unpack(sRGB)
end

function colorSpace.XYZ_to_RGB(X, Y, Z)
	-- https://en.wikipedia.org/wiki/SRGB#From_CIE_XYZ_to_sRGB

	local R = 3.2406 * X - 1.5372 * Y - 0.4986 * Z
	local G = -0.9689 * X + 1.8758 * Y + 0.0415 * Z
	local B = 0.0557 * X - 0.2040 * Y + 1.0570 * Z

	return R, G, B
end

function colorSpace.xyY_to_XYZ(x, y, Y)
	-- https://en.wikipedia.org/wiki/CIE_1931_color_space#CIE_xy_chromaticity_diagram_and_the_CIE_xyY_color_space

	local X = Y / y * x
	local Z = Y / y * (1 - x - y)

	return X, Y, Z
end

function colorSpace.OKLab_to_RGB(L, a, b)
	-- https://bottosson.github.io/posts/oklab/

	local l_ = L + 0.3963377774 * a + 0.2158037573 * b;
	local m_ = L - 0.1055613458 * a - 0.0638541728 * b;
	local s_ = L - 0.0894841775 * a - 1.2914855480 * b;

	local l = l_ * l_ * l_;
	local m = m_ * m_ * m_;
	local s = s_ * s_ * s_;

	local R = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	local G = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	local B = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

	return R, G, B
end

function colorSpace.OKLCh_to_OKLab(L, C, h)
	return L, C * math.cos(h), C * math.sin(h)
end

return colorSpace
