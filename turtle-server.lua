-- Remote turtle server side
-- by zyxkad@gmail.com

if not turtle then
	error("turtle API not found")
end

if not rednet then
	error("rednet API not found")
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

	refuel = function() return turtle.refuel() end,
	getFuel = function()
		local level = turtle.getFuelLevel()
		if level == "unlimited" then
			return -1
		end
		return level
	end,
	getFuelLimit = function()
		local limit = turtle.getFuelLimit()
		if limit == "unlimited" then
			return -1
		end
		return limit
	end,
}

local function handle_msg(prot, sdr, msg)
	local cmd, arg = msg.c, msg.a
	local c = rpcDCalls[cmd]
	if c then
		rednetReply(prot, sdr, c(arg))
	else
		print(string.format("Unknown command '%s'", cmd))
		rednetReply(prot, sdr, "Unknown command")
	end
end

local function main()
	print("Starting turtle server with arguments:", table.concat(arg, ", "))

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
