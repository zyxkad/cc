-- GeoScanner Miner
-- by zyxkad@gmail.com
--
-- NOTE: This program will interact on the left side
-- NOTE2: The position is relative to the turtle's home position

local turtleLabel = os.getComputerLabel()
if not turtleLabel then
	error('Please use `label set <label>` give the miner a name')
end

local lps = require('lps')

local initDirection = nil
if not lps.init() then
	print('Turtle facing (+x | -x | +z | -z):')
	local facing = read()
	if not lps.init(facing) then
		error('LPS init failed', 1)
	end
	initDirection = facing
	local fd = assert(fs.open('.init_direction.json', 'w'))
	fd.write(textutils.serialiseJSON(initDirection))
	fd.close()
end

if not initDirection then
	local fd = assert(fs.open('.init_direction.json', 'r'))
	initDirection = textutils.unserialiseJSON(fd.readAll())
	fd.close()
	assert(type(initDirection) == 'string')
end

---- constants
local pickaxeId = 'minecraft:diamond_pickaxe'
local scannerId = 'advancedperipherals:geo_scanner'
local enderWirelessModemId = 'computercraft:wireless_modem_advanced'
local lavaBucketId = 'minecraft:lava_bucket'

---- BEGIN CONFIG ----

local currentLevel = 82

local maxLevel = 13 - currentLevel
local minLevel = -30 - currentLevel

if turtleLabel:find('nether') then
	maxLevel = 20 - currentLevel
	minLevel = 6 - currentLevel
end

local targetOres = {
	['#minecraft:block/forge:ores/netherite_scrap'] = 100,
	['#minecraft:block/forge:ores/diamond'] = 10,
	['#minecraft:block/forge:ores/gold'] = 5,
	['#minecraft:block/forge:ores/iron'] = 5,
	['#minecraft:block/forge:ores/zinc'] = 3,
	['#minecraft:block/forge:ores/redstone'] = 2,
	-- ['#minecraft:block/forge:ores/copper'] = 1,
	['#minecraft:block/forge:ores/coal'] = 1,
}
local targetItems = {
	['minecraft:ancient_debris'] = 1,
	['minecraft:diamond'] = 1,
	['minecraft:redstone'] = 1,
	['minecraft:raw_iron'] = 1,
	['minecraft:raw_gold'] = 1,
	['minecraft:gold_nugget'] = 1,
	['minecraft:raw_copper'] = 1,
	['create:raw_zinc'] = 1,
}
local coalId = 'minecraft:coal'

---- END CONFIG ----

local posCacheName = '/geoPos.json'

--- begin utils

local function selectItem(item)
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail and detail.name == item then
			turtle.select(i)
			return true
		end
	end
	return false
end

local function doUntil(c, max)
	if c == nil then
		error('the first arguemnt is not a function')
	end
	local i = 1
	local res
	while true do
		res = {c()}
		if res[1] or (max and i >= max) then
			break
		end
		i = i + 1
		sleep(0)
	end
	return table.unpack(res)
end

local function equipPickaxe()
	if selectItem(pickaxeId) then
		turtle.equipLeft()
	end
end

local function digForwardIfExists(count)
	while not turtle.forward() do
		if (not turtle.detect()) or (not turtle.dig()) then
			if count == false then
				return false
			elseif type(count) == 'number' then
				if count <= 0 then
					return false
				end
				count = count - 1
			end
		end
	end
	return true
end

local function digUpIfExists(count)
	while not turtle.up() do
		if (not turtle.detectUp()) or (not turtle.digUp()) then
			if count == false then
				return false
			elseif type(count) == 'number' then
				if count <= 0 then
					return false
				end
				count = count - 1
			end
		end
	end
	return true
end

local function digDownIfExists(count)
	while not turtle.down() do
		if (not turtle.detectDown()) or (not turtle.digDown()) then
			if count == false then
				return false
			elseif type(count) == 'number' then
				if count <= 0 then
					return false
				end
				count = count - 1
			end
		end
	end
	return true
