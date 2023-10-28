-- Remote turtle server side
-- by zyxkad@gmail.com

os.pullEvent = os.pullEventRaw

if not turtle then
	error("turtle API not found")
end

if not rednet then
	error("rednet API not found")
end

local aes = aes
if not aes then
	aes = require('aes')
	if not aes then
		error('aes API not found')
	end
end

local global_aes_key, err = aes.loadKey()
if not global_aes_key then
	global_aes_key = string.rep(' ', 16)
	-- error('Cannot load global aes key: ' .. err)
end

local hmac = hmac
if not hmac then
	hmac = require('hmac')
	if not hmac then
		error('hmac API not found')
	end
end

local sgps = require('sgps')
if not sgps then
	error("sgps API not found")
end

local function getSecond()
	return math.floor(os.epoch() / 100000)
end

local function rednetReply(protocol, recver, v)
	rednet.send(recver, v, string.format("reply-%s", protocol))
end

local rpcDCalls = {
	forward   = function() return turtle.forward() end,
	back      = function() return turtle.back() end,
	up        = function() return turtle.up() end,
	down      = function() return turtle.down() end,
	turnLeft  = function() return turtle.turnLeft() end,
	turnRight = function() return turtle.turnRight() end,
	left  = function()
		return turtle.turnLeft() and turtle.forward() and turtle.turnRight()
	end,
	right = function()
		return turtle.turnRight() and turtle.forward() and turtle.turnLeft()
	end,

	place     = function() return turtle.place() end,
	placeUp   = function() return turtle.placeUp() end,
	placeDown = function() return turtle.placeDown() end,

	attack     = function() return turtle.attack() end,
	attackUp   = function() return turtle.attackUp() end,
	attackDown = function() return turtle.attackDown() end,

	dig     = function() return turtle.dig() end,
	digUp   = function() return turtle.digUp() end,
	digDown = function() return turtle.digDown() end,

	suck = function() return turtle.suck() or turtle.suckUp() or turtle.suckDown() end,
	drop = function() return turtle.drop() or turtle.dropUp() or turtle.dropDown() end,

	refuel = function() return turtle.refuel() end,
	getFuel = function()
		local level, limit = turtle.getFuelLevel(), turtle.getFuelLimit()
		if limit == "unlimited" then
			return {0, 0}
		end
		return {level, limit}
	end,

	locate = function()
		local x, y, z = gps.locate()
		if not x then
			return nil
		end
		return {x, y, z}
	end,

	exit = function()
		error("EXIT command received")
	end
}

local function handle_msg(prot, sdr, msg)
	local cmd, arg, exp = msg.c, msg.a, msg.exp
	if not exp or exp < getSecond() or msg.hmac ~= hmac.signCrc32(
		global_aes_key, { exp = exp, sub = "rmt-tultle" },
		{ c = cmd, a = arg }) then
		return
	end
	print('Running', cmd)
	local c = rpcDCalls[cmd]
	if c then
		rednetReply(prot, sdr, {c(arg)})
	else
		print(string.format("Unknown command '%s'", cmd))
		rednetReply(prot, sdr, "Unknown command")
	end
end

local function main()
	-- print("Starting turtle server with arguments:", table.concat(arg, ", "))
	local id = arg[1]
	if not id then
		error("You must give an ID to the turtle")
	end
	print("turtle id =", id)

	local modem = nil
	for _, v in ipairs(peripheral.getNames()) do
		if peripheral.getType(v) == 'modem' then
			modem = v
			break
		end
	end
	if not modem then
		error("No modem found on the turtle")
	end
	print("modem side =", modem)
	print()

	rednet.open(modem)
	rednet.host(id, string.format("turtle-%s", id))

	print("Listening...")
	while(true) do
		local sdr, msg = rednet.receive(id, 30)
		if msg then
			handle_msg(id, sdr, msg)
		end
	end
end

main()
