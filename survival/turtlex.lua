-- More turtle actions
-- by zyxkad@gmail.com

-- Usage: turtlex = require("turtlex")

if not turtle then
	error("turtle API not found")
end

local moduleName = ...
local isProgram = not moduleName or moduleName ~= 'turtlex'

local function proglog(...)
	if isProgram then
		print(...)
	end
end

local function doUntil(c, failed, max)
	failed = failed or function() return false end
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
	until res[1] or (max and i >= max) or failed(table.unpack(res))
	return table.unpack(res)
end

local function doN(c, n, before, after)
	if not n then
		n = 1
	end
	before = before or function() return true end
	after = after or function() return true end
	for i = 1, n do
		local ok, err = before()
		if not ok then return false, n, err end
		local ok, err = c()
		if not ok then return false, n, err end
		local ok, err = after()
		if not ok then return false, n, err end
	end
	return true, n
end

local function gpsLocater()
	if not gps then
		return false, 'Gps API not found'
	end
	local x, y, z = gps.locate()
	if x == nil then
		return false, 'Cannot locate current position'
	end
	return {x=x, y=y, z=z}
end

local Turtle = {
	action_retry = 3,

	locater = gpsLocater,
}

function Turtle:dig()
	return turtle.dig()
end

function Turtle:digIfExists()
	return not turtle.detect() or self:dig()
end

function Turtle:digTop()
	return turtle.digUp()
end

function Turtle:digTopIfExists()
	return not turtle.detectUp() or self:digTop()
end

function Turtle:digBottom()
	return turtle.digDown()
end

function Turtle:digBottomIfExists()
	return not turtle.detectDown() or self:digBottom()
end

function Turtle:turnLeft(n, before, after)
	if n and n < 0 then
		return self:turnRight(-n, before, after)
	end
	return doN(function() return doUntil(turtle.turnLeft, nil, self:action_retry) end, before, after, n)
end

function Turtle:turnRight(n, before, after)
	if n and n < 0 then
		return self:turnLeft(-n, before, after)
	end
	return doN(function() return doUntil(turtle.turnRight, nil, self:action_retry) end, before, after, n)
end

function Turtle:turnBack(n, before, after)
	local turn = turtle.turnRight
	if n and n < 0 then
		n = -n
		turn = turtle.turnLeft
	end
	return doN(function() return doUntil(turn, nil, self:action_retry) and doUntil(turn, nil, self:action_retry) end, before, after, n)
end

function Turtle:checkFuel(n, fuel)
	local fuel = fuel or turtle.getFuelLevel()
	if fuel == 'unlimited' then
		return true, 'unlimited'
	end
	if n then
		if n < 0 then
			n = -n
		end
		local remain = fuel - n
		if remain < 0 then
			return false, string.format('Fuel not enough for %d moves', n)
		end
		return true, remain
	end
	if fuel == 0 then
		return false, 'Zero fuel remain'
	end
	return true, fuel
end

function Turtle:checkFuelOrFail(n, fuel)
	local ok, fuel = self:checkFuel(n, fuel)
	if ok then
		return fuel
	end
	error(fuel)
end

function Turtle:forward(n, before, after)
	if n and n < 0 then
		return self:back(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return doUntil(turtle.forward, nil, self:action_retry) end, before, after, n)
end

function Turtle:back(n, before, after)
	if n and n < 0 then
		return self:forward(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return doUntil(turtle.back, nil, self:action_retry) end, before, after, n)
end

function Turtle:up(n, before, after)
	if n and n < 0 then
		return self:down(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return doUntil(turtle.up, nil, self:action_retry) end, before, after, n)
end

function Turtle:down(n, before, after)
	if n and n < 0 then
		return self:up(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return doUntil(turtle.down, nil, self:action_retry) end, before, after, n)
end

