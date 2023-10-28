-- GeoScanner Miner
-- by zyxkad@gmail.com
-- NOTE: This program will interact with the right side

local lps = require('lps')
if not lps.init() then
	print('Turtle facing (+x | -x | +z | -z):')
	local facing = read()
	if not lps.init(facing) then
		error('LPS init failed', 1)
	end
end

local pickaxeId = 'minecraft:diamond_pickaxe'
local scannerId = 'advancedperipherals:geo_scanner'

-- 0 ~ 50
-- place at y = 50
local maxLevel = -10
local minLevel = -50
local targetOre = '#minecraft:block/forge:ores/osmium'
local targetItems = {
	['mekanism:raw_osmium'] = 1,
}
local coalOre = '#minecraft:block/forge:ores/coal'
local coalId = 'minecraft:coal'

local posCacheName = '/geoPos.json'

--- begin utils

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
	for i = 1, 16 do
		local count = turtle.getItemCount(i)
		if count == 0 then
			return true
		end
	end
	return false
end

--- end utils


local function distance()
	local x, y, z = lps.locate()
	return math.abs(x) + math.abs(y) + math.abs(z)
end

local function refuel()
	local flag = false
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if detial and detial.name == coalId then
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
			elseif not targetItems[name] and name ~= pickaxeId and name ~= scannerId then
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
	if peripheral.getType('right') ~= 'geoScanner' then
		print('selecting item')
		if not selectItem(scannerId) then
			print('scanner not found')
			return nil, 'scanner not found'
		end
		turtle.equipRight()
	end
	local scanner = peripheral.wrap('right')
	local scaned, err = scanner.scan(scanner.getConfiguration().scanBlocks.maxFreeRadius)
	turtle.equipRight()
	local x, y, z = lps.locate()
	local ores = {}
	for _, d in pairs(scaned) do
		if y + d.y < maxLevel then
			for _, t in pairs(d.tags) do
				t = '#'..t
				if t == targetOre then
					ores[#ores + 1] = {
						x = x + d.x,
						y = y + d.y,
						z = z + d.z,
						v = 2,
					}
					break
				elseif t == coalOre then
					ores[#ores + 1] = {
						x = x + d.x,
						y = y + d.y,
						z = z + d.z,
						v = 1,
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

local function scanAndDig()
	equipPickaxe()
	while true do
		local ores = scan()
		print('Found '..#ores..' ores')
		if #ores == 0 then
			for i = 1, 8 do
				if not check() then
					return
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
			return
		elseif not hasFreeSlot() then
			cleanInventory()
			if not hasFreeSlot() then
				local fd = fs.open(posCacheName, 'w')
				fd.write(textutils.serialiseJSON({x, y, z}))
				fd.close()
				return
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

function main(args)
	while true do
		shell.run('lava_refueler')
		local fd = fs.open(posCacheName, 'r')
		local flag = false
		if fd then
			local last = textutils.unserialiseJSON(fd.readAll())
			fd.close()
			if last then
				while not goPos(last.x, last.y, last.z) do
					goHome()
					shell.run('lava_refueler')
					flag = true
				end
				fs.delete(posCacheName)
			end
		end
		if not flag then
			local y = math.random(minLevel, maxLevel)
			turnTo(({'+x', '-x', '+z', '-z'})[math.random(1, 4)])
			while not goPos(nil, y, nil) do
				goHome()
				shell.run('lava_refueler')
			end
		end
		scanAndDig()
		goHome()
		for i = 1, 16 do
			local detial = turtle.getItemDetail(i)
			if detial then
				local item = detial.name
				if item == coalId then
					turtle.select(i)
					turtle.refuel(detail.count)
				end
				if item ~= pickaxeId and item ~= scannerId then
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
end

main({...})
