-- Thermal tower builder
-- by zyxkad@gmail.com

if not turtle then
	error('turtle API not found')
end

-- Constants
local thermal_block = 'mekanism:thermal_evaporation_block'
local thermal_valve = 'mekanism:thermal_evaporation_valve'
local thermal_controller = 'mekanism:thermal_evaporation_controller'
local structural_glass = 'mekanism:structural_glass'
local max_height = 18 - 1 -- subtract by the base height

local function doUntil(c, failed, max)
	local i = 0
	local res
	repeat
		if i % 2 == 1 then
			sleep(0) -- yield once
		end
		i = i + 1
		res = {c()}
	until res[1] or (max and i >= max) or (failed and failed(table.unpack(res)))
	return table.unpack(res)
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

local function selectAndPlace(item)
	doUntil(function() return selectItem(item) end)
	doUntil(turtle.placeDown)
end

local function build(reverse)
	local turn1
	local turn2
	if reverse then
		turn1 = function() return doUntil(turtle.turnRight) end
		turn2 = function() return doUntil(turtle.turnLeft) end
	else
		turn1 = function() return doUntil(turtle.turnLeft) end
		turn2 = function() return doUntil(turtle.turnRight) end
	end
	doUntil(turtle.up)
	for _ = 1, 3 do
		selectAndPlace(thermal_block)
		doUntil(turtle.forward)
	end
	selectAndPlace(thermal_block)
	turn2()
	for i = 3, 1, -1 do
		for _ = 1, 2 do
			for _ = 1, i do
				doUntil(turtle.forward)
				selectAndPlace(thermal_block)
			end
			turn2()
		end
	end
	for _ = 1, 2 do
		doUntil(turtle.forward)
	end
	turn2()
	doUntil(turtle.back)
	print('end the base')
	for y = 2, max_height do
		doUntil(turtle.up)
		for d = 1, 4 do
			for i = 1, 3 do
				repeat
					local item = structural_glass
					if i == 1 then
						item = thermal_block
					elseif y == 2 and i == 2 then
						if d == 1 then
							-- keep the correct facing direction
							turn2()
							selectAndPlace(thermal_controller)
							turn1()
							doUntil(turtle.forward)
							break
						elseif d == 3 then
							item = thermal_valve
						end
					elseif (y == 4 or y == 6) and d == 3 and i == 2 then
						item = thermal_valve
					end
					selectAndPlace(item)
					doUntil(turtle.forward)
				until true
			end
			print('end a line')
			turn2()
		end
		print('end a level')
	end
	for x = 1, 4 do
		doUntil(turtle.forward)
	end
	for y = 1, max_height do
		doUntil(turtle.down)
	end
	return true
end


---- CLI ----

local subCommands = {
	build1 = function(args, i) -- build left side
		return build(false)
	end,
	build2 = function(args, i) -- build right side
		return build(true)
	end,
	buildLine1 = function(args, i) -- build right side
		for i = 1, 11 do -- build 11
			build(false)
			doUntil(turtle.forward)
		end
		return true
	end,
	buildLine2 = function(args, i) -- build right side
		for i = 1, 11 do -- build 11
			build(true)
			doUntil(turtle.forward)
		end
		return true
	end,
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
		fn(args, 1)
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

if true then
	return main({...})
end

---- END CLI ----