end

local function turnTo(d)
	local f = lps.facing()
	if d == '+x' then
		if f == '+x' then
		elseif f == '-x' then doUntil(turtle.turnRight) doUntil(turtle.turnRight)
		elseif f == '+z' then doUntil(turtle.turnLeft)
		elseif f == '-z' then doUntil(turtle.turnRight)
		end
	elseif d == '-x' then
		if f == '+x' then doUntil(turtle.turnRight) doUntil(turtle.turnRight)
		elseif f == '-x' then
		elseif f == '-z' then doUntil(turtle.turnLeft)
		elseif f == '+z' then doUntil(turtle.turnRight)
		end
	elseif d == '-z' then
		if f == '+x' then doUntil(turtle.turnLeft)
		elseif f == '-x' then doUntil(turtle.turnRight)
		elseif f == '-z' then
		elseif f == '+z' then doUntil(turtle.turnRight) doUntil(turtle.turnRight)
		end
	elseif d == '+z' then
		if f == '+x' then doUntil(turtle.turnRight)
		elseif f == '-x' then doUntil(turtle.turnLeft)
		elseif f == '-z' then doUntil(turtle.turnRight) doUntil(turtle.turnRight)
		elseif f == '+z' then
		end
	end
end

local function goPos(x, y, z)
	equipPickaxe()
	print(string.format('Goto %s %s %s ...', x, y, z))
	local x0, y0, z0 = lps.locate()
	if y then
		local dy = y - y0
		if dy > 0 then
			for i = 1, dy do
				if not digUpIfExists(5) then
					return false
				end
			end
		elseif dy < 0 then
			for i = 1, -dy do
				if not digDownIfExists(5) then
					return false
				end
			end
		end
	end
	if z then
		local dz = z - z0
		if dz > 0 then
			turnTo('+z')
			for i = 1, dz do
				if not digForwardIfExists(5) then
					return false
				end
			end
		elseif dz < 0 then
			turnTo('-z')
			for i = 1, -dz do
				if not digForwardIfExists(5) then
					return false
				end
			end
		end
	end
	if x then
		local dx = x - x0
		if dx > 0 then
			turnTo('+x')
			for i = 1, dx do
				if not digForwardIfExists(5) then
					return false
				end
			end
		elseif dx < 0 then
			turnTo('-x')
			for i = 1, -dx do
				if not digForwardIfExists(5) then
					return false
				end
			end
		end
	end
	local x1, y1, z1 = lps.locate()
	x = x or x0
	y = y or y0
	z = z or z0
	if x1 ~= x or y1 ~= y or z1 ~= z then
		error(string.format('Position not match, expect %d %d %d but arrived %d %d %d', x, y, z, x1, y1, z1))
	end
	print('Arrived!')
	return true
end

local function hasFreeSlot()
	local c = 0
	for i = 1, 16 do
		local count = turtle.getItemCount(i)
		if count == 0 then
			c = c + 1
		end
	end
	return c > 3
end

--- end utils

local action = nil

local function distance()
	local x, y, z = lps.locate()
	return math.abs(x) + math.abs(y) + math.abs(z)
end

local function refuel()
	local flag = false
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail and detail.name == coalId then
			turtle.select(i)
			turtle.refuel(flag and detail.count or detail.count - 1)
			flag = true
		end
	end
end

local function cleanInventory()
	print('cleaning inventory')
	local flag = false
	local details = {}
	local items = {}
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail then
			local name = detail.name
			local first = items[name]
			if first then
				turtle.select(i)
				turtle.transferTo(first)
				detail.count = turtle.getItemCount(i)
			end
			if detail.count > 0 then
				if name == coalId then
					turtle.select(i)
					turtle.refuel(flag and detail.count or detail.count - 1)
					if flag then
						turtle.dropDown(detail.count)
					end
					flag = true
				elseif not targetItems[name] and name ~= pickaxeId and name ~= scannerId and name ~= enderWirelessModemId and name ~= lavaBucketId then
					turtle.select(i)
					turtle.dropDown(detail.count)
				end
				detail.count = turtle.getItemCount(i)
				detail.space = turtle.getItemSpace(i)
				if detail.count > 0 then
					details[i] = detail
					if detail.space > 0 then
						items[detail.name] = i
					end
				end
			end
		end
	end
