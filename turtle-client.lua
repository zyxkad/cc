-- Remote turtle client side
-- by zyxkad@gmail.com

if not rednet then
	error("rednet API wasn't found")
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
	error('Cannot load global aes key: ' .. err)
end

local hmac = hmac
if not hmac then
	hmac = require('hmac')
	if not hmac then
		error('hmac API not found')
	end
end

local function getSecond()
	return math.floor(os.epoch() / 100000)
end

local function locate(tid, id)
	local msg = { c = 'locate', a = nil }
	local exp = getSecond() + 3
	local h = hmac.signCrc32( global_aes_key, { exp = exp, sub = "rmt-tultle" }, msg)
	msg.exp = exp
	msg.hmac = h
	rednet.send(tid, msg, id)
	local _, reply = rednet.receive(string.format("reply-%s", id), 3)
	if not reply or type(reply) ~= 'table' then
		return nil
	end
	return reply[1], reply[2], reply[3]
end

local function getFuelLevel(tid, id)
	local msg = { c = 'getFuel', a = nil }
	local exp = getSecond() + 3
	local h = hmac.signCrc32( global_aes_key, { exp = exp, sub = "rmt-tultle" }, msg)
	msg.exp = exp
	msg.hmac = h
	rednet.send(tid, msg, id)
	local _, reply = rednet.receive(string.format("reply-%s", id), 3)
	if not reply or type(reply) ~= 'table' then
		return nil
	end
	return reply[1], reply[2]
end

local function main()
	print("Starting turtle client with arguments:", table.concat(arg, ", "))

	local id = arg[1]
	if not id then
		error("You must give an ID for connect to turtle")
	end
	print("turtle id =", id)
	local subcmd = arg[2]

	local modem = nil
	for _, v in ipairs(peripheral.getNames()) do
		if peripheral.getType(v) == 'modem' then
			modem = v
			break
		end
	end
	if not modem then
		error("No modem found on the computer")
	end
	print("modem side =", _modem)
	print()

	rednet.open(modem)
	local tid = rednet.lookup(id, string.format("turtle-%s", id))
	if not tid then
		error(string.format("Cannot find turtle with id '%s'", id))
	end

	if subcmd == 'exit' then
		local msg = { c = 'exit', a = nil }
		local exp = getSecond() + 3
		local h = hmac.signCrc32( global_aes_key, { exp = exp, sub = "rmt-tultle" }, msg)
		msg.exp = exp
		msg.hmac = h
		rednet.send(tid, msg, id)
		print('exiting turtle...')
		local _, reply = rednet.receive(string.format("reply-%s", id), 3)
		print('reply:', reply)
		return
	end

	print("Found turtle:", tid)
	print("Reading keys...")
	while(true) do
		local _, k, rep = os.pullEvent('key')
		local msg = nil
		if k == keys.w then
			msg = { c = 'forward', a = nil }
		elseif k == keys.s then
			msg = { c = 'back', a = nil }
		elseif k == keys.a then
			msg = { c = 'turnLeft', a = nil }
		elseif k == keys.d then
			msg = { c = 'turnRight', a = nil }
		elseif k == keys.space then
			msg = { c = 'up', a = nil }
		elseif k == keys.leftShift or k == keys.z then
			msg = { c = 'down', a = nil }
		elseif k == keys.j then
			msg = { c = 'dig', a = nil }
		elseif k == keys.i then
			msg = { c = 'digUp', a = nil }
		elseif k == keys.k then
			msg = { c = 'digDown', a = nil }
		elseif k == keys.y then
			msg = { c = 'place', a = nil }
		end
		if msg then
			local exp = getSecond() + 3
			local h = hmac.signCrc32( global_aes_key, { exp = exp, sub = "rmt-tultle" }, msg)
			msg.exp = exp
			msg.hmac = h
			rednet.send(tid, msg, id)
			print('waiting reply...')
			local _, reply = rednet.receive(string.format("reply-%s", id), 3)
			local x, y, z = locate(tid, id)
			local fl, fm = getFuelLevel(tid, id)
			term.clear()
			term.setCursorPos(1, 1)
			if x then
				print(string.format('Pos: %d, %d, %d', x, y, z))
			else
				print('Pos: ERROR')
			end
			if fl then
				print(string.format('Fuel: %d / %d', fl, fm))
			else
				print('Fuel: ERROR')
			end
			print(reply)
		else
			local x, y, z = locate(tid, id)
			local fl, fm = getFuelLevel(tid, id)
			term.clear()
			term.setCursorPos(1, 1)
			if x then
				print(string.format('Pos: %d, %d, %d', x, y, z))
			else
				print('Pos: ERROR')
			end
			if fl then
				print(string.format('Fuel: %d / %d', fl, fm))
			else
				print('Fuel: ERROR')
			end
		end
	end
end

main()
