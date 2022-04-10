local fileio = {}

function fileio.readFile(path)
	local file = io.open(path, "r")
	local data = file:read("*a")
	file:close()
	return data
end

function fileio.writeFile(path, data)
	local file = io.open(path, "w")
	file:write(data)
	file:close()
end

return fileio
