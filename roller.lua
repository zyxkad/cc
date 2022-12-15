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
		if noloop then
			return false
		end
		if (not turtle.detect()) or (not turtle.dig()) then
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

local base_blocks = {
	"minecraft:cobblestone",
	"minecraft:dirt",
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
}