end

local limit = turtle.getFuelLimit()

local function check(blocks)
	blocks = blocks or 0
	local error = 10
	local dis = distance() + error
	local fuel = turtle.getFuelLevel()
	if fuel - blocks <= dis then
		refuel()
		if fuel - blocks <= dis then
			return false
		end
	end
	return true
end

local function scan()
	print('Scanning...')
	if not peripheral.hasType('left', 'geoScanner') then
		-- print('Finding geoScanner')
		if not selectItem(scannerId) then
			printError('GeoScanner not found')
			return nil, 'GeoScanner not found'
		end
		turtle.equipLeft()
	end
	local scanner = peripheral.wrap('left')
	local scaned, err = scanner.scan(scanner.getConfiguration().scanBlocks.maxFreeRadius)
	turtle.equipLeft()
	local x, y, z = lps.locate()
	local ores = {}
	for _, d in pairs(scaned) do
		local y1 = y + d.y
		if minLevel <= y1 and y1 < maxLevel then
			for _, t in pairs(d.tags) do
				t = '#'..t
				local v = targetOres[t]
				if v then
					ores[#ores + 1] = {
						x = x + d.x,
						y = y + d.y,
						z = z + d.z,
						v = v,
					}
					break
				end
			end
		end
	end
	return ores
end

local function popNearestOre(ores)
	local x, y, z = lps.locate()
	local l = #ores
	local j = 1
	local o = ores[1]
	local n = (math.abs(x - o.x) + math.abs(y - o.y) + math.abs(z - o.z)) / o.v
	if l == 1 then
		ores[1] = nil
		return o
	end
	for i, d in pairs(ores) do
		local m = (math.abs(x - d.x) + math.abs(y - d.y) + math.abs(z - d.z)) / d.v
		if m < n then
			j = i
			o = d
			n = m
		end
	end
	if j ~= l then
		ores[j] = ores[l]
	end
	ores[l] = nil
	return o, n * o.v
end

local function digOres(ores)
	cleanInventory()
	while #ores > 0 do
		local ore, n = popNearestOre(ores)
		if not check(n) then
			return false
		end
		goPos(ore.x, ore.y, ore.z)
	end
	return true
end

local function broadcastPosition()
	while true do
		if not peripheral.hasType('left', 'modem') then
			if not selectItem(enderWirelessModemId) then
				return false
			end
			turtle.equipLeft()
		end
		if pcall(rednet.open, 'left') then
			local x, y, z = lps.locate()
			rednet.broadcast({
				name = turtleLabel,
				x = x,
				y = y,
				z = z,
				fuel = turtle.getFuelLevel(),
				act = action,
			}, 'turtle_geo_miner')
			turtle.equipLeft()
			return
		end
		sleep(0)
	end
end

