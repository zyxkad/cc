-- GeoScanner Miner
-- by zyxkad@gmail.com
--
-- NOTE: This program will interact on the right side
-- NOTE2: The position is relative to the turtle's home position

local turtleLabel = os.getComputerLabel()
if not turtleLabel then
	error('Please use `label set <label>` give the miner a name')
end

local lps = require('lps')
if not lps.init() then
	print('Turtle facing (+x | -x | +z | -z):')
	local facing = read()
	if not lps.init(facing) then
		error('LPS init failed', 1)
	end
end

---- constants
local pickaxeId = 'minecraft:diamond_pickaxe'
local scannerId = 'advancedperipherals:geo_scanner'
local enderWirelessModemId = 'computercraft:wireless_modem_advanced'
local lavaBucketId = 'minecraft:lava_bucket'

---- BEGIN CONFIG ----

local maxLevel = -48
local minLevel = -62
local targetOres = {
	['#minecraft:block/forge:ores/netherite_scrap'] = 100,
	['#minecraft:block/forge:ores/diamond'] = 10,
	['#minecraft:block/forge:ores/redstone'] = 3,
	['#minecraft:block/forge:ores/coal'] = 1,
}
local targetItems = {
	['minecraft:ancient_debris'] = 1,
	['minecraft:redstone'] = 1,
	['minecraft:diamond'] = 1,
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

local function digForwardIfExists(noloop)
	while not turtle.forward() do
		if (not turtle.detect()) or (not turtle.dig()) then
			return false
		end
		if noloop then
			return false
		end
	end
	return true
end

local function digUpIfExists(noloop)
	while not turtle.up() do
		if (not turtle.detectUp()) or (not turtle.digUp()) then
			return false
		end
		if noloop then
			return false
		end
	end
	return true
end

local function digDownIfExists(noloop)
	while not turtle.down() do
		if (not turtle.detectDown()) or (not turtle.digDown()) then
			return false
		end
		if noloop then
			return false
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
	print(string.format('Goto %s %s %s ...', x, y, z))
	local x0, y0, z0 = lps.locate()
	if y then
		local dy = y - y0
		if dy > 0 then
			for i = 1, dy do
				if not doUntil(digUpIfExists, 5) then
					return false
				end
			end
		elseif dy < 0 then
			for i = 1, -dy do
				if not doUntil(digDownIfExists, 5) then
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
				if not doUntil(digForwardIfExists, 5) then
					return false
				end
			end
		elseif dz < 0 then
			turnTo('-z')
			for i = 1, -dz do
				if not doUntil(digForwardIfExists, 5) then
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
				if not doUntil(digForwardIfExists, 5) then
					return false
				end
			end
		elseif dx < 0 then
			turnTo('-x')
			for i = 1, -dx do
				if not doUntil(digForwardIfExists, 5) then
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
	return c > 10
end

--- end utils


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
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail then
			local name = detail.name
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
		end
	end
end

local limit = turtle.getFuelLimit()

local function check(blocks)
	blocks = blocks or 0
	local dis = distance()
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
	if not peripheral.hasType('right', 'geoScanner') then
		print('Finding geoScanner')
		if not selectItem(scannerId) then
			printError('GeoScanner not found')
			return nil, 'GeoScanner not found'
		end
		turtle.equipRight()
	end
	local scanner = peripheral.wrap('right')
	local scaned, err = scanner.scan(scanner.getConfiguration().scanBlocks.maxFreeRadius)
	turtle.equipRight()
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

local function equipPickaxe()
	if selectItem(pickaxeId) then
		turtle.equipRight()
	end
end

local function broadcastPosition()
	while true do
		if not peripheral.hasType('right', 'modem') then
			if not selectItem(enderWirelessModemId) then
				return false
			end
			turtle.equipRight()
		end
		if pcall(rednet.open, 'right') then
			local x, y, z = lps.locate()
			rednet.broadcast({
				name = turtleLabel,
				x = x,
				y = y,
				z = z,
				fuel = turtle.getFuelLevel(),
			}, 'turtle_geo_miner')
			turtle.equipRight()
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
		broadcastPosition()
		equipPickaxe()
		local ores, err = scan()
		if not ores then
			return false, err
		end
		print('Found '..#ores..' ores')
		if #ores == 0 then
			for i = 1, 16 do
				if not check() then
					return true
				end
				digForwardIfExists()
			end
		elseif not digOres(ores) then
			local x, y, z = lps.locate()
			if (math.abs(x) +  math.abs(y) + math.abs(z)) * 2 < limit then
				local fd = fs.open(posCacheName, 'w')
				fd.write(textutils.serialiseJSON({x, y, z}))
				fd.close()
			end
			return true
		elseif os.clock() > deadline or not hasFreeSlot() then
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
	equipPickaxe()
	print('Going home ...')
	local x, y, z = lps.locate()
	if x > 0 then
		turnTo('-x')
		for i = 1, x do
			doUntil(digForwardIfExists)
		end
	elseif x < 0 then
		turnTo('+x')
		for i = 1, -x do
			doUntil(digForwardIfExists)
		end
	end
	if z > 0 then
		turnTo('-z')
		for i = 1, z do
			doUntil(digForwardIfExists)
		end
	elseif z < 0 then
		turnTo('+z')
		for i = 1, -z do
			doUntil(digForwardIfExists)
		end
	end
	if y < 0 then
		for i = 1, -y do
			doUntil(digUpIfExists)
		end
	end
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
	shell.run('coal_refueler')
	if turtle.getFuelLevel() * 2 < limit then
		return false
	end
	return true
end

function main(args)
	sleep(3)
	while true do
		local fd = fs.open(posCacheName, 'r')
		local flag = false
		if fd then
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
			local y = math.random(minLevel, maxLevel)
			turnTo(({'+x', '-x', '+z', '-z'})[math.random(1, 4)])
			while not doWithBroadcastPos(goPos, nil, y, nil) do
				doWithBroadcastPos(goHome)
				if not refuel() then
					printError('Refuel failed')
					return
				end
			end
		end
		scanAndDig()
		doWithBroadcastPos(goHome)
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
		refuel()
	end
end

main({...})
