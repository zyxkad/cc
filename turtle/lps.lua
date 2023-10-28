-- Local Positioning System
-- by zyxkad@gmail.com

local version = 1

if not turtle then
	error('LPS can only work on turtle', 1)
end

local turtle_forward = turtle.forward
local turtle_back = turtle.back
local turtle_up = turtle.up
local turtle_down = turtle.down
local turtle_turnLeft = turtle.turnLeft
local turtle_turnRight = turtle.turnRight

local lpsCacheName = '/lps.json'

local pos = nil
-- pos = {
-- 	x = 0,
-- 	y = 0,
-- 	z = 0,
-- 	f = facing,
-- 	v = version,
-- }

local function update(k, v)
	pos[k] = v
	local fd = fs.open(lpsCacheName, 'w')
	fd.write(textutils.serialiseJSON(pos))
	fd.close()
end

local function init(facing, x, y, z)
	if type(facing) ~= 'nil' and facing ~= '+x' and facing ~= '-x' and facing ~= '+z' and facing ~= '-z' then
		error('Invalid arg#1(facing): '..facing, 1)
	end

	local fd = fs.open(lpsCacheName, 'r')
	if fd then
		pos = textutils.unserialiseJSON(fd.readAll())
		if pos.v ~= version then
			error('Version '..pos.v..' is not supported, current version is '..version, 1)
		end
	else
		if facing == nil then
			return false
		end
		fd = fs.open(lpsCacheName, 'w')
		pos = {
			x = x or 0,
			y = y or 0,
			z = z or 0,
			f = facing,
			v = version,
		}
		fd.write(textutils.serialiseJSON(pos))
	end
	fd.close()

	turtle.forward = function()
		local res = {turtle_forward()}
		if res[1] then
			local f = pos.f
			if f == '+x' then
				update('x', pos.x + 1)
			elseif f == '-x' then
				update('x', pos.x - 1)
			elseif f == '+z' then
				update('z', pos.z + 1)
			elseif f == '-z' then
				update('z', pos.z - 1)
			else
				error('Unexpected old facing '..f)
			end
		end
		return table.unpack(res)
	end

	turtle.back = function()
		local res = {turtle_back()}
		if res[1] then
			local f = pos.f
			if f == '+x' then
				update('x', pos.x - 1)
			elseif f == '-x' then
				update('x', pos.x + 1)
			elseif f == '+z' then
				update('z', pos.z - 1)
			elseif f == '-z' then
				update('z', pos.z + 1)
			else
				error('Unexpected old facing '..f)
			end
		end
		return table.unpack(res)
	end

	turtle.up = function()
		local res = {turtle_up()}
		if res[1] then
			update('y', pos.y + 1)
		end
		return table.unpack(res)
	end

	turtle.down = function()
		local res = {turtle_down()}
		if res[1] then
			update('y', pos.y - 1)
		end
		return table.unpack(res)
	end

	turtle.turnLeft = function()
		local res = {turtle_turnLeft()}
		if res[1] then
			local f = pos.f
			local n = nil
			if f == '+x' then n = '-z'
			elseif f == '-z' then n = '-x'
			elseif f == '-x' then n = '+z'
			elseif f == '+z' then n = '+x'
			else
				error('Unexpected old facing '..f)
			end
			update('f', n)
		end
		return table.unpack(res)
	end

	turtle.turnRight = function()
		local res = {turtle_turnRight()}
		if res[1] then
			local f = pos.f
			local n = nil
			if f == '+x' then n = '+z'
			elseif f == '+z' then n = '-x'
			elseif f == '-x' then n = '-z'
			elseif f == '-z' then n = '+x'
			else
				error('Unexpected old facing '..f)
			end
			update('f', n)
		end
		return table.unpack(res)
	end

	return true
end

local function locate()
	if pos == nil then
		return nil
	end
	return pos.x, pos.y, pos.z
end

local function facing()
	return pos.f
end

return {
	version = version,
	init = init,
	locate = locate,
	facing = facing,
}