local function scanAndDig()
	local start = os.clock()
	local maxMiningTime = 60 * 60
	local deadline = start + maxMiningTime
	while true do
		action = nil
		local ores, err = scan()
		if not ores then
			broadcastPosition()
			equipPickaxe()
			return false, err
		end
		action = #ores .. ' ores'
		broadcastPosition()
		equipPickaxe()
		print('Found ' .. #ores .. ' ores')
		if #ores == 0 then
			local range = 16
			if not check(range) then
				return true
			end
			local r = math.random(1, 64)
			if r < 8 then
				turtle.turnRight()
			elseif r == 8 then
				turtle.turnLeft()
			end
			for i = 1, range do
				digForwardIfExists()
			end
		elseif not digOres(ores) then
			print('digOres failed')
			local x, y, z = lps.locate()
			if (math.abs(x) +  math.abs(y) + math.abs(z)) * 2 < limit then
				local fd = fs.open(posCacheName, 'w')
				fd.write(textutils.serialiseJSON({x, y, z}))
				fd.close()
			end
			return true
		elseif os.clock() > deadline then
			print('deadline exceeded')
			local fd = fs.open(posCacheName, 'w')
			fd.write(textutils.serialiseJSON({x, y, z}))
			fd.close()
			return true
		elseif not hasFreeSlot() then
			print('inventory full')
			cleanInventory()
			if not hasFreeSlot() then
				local fd = fs.open(posCacheName, 'w')
				fd.write(textutils.serialiseJSON({x, y, z}))
				fd.close()
				return true
			end
		end
	end
end

local function goHome()
	action = 'homing'
	equipPickaxe()
	print('Going home ...')
	local x, y, z = lps.locate()
	if x > 0 then
		turnTo('-x')
		for i = 1, x do
			digForwardIfExists()
		end
	elseif x < 0 then
		turnTo('+x')
		for i = 1, -x do
			digForwardIfExists()
		end
	end
	if z > 0 then
		turnTo('-z')
		for i = 1, z do
			digForwardIfExists()
		end
	elseif z < 0 then
		turnTo('+z')
		for i = 1, -z do
			digForwardIfExists()
		end
	end
	if y < 0 then
		for i = 1, -y do
			digUpIfExists()
		end
	end
	turnTo(initDirection)
	print('Arrived home!')
end

local function doWithBroadcastPos(fn, ...)
	local args = table.pack(...)
	local res
	parallel.waitForAny(function()
		res = fn(table.unpack(args, 1, args.n))
	end, function()
		while true do
			broadcastPosition()
			sleep(10)
		end
	end)
	return res
end

local function refuel()
	action = 'refuel'
	shell.run('lava_refueler')
	if turtle.getFuelLevel() * 2 < limit then
		return false
	end
	action = nil
	return true
end

local function sortItem()
	print('Sorting items ...')
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail then
			local item = detail.name
			if item == coalId then
				turtle.select(i)
				turtle.refuel(detail.count)
			end
			if item ~= pickaxeId and item ~= scannerId and item ~= lavaBucketId and item ~= enderWirelessModemId then
				turtle.select(i)
				local p = targetItems[item]
				if p then
					turtle.dropUp()
				else
					turtle.dropDown()
				end
			end
		end
	end
end

function main(args)
	print('min level:', minLevel)
	print('max level:', maxLevel)
	while true do
		print('Waiting ...')
		sleep(3)
		do
			local x, y, z = lps.locate()
			if x == 0 and y == 0 and z == 0 and turtle.detectUp() then
				sortItem()
			end
		end
		local fd = fs.open(posCacheName, 'r')
		local flag = false
		if fd then
			action = 'restoring'
			local last = textutils.unserialiseJSON(fd.readAll())
			fd.close()
			if last then
				while not doWithBroadcastPos(goPos, last.x, last.y, last.z) do
					doWithBroadcastPos(goHome)
					if not refuel() then
						printError('Refuel failed')
						return
					end
					flag = true
				end
				fs.delete(posCacheName)
			end
		end
		if not flag then
			action = 'started'
			local y = math.random(minLevel, maxLevel)
			turnTo(({'+x', '-x', '+z', '-z'})[math.random(1, 4)])
			local c = 0
			while not doWithBroadcastPos(goPos, nil, y, nil) do
				c = c + 1
				print('Failed to init position and going home ' .. c)
				doWithBroadcastPos(goHome)
				if not refuel() then
					printError('Refuel failed')
					return
				end
			end
		end
		scanAndDig()
		doWithBroadcastPos(goHome)
		action = 'homed'
		broadcastPosition()
		repeat sleep(1) until turtle.detectUp()
		sortItem()
		refuel()
	end
end

main({...})
