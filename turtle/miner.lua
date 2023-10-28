-- More turtle actions -- miner
-- by zyxkad@gmail.com

-- Usage: miner = require("miner")

if not turtle then
	error("turtle API not found")
end

local moduleName = ...
local isProgram = not moduleName or moduleName ~= 'miner'

local function digForwardIfExists(noloop)
	while not turtle.forward() do
		if noloop then
			return false
		end
		if (not turtle.detect()) or (not turtle.dig()) then
			return false
		end
	end
	return true
end

local function findInArray(arr, item)
	return table.foreachi(arr, function(i, v)
		if v == item then
			return i
		end
	end)
end

local function checkBlock(targets, checker)
	checker = checker or turtle.inspect
	local ok, blk = checker()
	if not ok then
		return false
	end
	for _, t in ipairs(targets) do
		if blk.name == t then
			return true
		end
	end
	return false
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

local function selectItems(items)
	for _, item in ipairs(items) do
		if selectItem(item) then
			return true
		end
	end
	return false
end


local function tunnel(n)
	for i = 1, n do
		if not (
			digForwardIfExists() and
			(not turtle.detectUp() or turtle.digUp())) then
			return false
		end
	end
end

local function tunnel3x3(n)
	for i = 1, n do
		if not (
			digForwardIfExists() and
			turtle.turnLeft() and (not turtle.detect() or turtle.dig()) and
			(not turtle.detectUp() or turtle.digUp()) and turtle.up() and
			(not turtle.detect() or turtle.dig()) and
			(not turtle.detectUp() or turtle.digUp()) and turtle.up() and
			(not turtle.detect() or turtle.dig()) and turtle.turnRight() and turtle.turnRight() and
			(not turtle.detect() or turtle.dig()) and turtle.down() and
			(not turtle.detect() or turtle.dig()) and turtle.down() and
			(not turtle.detect() or turtle.dig()) and turtle.turnLeft()
			) then
			return false
		end
	end
end

local function mineTunnel(n)
	for i = 1, n do
		if not (
			digForwardIfExists() and
			(not turtle.detectUp() or turtle.digUp()) and
			(not turtle.detectDown() or turtle.digDown()) and turtle.down()
			) then
			return false
		end
	end
	return true
end

local function escapeTunnel(n)
	for i = 1, n do
		if not (
			digForwardIfExists() and
			(not turtle.detectUp() or turtle.digUp()) and turtle.up() and
			(not turtle.detectUp() or turtle.digUp())
			) then
			return false
		end
	end
	return true
end

local commonBlock = {
	"minecraft:dirt",
	"minecraft:cobblestone",
	"minecraft:cobbled_deepslate",
	"minecraft:stone",
	"minecraft:deepslate",
	"minecraft:netherrack",
	"minecraft:soul_soil",
	"minecraft:tuff",
	"minecraft:dripstone_block",
	"minecraft:smooth_basalt",
	"minecraft:granite",
	"minecraft:diorite",
	"minecraft:andesite",
	"minecraft:calcite",
	"minecraft:grassblock",
	"byg:soapstone",
}

local lightSources = {
	"minecraft:torch"
}

local function fillACommon(placer, _bDebug)
	if selectItems(commonBlock) then
		if placer() then
			return true
		end
		print('Cannot place block')
	elseif _bDebug then
		print('Cannot find block to fill')
	end
	return false
end

local function cleanInventory(dropper)
	dropper = dropper or turtle.drop
	local slots = {}
	local free = 16
	for i = 1, 16 do
		local d = turtle.getItemDetail(i)
		if d then
			free = free - 1
			slots[i] = d
		end
	end
	if free == 0 then
		for i, v in ipairs(slots) do
			if v and findInArray(commonBlock, v.name) then
				turtle.select(i)
				dropper()
				break
			end
		end
	end
end

local function mineChunk(_bDebug)
	for x = 0, 15 do
		for z = 0, 15 do
			if (x == 0 or z == 0) or (x == 15 or z == 15) then
				if turtle.detectUp() and not turtle.digUp() then
					if _bDebug then
						print('Turtle cannot dig up')
					end
				end
				if turtle.detectDown() and not turtle.digDown() then
					if _bDebug then
						print('Turtle cannot dig down')
					end
				end
			else
				local ok, d = turtle.inspectUp()
				if ok then
					if not findInArray(commonBlock, d.name) then
						turtle.digUp()
						fillACommon(turtle.placeUp, _bDebug)
					end
				else
					fillACommon(turtle.placeUp, _bDebug)
				end
				local ok, d = turtle.inspectDown()
				if ok then
					if not findInArray(commonBlock, d.name) then
						turtle.digDown()
						fillACommon(turtle.placeDown, _bDebug)
					end
				else
					fillACommon(turtle.placeDown, _bDebug)
				end
			end
			if not digForwardIfExists() then
				return false, 'Turtle cannot dig or move forward'
			end
			cleanInventory()
			if x % 5 == 0 and z % 5 == 0 then
				if selectItems(lightSources) then
					if not turtle.placeDown() then
						print('Cannot place light source')
					end
				elseif _bDebug then
					print('Cannot find any light source')
				end
			end
		end
		if turtle.detectUp() and not turtle.digUp() then
			if _bDebug then
				print('Turtle cannot dig up')
			end
		end
		if turtle.detectDown() and not turtle.digDown() then
			if _bDebug then
				print('Turtle cannot dig down')
			end
		end
		if x % 2 == 0 then
			if not turtle.turnRight() then
				return false, 'Turtle cannot turn right'
			end
			if not digForwardIfExists() then
				return false, 'Turtle cannot dig or move forward'
			end
			if not turtle.turnRight() then
				return false, 'Turtle cannot turn right'
			end
		else
			if not turtle.turnLeft() then
				return false, 'Turtle cannot turn left'
			end
			if not digForwardIfExists() then
				return false, 'Turtle cannot dig or move forward'
			end
			if not turtle.turnLeft() then
				return false, 'Turtle cannot turn left'
			end
		end
		if turtle.detectUp() and not turtle.digUp() then
			if _bDebug then
				print('Turtle cannot dig up')
			end
		end
		if turtle.detectDown() and not turtle.digDown() then
			if _bDebug then
				print('Turtle cannot dig down')
			end
		end
		cleanInventory()
	end
	for z = 0, 15 do
		turtle.back()
	end
	turtle.turnLeft()
	for x = 0, 15 do
		turtle.forward()
	end
	turtle.turnRight()
	return true
end

---- CLI ----

local subCommands = {
	tunnel = function(arg, i)
		local n = tonumber(arg[i + 1])
		return tunnel(n)
	end,
	tunnel3x3 = function(arg, i)
		local n = tonumber(arg[i + 1])
		return tunnel3x3(n)
	end,
	mineTunnel = function(arg, i)
		local n = tonumber(arg[i + 1])
		return mineTunnel(n)
	end,
	escapeTunnel = function(arg, i)
		local n = tonumber(arg[i + 1])
		return escapeTunnel(n)
	end,
	mineChunk = function(arg, i)
		if not digForwardIfExists() then
			return false, 'Turtle cannot dig or move forward'
		end
		local ok, err mineChunk(true)
		if ok then
			turtle.back()
		end
		return ok, err
	end
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
	tunnel = tunnel,
	tunnel3x3 = tunnel3x3,
	mineTunnel = mineTunnel,
	escapeTunnel = escapeTunnel,
}
