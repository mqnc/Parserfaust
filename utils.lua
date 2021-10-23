local utils = {}

function utils.stringStream()
	local ss = {}

	ss.append = function(...)
		for _, v in ipairs({...}) do
			table.insert(ss, v)
		end
	end

	ss.concat = function(filter, sep)
		if filter == nil then
			return table.concat(ss, sep)
		else
			local result = {}
			for i, v in ipairs(ss) do
				result[i] = filter(v)
			end
			return table.concat(result, sep)
		end
	end

	return ss
end

function utils.readFile(path)
	local file = io.open(path, "r")
	local data = file:read("*a")
	file:close()
	return data
end

function utils.writeFile(path, data)
	local file = io.open(path, "w")
	file:write(data)
	file:close()
end

function utils.forward(...)
	return ...
end

function utils.nop(...)
end

local proxyMt = {
	__index = function(t, k)
		return t.__raw[k]
	end,
	__newindex = function(t, k, v)
		t.__raw[k] = v
	end
}
function utils.proxyfy(raw, proxy)
	proxy.__raw = raw
	setmetatable(proxy, proxyMt)
end

function utils.copyTable(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

return utils
