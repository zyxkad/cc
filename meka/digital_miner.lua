-- Digital miner
-- by zyxkad@gmail.com

-- startup command:
-- shell.run('digital_miner.lua', 'placeAndForward', 'launch')

if not turtle then
	error('turtle API not found')
end

local debuging = false
local enable_teleporter = true
-- local lava_quantum_nbt = 

local turtleLabel = os.getComputerLabel()
if not turtleLabel then
	error('Please use `label set <label>` give the miner a name')
end

local miner_frequency = turtleLabel
local emergency_frequency = turtleLabel..'_E'
local digital_miner_id = 'mekanism:digital_miner'
local cable_id = 'mekanism:advanced_universal_cable'
-- not using yet
local transporter_id = 'mekanism:advanced_logistcial_transporter'
-- only if enable_teleporter
local a = 'mekanism:teleporter'
local quantum_porter_id = 'mekanism:quantum_entangloporter'
local diamond_pickaxe_id = 'minecraft:diamond_pickaxe'
local ender_wireless_modem_id = 'computercraft:wireless_modem_advanced'
-- only if no ender wireless modem
local wireless_modem_id = 'computercraft:wireless_modem_normal'

local function doUntil(c, failed, max)
	if type(failed) == 'number' then
		failed, max = nil, failed
	end
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
		sleep(0)
	until res[1] or (max and i >= max) or (failed and failed(table.unpack(res)))
	return table.unpack(res)
end

local function digIfExists()
	return not turtle.detect() or turtle.dig()
end

local function digUpIfExists()
	return not turtle.detectUp() or turtle.digUp()
end

local function digDownIfExists()
	return not turtle.detectDown() or turtle.digDown()
end

local function cleanInventory()
	return true
end

local function selectItem(item)
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if detial and detial.name == item then
			turtle.select(i)
			return true
		end
	end
	return false
end

local function selectEmptySlot()
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if not detial then
			turtle.select(i)
			return true
		end
	end
	return false
end

local function unequipLeft()
	if not selectEmptySlot() then
		return false, 'no empty slot found'
	end
	return turtle.equipLeft()
end

local function equipLeft(item)
	if not selectItem(item) then
		return false, 'item was not found'
	end
	turtle.equipLeft()
	return true
end

local function hasFrequency(teleporter, frequency)
	local ls = teleporter.getFrequencies()
	for _, v in ipairs(ls) do
		if v.key == frequency then
			return true
		end
	end
	return false
end

local function equipLeftModem()
	return equipLeft(ender_wireless_modem_id) or equipLeft(wireless_modem_id)
end

local function rewrite(str)
	local _, y = term.getCursorPos()
	term.setCursorPos(1, y)
	term.clearLine()
	term.write(str)
end

local function reprint(...)
	local _, y = term.getCursorPos()
	term.setCursorPos(1, y)
	term.clearLine()
	print(...)
end

local function place()
	if not selectItem(digital_miner_id) then
		return false, string.format('No item [%s] found', digital_miner_id)
	end
	doUntil(turtle.placeUp)
	doUntil(turtle.forward)
	doUntil(turtle.forward)
	doUntil(turtle.up)
	if not selectItem(quantum_porter_id) then
		return false, string.format('No item [%s] found', quantum_porter_id)
	end
	doUntil(turtle.placeUp)
	doUntil(turtle.turnRight)
	doUntil(turtle.back)
	if not selectItem(cable_id) then
		return false, string.format('No item [%s] found', cable_id)
	end
	doUntil(turtle.place)
	doUntil(turtle.back)
	if not selectItem(cable_id) then
		return false, string.format('No item [%s] found', cable_id)
	end
	doUntil(turtle.place)
	doUntil(turtle.turnLeft)
	if enable_teleporter then
		if not selectItem(a) then
			return false, string.format('No item [%s] found', teleporter_id)
		end
		doUntil(turtle.placeUp)
		local teleporter
		repeat
			teleporter = peripheral.wrap('top')
		until teleporter
		if teleporter.getSecurityMode() == 'PUBLIC' then
			if not hasFrequency(teleporter, miner_frequency) then
				teleporter.createFrequency(miner_frequency)
			end
			teleporter.setFrequency(miner_frequency)
		end
	end
	doUntil(turtle.back)
	if not selectItem(cable_id) then
		return false, string.format('No item [%s] found', cable_id)
	end
	doUntil(turtle.place)
	doUntil(turtle.back)
	if not selectItem(cable_id) then
		return false, string.format('No item [%s] found', cable_id)
	end
	doUntil(turtle.place)
	doUntil(turtle.down)
	if not selectItem(cable_id) then
		return false, string.format('No item [%s] found', cable_id)
	end
	doUntil(turtle.placeUp)
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	return true
end

