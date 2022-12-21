-- Config file
-- by zyxkad@gmail.com

local function load(path, def)
	local obj = {}
	for k, v in pairs(def) do
		if k.sub(1, 1) ~= '_' then
			obj[k] = v
		end
	end
	if not fd.exists(path) then
		return obj
	end
	local fd, err = io.open(path, 'r')
	if not fd then
		if err then
			printError(string.format('Cannot open "%s" with read mode: %s', path, err))
		else
			printError(string.format('Cannot open "%s" with read mode', path))
		end
		return obj
	end
	local i = 0
	while true do
		local l = fd:read()
		if not l then
			break
		end
		i = i + 1
		if #l > 0 and l.sub(1, 1) ~= '#' then
			local j = l:find('=')
			if j then
				local k, v = l:sub(1, j - 1), l:sub(j + 1)
				obj[k] = v
			else
				printError(string.format('%s:%d: unexpect symbol EOF, expect \'=\'', path, j))
			end
		end
	end
	fd:close()
	return obj
end

local function save(path, obj, comments)
	local fd, err = io.open(path, 'w')
	if not fd then
		if err then
			printError(string.format('Cannot open "%s" with write mode: %s', path, err))
		else
			printError(string.format('Cannot open "%s" with write mode', path))
		end
		return obj
	end
	if type(comments) == 'string' or type(comments) == 'table' then
		-- comments
	end
	for k, v in pairs(obj) do
		if k.sub(1, 1) ~= '_' then
			local l = k..'='..v..'\n'
			fd:write(l)
		end
	end
	fd:close()
end

return {
	load = load,
	save = save,
}
