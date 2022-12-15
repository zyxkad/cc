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

local function doN(c, n)
	if n == nil then
		n = 1
	end
	for i = 1, n do
		if not c() then
			return false, i
		end
	end
	return true, n
end

local turnLeft, turnRight, turnBack

turnLeft = function(n, before, after)
	if n and n < 0 then
		return turnRight(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.turnLeft() and after() end, n)
end

turnRight = function(n, before, after)
	if n and n < 0 then
		return turnLeft(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.turnRight() and after() end, n)
end

turnBack = function(n, before, after)
	local turn = turtle.turnRight
	if n and n < 0 then
		n = -n
		turn = turtle.turnLeft
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turn() and turn() and after() end, n)
end

local forward, back, up, down, left, right

forward = function(n, before, after)
	if n and n < 0 then
		return back(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.forward() and after() end, n)
end

back = function(n, before, after)
	if n and n < 0 then
		return forward(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.back() and after() end, n)
end

up = function(n, before, after)
	if n and n < 0 then
		return down(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.up() and after() end, n)
end

down = function(n, before, after)
	if n and n < 0 then
		return up(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and turtle.down() and after() end, n)
end

left = function(n, before, after)
	if n and n < 0 then
		return right(-n, before, after)
	end
	local bef = (before and function() return turtle.turnRight() and before() and turtle.turnLeft() end) or nil
	local aft = (after and function() return turtle.turnRight() and after() and turtle.turnLeft() end) or nil
	if not turtle.turnLeft() then
		return false, 0
	end
	local ok, i = forward(n, bef, aft)
	if not turtle.turnRight() then
		return false, i
	end
	return ok, i
end

right = function(n, before, after)
	if n and n < 0 then
		return left(-n, before, after)
	end
	local bef = (before and function() return turtle.turnLeft() and before() and turtle.turnRight() end) or function() return true end
	local aft = (after and function() return turtle.turnLeft() and after() and turtle.turnRight() end) or function() return true end
	if not turtle.turnRight() then
		return false, 0
	end
	local ok, i = forward(n, bef, aft)
	if not turtle.turnLeft() then
		return false, i
	end
	return ok, i
end

local digForward, digBack, digUp, digDown, digLeft, digRight

digForward = function(n, before, after)
	if n and n < 0 then
		return digBack(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and (not turtle.detect() or turtle.dig()) and turtle.forward() and after() end, n)
end

digBack = function(n, before, after)
	if n and n < 0 then
		return digForward(-n, before, after)
	end
	local bef = (before and function() return turnBack() and before() and turnBack() end) or function() return true end
	local aft = (after and function() return turnBack() and after() and turnBack() end) or function() return true end
	if not turnBack() then
		return false, 0
	end
	local ok, i = digForward(n, before, after)
	if not turnBack() then
		return false, i
	end
	return ok, i
end

digUp = function(n, before, after)
	if n and n < 0 then
		return digDown(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and (not turtle.detectUp() or turtle.digUp()) and turtle.up() and after() end, n)
end

digDown = function(n, before, after)
	if n and n < 0 then
		return digUp(-n, before, after)
	end
	before = before or function() return true end
	after = after or function() return true end
	return doN(function() return before() and (not turtle.detectDown() or turtle.digDown()) and turtle.down() and after() end, n)
end

digLeft = function(n, before, after)
	if n and n < 0 then
		return digRight(-n, before, after)
	end
	local bef = (before and function() return turtle.turnRight() and before() and turtle.turnLeft() end) or nil
	local aft = (after and function() return turtle.turnRight() and after() and turtle.turnLeft() end) or nil
	if not turtle.turnLeft() then
		return false, 0
	end
	local ok, i = digForward(n, bef, aft)
	if not turtle.turnRight() then
		return false, i
	end
	return ok, i
end

digRight = function(n, before, after)
	if n and n < 0 then
		return digLeft(-n, before, after)
	end
	local bef = (before and function() return turtle.turnLeft() and before() and turtle.turnRight() end) or function() return true end
	local aft = (after and function() return turtle.turnLeft() and after() and turtle.turnRight() end) or function() return true end
	if not turtle.turnRight() then
		return false, 0
	end
	local ok, i = digForward(n, bef, aft)
	if not turtle.turnLeft() then
		return false, i
	end
	return ok, i
end