local function destroy()
	if not cleanInventory() then
		return false
	end
	equipLeft(diamond_pickaxe_id)
	doUntil(digUpIfExists)
	doUntil(turtle.turnLeft)
	doUntil(turtle.forward)
	doUntil(turtle.forward)
	doUntil(turtle.turnRight)
	doUntil(digUpIfExists)
	doUntil(turtle.up)
	doUntil(digIfExists)
	doUntil(turtle.forward)
	doUntil(digIfExists)
	doUntil(turtle.forward)
	doUntil(digUpIfExists)
	doUntil(turtle.turnRight)
	doUntil(digIfExists)
	doUntil(turtle.forward)
	doUntil(digIfExists)
	doUntil(turtle.forward)
	doUntil(digUpIfExists)
	doUntil(turtle.turnLeft)
	doUntil(digDownIfExists)
	doUntil(turtle.down)
	return true
end

local function broadcastProcess(modem, typ, data)
	rednet.open(peripheral.getName(modem))
	local monitors = {rednet.lookup('miner_monitor')}
	for _, m in ipairs(monitors) do
		rednet.send(m, {
			id = miner_frequency,
			typ = typ,
			data = data,
		}, 'digital_miner')
	end
	rednet.close(peripheral.getName(modem))
end

local function placeMinerAndDestroy(modem)
	rewrite('Placing...')
	local ok, err = place()
	if not ok then
		print()
		return false, err
	end
	local miner = peripheral.wrap('top')
	rewrite('Starting...')
	if miner.getSecurityMode() == 'PUBLIC' then
		miner.stop()
		miner.reset()
		miner.setAutoEject(false)
		sleep(0.1) -- need refuresh auto eject?
		miner.setAutoEject(true)
		miner.setSilkTouch(true)
		miner.setRadius(32)
	end
	miner.start()
	rewrite('Polling...')
	sleep(1)
	local remain = miner.getToMine()
	local i = 0
	while remain ~= 0 do
		local _, y = term.getCursorPos()
		i = (i + 1) % 3
		rewrite(string.format('%d ores left.'..(string.rep('.', i)), remain))
		sleep(0.05)
		remain = miner.getToMine()
		if modem then
			broadcastProcess(modem, 'mining', remain)
		end
	end
	rewrite('Stopping...')
	miner.stop()
	rewrite('Destroying...')
	if modem then
		broadcastProcess(modem, 'destorying')
	end
	ok, err = destroy()
	if not ok then
		print()
		if modem then
			broadcastProcess(modem, 'error', err)
		end
		return false, err
	end
	return true
end

local cached_position_path = 'position.txt'
local cached_stat_path = 'stat.txt'

local function broadcastPos(modem, x, y, z)
	rednet.open(peripheral.getName(modem))
	local monitors = {rednet.lookup('miner_monitor')}
	for _, m in ipairs(monitors) do
		rednet.send(m, {
			id = miner_frequency,
			typ = 'pos',
			x = x, y = y, z = z,
			fuel = turtle.getFuelLevel(),
		}, 'digital_miner')
	end
	rednet.close(peripheral.getName(modem))
