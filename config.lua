-- Config file
-- by zyxkad@gmail.com

local function load(path, def)
	if not fs.exists(path) then
		return nil, 'Config file not exists'
	end
	local fd, err = io.open(path, 'r')
	if not fd then
		local msg
		if err then
			msg = string.format('Cannot open "%s" with read mode: %s', path, err)
		else
			msg = string.format('Cannot open "%s" with read mode', path)
		end
		return nil, msg
	end
	local obj = {}
	if def then
		for k, v in pairs(def) do
			if k:sub(1, 1) ~= '_' then
				obj[k] = v
			end
		end
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
				if def and def[k] ~= nil then
					local t = type(def[k])
					if t == 'string' then
						v = tostring(v)
					elseif t == 'number' then
						v = tonumber(v)
					elseif t == 'boolean' then
						if v == 'true' then
							v = true
						else
							v = false
						end
					end
				end
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
		local msg
		if err then
			msg = string.format('Cannot open "%s" with write mode: %s', path, err)
		else
			msg = string.format('Cannot open "%s" with write mode', path)
		end
		return false, msg
	end
	if type(comments) == 'string' or type(comments) == 'table' then
		-- TODO: comments
	end
	local lines = {}
	for k, v in pairs(obj) do
		if k:sub(1, 1) ~= '_' then
			local l = k..'='..tostring(v)..'\n'
			lines[#lines + 1] = {k, l}
		end
	end
	table.sort(lines, function(a, b) return a[1] < b[1] end)
	for _, l in ipairs(lines) do
		fd:write(l[2])
	end
	fd:close()
	return true
end

return {
	load = load,
	save = save,
}
