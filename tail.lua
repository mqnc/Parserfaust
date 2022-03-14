function caller(a)
	local c = callee(a + 1)
	return callee(a + 2)
end

function callee(b)
	return b
end

function inspect(kind)
	print(kind, debug.getinfo(2).name, debug.getinfo(2).linedefined)

	local i = 1
	while true do
		local n, v = debug.getlocal(2, i)
		if not n then
			break
		end
		if n ~= "(temporary)" then
			print(n, v)
		end
		i = i + 1
	end
end

debug.sethook(inspect, "cr")
q = caller(6)