end

local function gpsLocate()
	local x, y, z = gps.locate(2, debuging)
	if x ~= x then -- it's nan
		return false
	end
	return x, y, z
end

local function _moveAndBroadcast1(modem, n)
	for i = 1, n do
		local ok, _, err = doUntil(turtle.forward, 3)
		if not ok then
			print()
			broadcastProcess(modem, 'error', err or 'Turtle cannot move forward')
			return false, err
		end
		rewrite(string.format('Moved %d blocks...', i))
		local x, y, z = doUntil(gpsLocate)
		broadcastPos(modem, x, y, z)
	end
end

local function _moveAndBroadcast2(modem, n)
	local done = false
	parallel.waitForAll(function()
		for i = 1, n do
			local ok, _, err = doUntil(turtle.forward, 3)
			if not ok then
				print()
				broadcastProcess(modem, 'error', err or 'Turtle cannot move forward')
				return false, err
			end
			rewrite(string.format('Moved %d blocks...', i))
		end
		done = true
	end, function()
		repeat
			local x, y, z = doUntil(gpsLocate)
			broadcastPos(modem, x, y, z)
		until done
	end)
end

local function isProtected(protects, x, z, radious)
	-- protects = { x=0, z=0, range=128 }
	for _, p in ipairs(protects) do
		if math.abs(p.x - x) + math.abs(p.z - z) <= (p.range or 0) + radious then
			return true
		end
	end
	return false
end

local function refuel()
	if false then
		if not equipLeft(end_automata_id) then
			printError('WARN: no end automata core was found')
			return shell.run('refuel', 10000)
		else
			local tmp_point = 'tmp_point'
			local core = peripheral.wrap('left')
			local ok, err = doUntil(function() return pcall(core.savePoint, tmp_point) end, 20)
			if not ok then
				printError('Cannot save current point: '..err)
				return false, err
			end
			ok, err = doUntil(function() return pcall(core.warpToPoint, refuel_point) end, 20)
			if not ok then
				printError('Cannot warp to point: '..err)
				return false, err
			end
			shell.run('lava_refueler', 'bottom')
			ok, err = doUntil(function() return pcall(core.warpToPoint, tmp_point) end, 20)
			if not ok then
				printError('Cannot warp back to tmp: '..err)
				return false, err
			end
		end
	else
		return shell.run('refuel', 10000)
	end
end