local function digSquare(dz, dx, before, after)
	if not dz then
		error("Missing argument 'dz'")
	end
	if not dx then
		error("Missing argument 'dx'")
	end
	if dx == 0 then
		return digForward(dz) and digBack(dz)
	end
	local xs = (dx < 0 and -1) or 1
	local i = 0
	while (true) do
		if i % 2 == 0 then
			if not digForward(dz, before, after) then
				return false
			end
		else
			if not digBack(dz, before, after) then
				return false
			end
		end
		if i == dx then
			break
		end
		i = i + xs
		if not digRight(xs, before, after) then
			return false
		end
	end
	if dx % 2 == 0 then
		if not digBack(dz) then
			return false
		end
	end
	if not digLeft(dx) then
		return false
	end
	return true
end

local function locate()
	if not gps then
		error("Gps API not found")
	end
	local x, y, z = gps.locate()
	if x == nil then
		error("Cannot locate current position")
	end
	return x, y, z
end

-- face east: x+
-- face west: x-
-- face south: z+
-- face north: z-

local faceTb = {
	e = "east",
	w = "west",
	s = "south",
	n = "north",
	east = "east",
	west = "west",
	south = "south",
	north = "north",
}

local reverseFaceTb = {
	east = "west",
	west = "east",
	south = "north",
	north = "south",
}

local function reverseDirection(face)
	return reverseFaceTb[faceTb[face]]
end

local function getDirection0()
	local x0, y0, z0 = locate()
	local back, backfn = false, turtle.back
	if not turtle.forward() then
		if not turtle.back() then
			error("Turtle can move nether forward nor backward")
		else
			back, backfn = true, turtle.forward
		end
	end
	local x1, y1, z1 = locate()
	if not backfn() then
		error("Turtle cannot move back")
	end
	if (y0 ~= y1) or (x0 ~= x1 and z0 ~= z1) then
		error("GPS locate error")
	end
	local face, ok = '', false
	if x0 < x1 then
		face, ok = "east", true
	elseif x0 > x1 then
		face, ok = "west", true
	elseif z0 < z1 then
		face, ok = "south", true
	elseif z0 > z1 then
		face, ok = "north", true
	end
	if not ok then
		error("GPS locate error")
	end
	if back then
		face = reverseDirection(face)
	end
	return face
end

local function getDirection()
	return getDirection0()
end

local function faceTo(face, cur)
	local tg = faceTb[string.lower(face)]
	if not tg then
		error(string.format("Unknown directionection '%s'"), tg)
	end
	cur = cur and faceTb[string.lower(cur)]
	if not cur then
		cur = getDirection()
	end
	if cur == tg then
		return true
	end
	if cur == "east" then
		if tg == "west" then
			return turnBack()
		elseif tg == "north" then
			return turtle.turnLeft()
		elseif tg == "south" then
			return turtle.turnRight()
		end
	elseif cur == "west" then
		if tg == "east" then
			return turnBack()
		elseif tg == "south" then
			return turtle.turnLeft()
		elseif tg == "north" then
			return turtle.turnRight()
		end
	elseif cur == "north" then
		if tg == "south" then
			return turnBack()
		elseif tg == "west" then
			return turtle.turnLeft()
		elseif tg == "east" then
			return turtle.turnRight()
		end
	elseif cur == "south" then
		if tg == "north" then
			return turnBack()
		elseif tg == "east" then
			return turtle.turnLeft()
		elseif tg == "west" then
			return turtle.turnRight()
		end
	end
	error("Wrong statment")
end

local function moveTo(pos)
	error("TODO")
end

local function digTo(pos)
	local x0, y0, z0 = locate()
	local dx, dy, dz =
		((pos.x and pos.x - x0) or 0),
		((pos.y and pos.y - y0) or 0),
		((pos.z and pos.z - z0) or 0)
	local f = getDirection()
	if (f ~= "north") and  not faceTo("north", f) then
		return false
	end
	if not((dx == 0 or digRight(dx)) and (dy == 0 or digUp(dy)) and (dz == 0 or digBack(dz))) then
		return false
	end
	if (f ~= "north") and  not faceTo(f, "north") then
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
		fn(arg, 1)
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

if isProgram then
	return main(arg)
end

---- END CLI ----

return {
	turnLeft = turnLeft,
	turnRight = turnRight,
	turnBack = turnBack,
	forward = forward,
	back = back,
	up = up,
	down = down,
	left = left,
	right = right,
	digForward = digForward,
	digBack = digBack,
	digUp = digUp,
	digDown = digDown,
	digLeft = digLeft,
	digRight = digRight,
	digSquare = digSquare,
	locate = locate,
	reverseDirection = reverseDirection,
	getDirection = getDirection,
	faceTo = faceTo,
	moveTo = moveTo,
	digTo = digTo,
	digSquareTo = digSquareTo,
}
