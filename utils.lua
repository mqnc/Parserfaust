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

return utils