local function placeAndForward(radious, islaunch)
	local ok, protect_positions = pcall(require, 'protects')
	if not ok or not protect_positions then
		printError('WARN: no protects.lua found')
		protect_positions = {}
	end
	radious = radious or 32
	local index = 0
	if islaunch then
		print('Turtle restarted :)')
		local x0, y0, z0
		local oldpos = false
		do
			local fd = io.open(cached_position_path, 'r')
			if fd then
				x0 = tonumber(fd:read())
				y0 = tonumber(fd:read())
				z0 = tonumber(fd:read())
				if z0 and y0 and z0 then
					print('Cached pos:', x0, y0, z0)
					oldpos = true
				end
			end
		end
		rewrite('Locating...')
		equipLeftModem()
		local x, y, z = doUntil(gpsLocate)
		if not(x and y and z) then
			print()
			return false, 'Cannot locate current position'
		end
		reprint('Current pos:', x, y, z)
		sleep(1)
		if oldpos then
			if x ~= x0 or y ~= y0 or z ~= z0 then
				printError('ERROR: position not match')
				return false, 'position not match, program break'
			end
			local fuel = turtle.getFuelLevel()
			if fuel ~= 'unlimited' and fuel < 10000 then
				print()
				refuel()
			end
			rewrite('Destorying old miner...')
			local ok, err = destroy()
			if not ok then
				print()
				return false, err
			end
			fs.delete(cached_position_path)
			doUntil(turtle.back)
			doUntil(turtle.back)
		end
		do
			local fd = io.open(cached_stat_path, 'r')
			if fd then
				index = tonumber(fd:read())
			end
		end
	end

	local x, y, z
	while true do
		rewrite('Locating...')
		equipLeftModem()
		x, y, z = doUntil(gpsLocate)
		if not(x and y and z) then
			print()
			return false, 'Cannot locate current position'
		end
		reprint('Pos:', x, y, z)
		local modem = peripheral.wrap('left')
		rewrite('Broadcasting position...')
		broadcastPos(modem, x, y, z)
		local fd = io.open('position.txt', 'w')
		fd:write(string.format('%d\n%d\n%d', x, y, z))
		fd:close()
		sleep(1)
		local fuel = turtle.getFuelLevel()
		if fuel ~= 'unlimited' and fuel < 10000 then
			print()
			refuel()
		end

		if not isProtected(protect_positions, x, z, radious) then
			-- MINE
			local ok, err = placeMinerAndDestroy(modem)
			if not ok then
				return false, err
			end
		end

		-- MOVE
		equipLeftModem()
		broadcastProcess(modem, 'moving')
		fs.delete(cached_position_path)
		rewrite('Moving...')
		--[[
		 36 35 34 33 32 31 30
		 37 16 15 14 13 12 29
		 38 17  4  3  2 11 28
		 39 18  5  0  1 10 27
		 40 19  6  7  8  9 26
		 41 20 21 22 23 24 25
		 42 43 44 45 46 47 48 49
		 n = math.floor(math.sqrt(m))
		 n * n == m or n * (n + 1) == m
		]]
		if parallel then
			_moveAndBroadcast2(modem, 2 * radious - 2)
		else
			_moveAndBroadcast1(modem, 2 * radious - 2)
		end
		index = index + 1
		do
			local fd = io.open(cached_stat_path, 'w')
			fd:write(string.format('%d\n', index))
			fd:close()
			local n = math.floor(math.sqrt(index))
			if n * n == index or n * n == index - n then
				rewrite('Turn left...')
				doUntil(turtle.turnLeft)
			end
		end
	end
end

local subCommands = {
	place = function(args, i)
		return place()
	end,
	destroy = function(args, i)
		return destroy()
	end,
	placeMinerAndDestroy = function(args, i)
		return placeMinerAndDestroy()
	end,
	placeAndForward = function(args, i)
		local radious = tonumber(args[i + 1])
		local islaunch = args[i + 2] == 'launch' or (not radious and args[i + 1] == 'launch')
		local ok, err = placeAndForward(radious, islaunch)
		if not ok then
			printError(err or 'Failed by unknown reason')
			if enable_teleporter then
				print('Placing emergency teleporter...')
				if not selectItem(teleporter_id) then
					return false, string.format('No item [%s] found', teleporter_id)
				end
				doUntil(turtle.placeDown)
				local teleporter
				repeat
					teleporter = peripheral.wrap('bottom')
					sleep(1)
				until teleporter
				if teleporter.getSecurityMode() == 'PUBLIC' then
					if not hasFrequency(teleporter, emergency_frequency) then
						teleporter.createFrequency(emergency_frequency)
					end
					teleporter.setFrequency(emergency_frequency)
				end
			end
		end
		return ok
	end
}

subCommands.help = function(args, i)
	local sc = args[i + 1]
	print('All subcommands:')
	for c, _ in pairs(subCommands) do
		print('-', c)
	end
end

local function main(args)
	if #args == 0 then
		print('All subcommands:')
		for c, _ in pairs(subCommands) do
			print('-', c)
		end
		return
	end
	local subcmd = args[1]
	local fn = subCommands[subcmd]
	if fn then
		local ok, err = fn(args, 1)
		if not ok then
			printError(err)
		end
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

return main({...})
