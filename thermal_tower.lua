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

function build()
	doUntil(turtle.up)
	for _ = 1, 3 do
		selectAndPlace(thermal_block)
		doUntil(turtle.forward)
	end
	selectAndPlace(thermal_block)
	doUntil(turtle.turnRight)
	for i = 3, 1, -1 do
		for _ = 1, 2 do
			for _ = 1, i do
				doUntil(turtle.forward)
				selectAndPlace(thermal_block)
			end
			doUntil(turtle.turnRight)
		end
	end
	for _ = 1, 2 do
		doUntil(turtle.forward)
	end
	doUntil(turtle.turnRight)
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
							doUntil(turtle.turnRight)
							selectAndPlace(thermal_controller)
							doUntil(turtle.turnLeft)
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
			doUntil(turtle.turnRight)
		end
		print('end a level')
	end
	for x = 1, 4 do
		doUntil(turtle.forward)
	end
	for y = 1, max_height do
		doUntil(turtle.down)
	end
end

build()