function Turtle:left(n, before, after)
	if n and n < 0 then
		return self:right(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	if not turtle.turnLeft() then
		return false, 0, 'Cannot turn left'
	end
	local ok, i, err = self:forward(n, before, after)
	if not turtle.turnRight() then
		return false, i, 'Cannot turn right'
	end
	return ok, i, err
end

function Turtle:right(n, before, after)
	if n and n < 0 then
		return self:left(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	if not turtle.turnRight() then
		return false, 0, 'Cannot turn right'
	end
	local ok, i, err = self:forward(n, before, after)
	if not turtle.turnLeft() then
		return false, i, 'Cannot turn left'
	end
	return ok, i, err
end

function Turtle:digForward(n, before, after)
	if n and n < 0 then
		return self:digBack(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function()
		if not turtle.digIfExists() then
			return false, 'Cannot dig forward'
		end
		if not self:forward() then
			return false, 'Cannot move forward'
		end
		return true
	end, before, after, n)
end

function Turtle:digBack(n, before, after)
	if n and n < 0 then
		return self:digForward(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	if not turnBack() then
		return false, 0, 'Cannot turn first back'
	end
	local ok, i, err = digForward(n, before, after)
	if not turnBack() then
		return false, i, 'Cannot turn second back'
	end
	if not ok then
		return ok, i, 'Cannot dig forward'
	end
	return ok, i, err
end

function Turtle:digUp(n, before, after)
	if n and n < 0 then
		return self:digDown(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return self:digUpIfExists() and self:up() end, before, after, n)
end

function Turtle:digDown(n, before, after)
	if n and n < 0 then
		return digUp(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	return doN(function() return self:digBottomIfExists() and self:down() end, before, after, n)
end

function Turtle:digLeft(n, before, after)
	if n and n < 0 then
		return digRight(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	if not self:turnLeft() then
		return false, 0, 'Cannot turn left'
	end
	local ok, i, err = digForward(n, before, after)
	if not self:turnRight() then
		return false, i, 'Cannot turn right'
	end
	return ok, i, err
end

function Turtle:digRight(n, before, after)
	if n and n < 0 then
		return digLeft(-n, before, after)
	end
	local ok, err = self:checkFuel(n)
	if not ok then
		return ok, 0, err
	end
	if not self:turnRight() then
		return false, 0, 'Cannot turn right'
	end
	local ok, i, err = digForward(n, before, after)
	if not turtle.turnLeft() then
		return false, i, 'Cannot turn left'
	end
	return ok, i, err
end

function Turtle:digSquare(dz, dx, before, after)
	if not dz then
		error("Missing argument 'dz'")
	end
	if not dx then
		error("Missing argument 'dx'")
	end
	if dx == 0 then
		return self:digForward(dz) and self:digBack(dz)
	end
	local xs = (dx < 0 and -1) or 1
	local i = 0
	while true do
		if i % 2 == 0 then
			if not self:digForward(dz, before, after) then
				return false, 'Cannot dig forward'
			end
		else
			if not self:digBack(dz, before, after) then
				return false, 'Cannot dig back'
			end
		end
		if i == dx then
			break
		end
		i = i + xs
		if not self:digRight(xs, before, after) then
			return false, 'Cannot dig right'
		end
	end
	if dx % 2 == 0 then
		if not self:digBack(dz) then
			return false, 'Cannot dig back'
		end
	end
	if not self:digLeft(dx) then
		return false, 'Cannot dig left'
	end
	return true
end

function Turtle:digCube(dz, dx, dy)
	if not dz then
		error("Missing argument 'dz'")
	end
	if not dx then
		error("Missing argument 'dx'")
	end
	if not dy then
		error("Missing argument 'dy'")
	end
	local xs = (dx < 0 and -1) or 1
	local x = 0
	while true do
		local dm = (x % 2 == 0 and self:digForward) or self:digBack
		local zs = (dz < 0 and -1) or 1
		local z = 0
		while true do
			local dd = (z % 2 == 0 and self:digUp) or self:digDown
			if not dd(dy) then
				return false
			end
			if z == dz then
				break
			end
			z = z + zs
			if not dm(xs) then
				return false
			end
		end
		if dz % 2 == 0 then
			if not self:digDown(dy) then
				return false
			end
		end
		if x == dx then
			break
		end
		x = x + xs
		if not self:digRight(xs) then
			return false
		end
	end
	if dx % 2 == 0 then
		if not self:digBack(dz) then
			return false
		end
	end
	if not self:digLeft(dx) then
		return false
	end
	return true
end

local function digPool(dz, dx, dy)
	if not dz then
		error("Missing argument 'dz'")
	end
	if not dx then
		error("Missing argument 'dx'")
	end
	if not dy then
		error("Missing argument 'dy'")
	end
	if dy < 0 then
		error("Y distance cannot less than zero")
	end
	local y = 0
	for y = 0, dy do
		if not self:digDown() then
			return false, 'Cannot dig down'
		end
		local xs = (dx < 0 and -1) or 1
		local x = 0
		while true do
			if x % 2 == 0 then
				if x == 0 and not self:digForward(dz) then
					return false, 'Cannot dig forward with block check'
				elseif not self:digForward(dz) then
					return false, 'Cannot dig forward'
				end
			else
				if not self:digBack(dz) then
					return false, 'Cannot dig back'
				end
			end
			if x == dx then
				break
			end
			x = x + xs
			if not self:digRight(xs) then
				return false, 'Cannot dig right'
			end
		end
		if dx % 2 == 0 then
			if not self:digBack(dz) then
				return false, 'Cannot dig back'
			end
		end
		if not self:digLeft(dx) then
			return false, 'Cannot dig left'
		end
	end
	if not self:digUp(dy + 1) then
		return false, 'Cannot dig up'
	end
	return true
end

function Turtle:locate()
	return self.locater()
end

-- face east: x+
-- face west: x-
-- face south: z+
-- face north: z-

local dirTb = {
	e = 'east',
	w = 'west',
	s = 'south',
	n = 'north',
	east = 'east',
	west = 'west',
	south = 'south',
	north = 'north',
	['x+'] = 'east',
	['+x'] = 'east',
	['x']  = 'east',
	['x-'] = 'west',
	['-x'] = 'west',
	['z+'] = 'south',
	['+z'] = 'south',
	['z']  = 'south',
	['z-'] = 'north',
	['-z'] = 'north',
}

local dir2axisTb = {
	ease = 'x+',
	west = 'x-',
	south = 'z+',
	north = 'z-',
}

local reverseDirTb = {
	east = 'west',
	west = 'east',
	south = 'north',
	north = 'south',
}

local turnRightDirTb = {
	east = 'south',
	west = 'north',
	south = 'west',
	north = 'east',
}

local turnLeftDirTb = {
	east = 'north',
	west = 'south',
	south = 'east',
	north = 'west',
}

local function direction2axis(face)
	return dir2axisTb[dirTb[string.lower(face)]]
end

local function reverseDirection(face)
	return reverseDirTb[dirTb[string.lower(face)]]
end

local function turnRightDirection(face)
	return turnRightDirTb[dirTb[string.lower(face)]]
end

local function turnLeftDirection(face)
	return turnLeftDirTb[dirTb[string.lower(face)]]
end

function Turtle:getDirectionByGPS()
	local pos0, err = self:locate()
	if not pos0 then
		return false, err
	end
	local back, backfn = false, self:back
	if not doUntil(turtle.forward, nil, 3) then
		if not doUntil(turtle.back, nil, 3) then
			return false, 'Turtle can neither move forward nor backward'
		else
			back, backfn = true, self:forward
		end
	end
	local pos1, err = self:locate()
	if not pos1 then
		return false, err
	end
	if not backfn() then
		return false, 'Turtle cannot move back'
	end
	if (pos0.y ~= pos1.y) or (pos0.x ~= pos1.x and pos0.z ~= pos1.z) then
		return false, 'GPS locate error'
	end
	local face = nil
	if x0 < x1 then
		face, ok = 'east'
	elseif x0 > x1 then
		face, ok = 'west'
	elseif z0 < z1 then
		face, ok = 'south'
	elseif z0 > z1 then
		face, ok = 'north'
	end
	if not face then
		return false, 'GPS locate error'
	end
	if back then
		face = reverseDirection(face)
	end
	return face
end

function Turtle:getDirection()
	return getDirectionByGPS()
end

function Turtle:getDirectionByStair()
	self:searchTag({'minecraft:stairs'})
end

function Turtle:faceTo(face, cur)
	local tg = dirTb[string.lower(face)]
	if not tg then
		error(string.format("Unknown directionection '%s'"), face)
	end
	cur = cur and dirTb[string.lower(cur)]
	if not cur then
		local err
		cur, err = getDirection()
		if not cur then
			return false, err
		end
	end
	if cur == tg then
		return true
	end
	if cur == 'east' then
		if tg == 'west' then
			return self:turnBack()
		elseif tg == 'north' then
			return self:turnLeft()
		elseif tg == 'south' then
			return self:turnRight()
		end
	elseif cur == 'west' then
		if tg == 'east' then
			return self:turnBack()
		elseif tg == 'south' then
			return self:turnLeft()
		elseif tg == 'north' then
			return self:turnRight()
		end
	elseif cur == 'north' then
		if tg == 'south' then
			return self:turnBack()
		elseif tg == 'west' then
			return self:turnLeft()
		elseif tg == 'east' then
			return self:turnRight()
		end
	elseif cur == 'south' then
		if tg == 'north' then
			return self:turnBack()
		elseif tg == 'east' then
			return self:turnLeft()
		elseif tg == 'west' then
			return self:turnRight()
		end
	end
	assert(false, "Shouldn't reach here")
end

local function moveTo(pos)
	assert(false, "TODO")
end

local function digTo(pos)
	local x0, y0, z0 = locate()
	local dx, dy, dz =
		((pos.x and pos.x - x0) or 0),
		((pos.y and pos.y - y0) or 0),
		((pos.z and pos.z - z0) or 0)
	local f = getDirection()
	if (f ~= 'north') and not faceTo('north', f) then
		return false
	end
	if not((dx == 0 or digRight(dx)) and (dy == 0 or digUp(dy)) and (dz == 0 or digBack(dz))) then
		return false
	end
	if (f ~= 'north') and not faceTo(f, 'north') then
		return false
	end
	return true
end

local function digSquareTo(x, z, before, after)
	local x0, _, z0 = locate()
	local dx, dz =
		((x and x - x0) or 0),
		((z and z0 - z) or 0)
	local f = getDirection()
	if (f ~= "north") and not faceTo("north", f) then
		return false
	end
	if not digSquare(dz, dx, before, after) then
		return false
	end
	if (f ~= "north") and not faceTo(f, "north") then
		return false
	end
	return true
end

---- CLI ----

local subCommands = {
	digSquare = function(arg, i)
		local dz, dx = tonumber(arg[i + 1]), tonumber(arg[i + 2])
		dz = (dz == 0 and 0) or (dz > 0 and dz - 1 or dz + 1)
		dx = (dx == 0 and 0) or (dx > 0 and dx - 1 or dx + 1)
		return digSquare(dz, dx, nil, function() turtle.digUp(); turtle.digDown(); return true end)
	end,
	digCube = function(arg, i)
		local dz, dx, dy = tonumber(arg[i + 1]), tonumber(arg[i + 2]), tonumber(arg[i + 3])
		dz = (dz == 0 and 0) or (dz > 0 and dz - 1 or dz + 1)
		dx = (dx == 0 and 0) or (dx > 0 and dx - 1 or dx + 1)
		dy = (dy == 0 and 0) or (dy > 0 and dy - 1 or dy + 1)
		return digCube(dz, dx, dy)
	end,
	digPool = function(arg, i)
		local dz, dx, dy = tonumber(arg[i + 1]), tonumber(arg[i + 2]), tonumber(arg[i + 3])
		dz = (dz == 0 and 0) or (dz > 0 and dz - 1 or dz + 1)
		dx = (dx == 0 and 0) or (dx > 0 and dx - 1 or dx + 1)
		dy = (dy == 0 and 0) or (dy > 0 and dy - 1 or dy + 1)
		return digPool(dz, dx, dy)
	end,
}

subCommands.help = function(arg, i)
	local sc = arg[i + 1]
	print('All subcommands:')
	for c, _ in pairs(subCommands) do
		print('-', c)
	end
end

local function main(arg)
	if #arg == 0 then
		print('All subcommands:')
		for c, _ in pairs(subCommands) do
			print('-', c)
		end
		return
	end
	local subcmd = arg[1]
	local fn = subCommands[subcmd]
	if fn then
		local ok, err = fn(arg, 1)
		if not ok and err then
			printError(err)
		end
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

if isProgram then
	return main(arg)
end

---- END CLI ----

return {
	Turtle = Turtle,
	gpsLocater = gpsLocater,
	direction2axis = direction2axis,
	reverseDirection = reverseDirection,
	turnRightDirection = turnRightDirection,
	turnLeftDirection = turnLeftDirection,
}
