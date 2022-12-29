-- Digital miner
-- by zyxkad@gmail.com

if not turtle then
	error('turtle API not found')
end

local debuging = false

local miner_frequency = os.getComputerLabel()
local emergency_frequency = miner_frequency..'Err'
local digital_miner_id = 'mekanism:digital_miner'
local cable_id = 'mekanism:advanced_universal_cable'
local transporter_id = 'mekanism:advanced_logistcial_transporter'
local teleporter_id = 'mekanism:teleporter'
local quantum_porter_id = 'mekanism:quantum_entangloporter'
local diamond_pickaxe_id = 'minecraft:diamond_pickaxe'
local ender_wireless_modem_id = 'computercraft:wireless_modem_advanced'
local wireless_modem_id = 'computercraft:wireless_modem_normal'

local function doUntil(c, failed, max)
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
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
	if not selectItem(teleporter_id) then
		return false, string.format('No item [%s] found', teleporter_id)
	end
	doUntil(turtle.placeUp)
	local teleporter
	repeat
		teleporter = peripheral.wrap('top')
	until teleporter
	if not hasFrequency(teleporter, miner_frequency) then
		teleporter.createFrequency(miner_frequency)
	end
	teleporter.setFrequency(miner_frequency)
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

local function broadcastProcess(modem, remain)
	rednet.open(peripheral.getName(modem))
	local monitors = {rednet.lookup('miner_monitor')}
	for _, m in ipairs(monitors) do
		rednet.send(m, {
			id = miner_frequency,
			typ = 'process',
			remain = remain,
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

local function broadcastPos(modem, x, y, z)
	rednet.open(peripheral.getName(modem))
	local monitors = {rednet.lookup('miner_monitor')}
	for _, m in ipairs(monitors) do
		rednet.send(m, {
			id = miner_frequency,
			typ = 'pos',
			x = x, y = y, z = z,
		}, 'digital_miner')
	end
	rednet.close(peripheral.getName(modem))
end

local function placeAndForward(radious, islaunch)
	radious = radious or 32
	if islaunch then
		print('Turtle restarted :)')
		local x0, y0, z0
		local oldpos = false
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
		rewrite('Locating...')
		equipLeftModem()
		local x, y, z = gps.locate(2, debuging)
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
			rewrite('Destorying old miner...')
			local ok, err = destroy()
			if not ok then
				print()
				return false, err
			end
			fs.delete(cached_position_path)
		end
	end

	local x, y, z
	while true do
		rewrite('Locating...')
		equipLeftModem()
		x, y, z = gps.locate(2, debuging)
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
		local ok, err = placeMinerAndDestroy(modem)
		if not ok then
			return false, err
		end
		equipLeftModem()
		broadcastProcess(modem, 'moving')
		fs.delete(cached_position_path)
		rewrite('Moving...')
		for i = 1, 2 * radious do
			ok, _, err = doUntil(turtle.forward, 3)
			if not ok then
				print()
				broadcastProcess(modem, 'error', err or 'Turtle cannot move forward')
				return false, err
			end
			rewrite(string.format('Moved %d blocks...', i))
			broadcastPos(modem, x, y, z)
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
			if not hasFrequency(teleporter, emergency_frequency) then
				teleporter.createFrequency(emergency_frequency)
			end
			teleporter.setFrequency(emergency_frequency)
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
