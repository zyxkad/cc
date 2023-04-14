-- More turtle actions -- roller
-- by zyxkad@gmail.com

-- Usage: roller = require("roller")

if not turtle then
	error("turtle API not found")
end

local moduleName = ...
local isProgram = not moduleName or moduleName ~= 'roller'

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

local function replaceBlock(items)
	if type(items) == 'string' then
		items = {items}
	end
	if not checkBlock(items) then
		if not selectItems(items) then
			return false, 'No replaceable item found'
		end
		if turtle.detect() and not turtle.dig() then
			return false, 'Cannot dig block'
		end
		if not turtle.place() then
			return false, 'Cannot place block'
		end
	end
	return true
end

local function doUntil(c, failed, max)
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
	until res[1] or (max and i >= max) or (failed and failed(table.unpack(res)))
	return table.unpack(res)
end

local base_blocks = {
	"minecraft:cobblestone",
	"minecraft:stone",
	"minecraft:deepslate",
	"minecraft:cobbled_deepslate",
	"minecraft:dirt",
	"minecraft:grass_block",
	"minecraft:netherrack",
}

local common_rail_block = "minecraft:rail"
local powered_rail_block = "minecraft:powered_rail"
local detector_rail_block = "minecraft:detector_rail"

local function tunnel(n)
	for i = 1, n do
		if not (
			digForwardIfExists() and
			(not turtle.detectUp() or turtle.digUp()) and
			(checkBlock(base_blocks, turtle.inspectDown) or
				((not turtle.detectDown() or turtle.digDown()) and
				selectItems(base_blocks) and turtle.placeDown())) and
			turtle.turnLeft() and (checkBlock(base_blocks) or
				((not turtle.detect() or turtle.dig()) and
				selectItems(base_blocks) and turtle.place())) and
			turtle.turnRight() and turtle.turnRight() and (checkBlock(base_blocks) or
				((not turtle.detect() or turtle.dig()) and
				selectItems(base_blocks) and turtle.place())) and
			turtle.turnLeft()
			) then
			return false
		end
	end
	return true
end

local function railway(n)
	for i = 1, n do
		if not turtle.forward() then
			return false
		end
		local x = i % 7
		local rail = common_rail_block
		if x == 0 or x == 5 then
			rail = detector_rail_block
		elseif x == 6 then
			rail = powered_rail_block
		end
		if not(selectItem(rail) and turtle.placeDown()) then
			return false
		end
	end
	return true
end

local function pool0(dx, dz, dy)
	for y = 1, dy do
		for z = 1, dz, 2 do
			for x = 2, dx do
				doUntil(digForwardIfExists)
			end
			doUntil(turtle.turnRight)
			if z + 1 <= dz then
				doUntil(digForwardIfExists)
			end
			doUntil(turtle.turnRight)
			for x = 2, dx do
				doUntil(digForwardIfExists)
			end
			if z + 2 <= dz then
				doUntil(turtle.turnLeft)
				doUntil(digForwardIfExists)
				doUntil(turtle.turnLeft)
			end
		end
		doUntil(turtle.turnRight)
		for z = 2, dz do
			doUntil(digForwardIfExists)
		end
		doUntil(turtle.turnRight)
		if y ~= dy then
			doUntil(digDownIfExists)
		end
	end
	return true
end

local function pool(dx, dz, dy)
	-- dig and replace border
	for y = 1, dy do
		for x = 1, dx do
			doUntil(turtle.turnLeft)
			doUntil(function() return replaceBlock(base_blocks) end, function() sleep(0.1) end)
			doUntil(turtle.turnRight)
			if x ~= dx then
				doUntil(digForwardIfExists)
			end
		end
		doUntil(turtle.turnRight)
		for z = 1, dz do
			doUntil(turtle.turnLeft)
			doUntil(function() return replaceBlock(base_blocks) end, function() sleep(0.1) end)
			doUntil(turtle.turnRight)
			if z ~= dz then
				doUntil(digForwardIfExists)
			end
		end
		doUntil(turtle.turnRight)
		for x = 1, dx do
			doUntil(turtle.turnLeft)
			doUntil(function() return replaceBlock(base_blocks) end, function() sleep(0.1) end)
			doUntil(turtle.turnRight)
			if x ~= dx then
				doUntil(digForwardIfExists)
			end
		end
		doUntil(turtle.turnRight)
		for z = 1, dz do
			doUntil(turtle.turnLeft)
			doUntil(function() return replaceBlock(base_blocks) end, function() sleep(0.1) end)
			doUntil(turtle.turnRight)
			if z ~= dz then
				doUntil(digForwardIfExists)
			end
		end
		doUntil(turtle.turnRight)
		if y ~= dy then
			doUntil(digDownIfExists)
		end
	end
	-- reset position
	for y = 2, dy do
		doUntil(digUpIfExists)
	end
	if dx > 2 and dz > 2 then
		doUntil(digForwardIfExists)
		doUntil(turtle.turnRight)
		doUntil(digForwardIfExists)
		doUntil(turtle.turnLeft)
		local ok, err = pool0(dx - 2, dz - 2, dy)
		if ok then
			doUntil(turtle.back)
			doUntil(turtle.turnRight)
			doUntil(turtle.back)
			doUntil(turtle.turnLeft)
		end
		return ok, err
	end
	return true
end

---- CLI ----

local subCommands = {
	tunnel = function(arg, i)
		local n = tonumber(arg[i + 1])
		return tunnel(n)
	end,
	railway = function(arg, i)
		local n = tonumber(arg[i + 1])
		return railway(n)
	end,
	pool = function(arg, i)
		local x, z, y = tonumber(arg[i + 1]), tonumber(arg[i + 2]), tonumber(arg[i + 3])
		if not digForwardIfExists() then
			return false, 'Cannot dig forward'
		end
		if not digDownIfExists() then
			return false, 'Cannot dig down'
		end
		local ok, err = pool(x, z, y)
		if ok then
			turtle.up()
			turtle.back()
		end
		return ok, err
	end,
	pool0 = function(arg, i)
		local x, z, y = tonumber(arg[i + 1]), tonumber(arg[i + 2]), tonumber(arg[i + 3])
		return pool0(x, z, y)
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
		local ok, err = fn(arg, 1)
		if not ok then
			if err then
				printError('command failed:', err)
			else
				printError('command failed')
			end
		end
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
	railway = railway,
	pool = pool,
	pool0 = pool0,
}
