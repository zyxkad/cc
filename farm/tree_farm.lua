-- Tree Farmer
-- by zyxkad@gmail.com

local function checkEnoughFuel()
	local level = turtle.getFuelLevel()
	return level == 'unlimited' or level >= 100
end

local function fillSupplies()
	print('Filling supplies ...')
	repeat until not turtle.suckDown()
	print('Refueling (' .. turtle.getFuelLevel() .. ') ...')
	turtle.select(9)
	while not checkEnoughFuel() do
		turtle.refuel(turtle.getItemCount() - 1)
		turtle.suck()
	end
	print('Turtle prepared')
end

local function checkIsLog()
	local ok, block = turtle.inspect()
	if not ok then
		return nil
	end
	if block.tags['minecraft:logs'] then
		return 'log'
	elseif block.tags['minecraft:saplings'] then
		return 'sapling'
	end
	return false
end

local function getMarkFacing()
	local ok, block = turtle.inspectDown()
	if not ok or block.name ~= 'minecraft:wall_torch' then
		return nil
	end
	local facing = block.state.facing
	if facing == 'north' then
		return 0
	elseif facing == 'west' then
		return 1
	elseif facing == 'south' then
		return 2
	elseif facing == 'east' then
		return 3
	end
	error('Unexpected facing state')
end

local function digTree()
	while true do
		local ok, block = turtle.inspectUp()
		if not ok or not block.tags['minecraft:logs'] then
			break
		end
		repeat assert(turtle.digUp()) until turtle.up()
	end
	while true do
		if not turtle.down() then
			local ok, block = turtle.inspectDown()
			if ok and (block.tags['minecraft:logs'] or block.tags['minecraft:leaves']) then
				repeat assert(turtle.digDown()) until turtle.down()
			else
				break
			end
		end
	end
end

local function doAStep()
	local typ = checkIsLog()
	if typ == 'log' then
		assert(turtle.dig())
		assert(turtle.forward())
		digTree()
		assert(turtle.up())
	else
		assert(turtle.up())
		assert(turtle.forward())
	end
	if not turtle.detectDown() and turtle.getItemCount(1) > 1 then
		turtle.select(1)
		turtle.placeDown()
	end
	assert(turtle.forward())
	assert(turtle.down())
	turtle.select(2)
	turtle.dropDown(turtle.getItemCount() - 1)
end

local function returnToHome()
	print('Returning to home ...')
	assert(turtle.back())
	assert(turtle.turnRight())
	assert(turtle.back())
	assert(turtle.back())
	assert(turtle.turnLeft())
	assert(turtle.back())
	while turtle.detectDown() do
		assert(turtle.back())
		assert(turtle.back())
	end
	assert(turtle.forward())
	assert(turtle.forward())
	assert(turtle.forward())
	assert(turtle.turnRight())
	assert(turtle.back())
	while turtle.detectDown() do
		assert(turtle.back())
		assert(turtle.back())
	end
	assert(turtle.forward())
	assert(turtle.turnLeft())
	assert(turtle.back())
	assert(turtle.back())
	assert(turtle.turnRight())
	assert(turtle.forward())
	assert(turtle.turnLeft())
	print('Returned to home.')
end

local forwardDirection = 0

function doIter()
	local forwarding = true
	local lastMarkFacing
	while true do
		doAStep()
		local facing = getMarkFacing()
		if not facing then
			local turnOp = forwarding and turtle.turnRight or turtle.turnLeft
			local turnOp2 = forwarding and turtle.turnLeft or turtle.turnRight
			assert(turnOp())
			assert(turtle.forward())
			assert(turnOp())
			assert(turtle.forward())
			while true do
				local sideFacing = getMarkFacing()
				if not sideFacing then
					if forwarding then
						assert(turtle.turnLeft())
						assert(turtle.turnLeft())
					end
					returnToHome()
					return
				end
				if forward and sideFacing ~= (forwardDirection + 1) % 4 then
					forwardDirection = (forwardDirection + 2) % 4
					assert(turtle.back())
					assert(turtle.turnRight())
					assert(turtle.forward())
					assert(turtle.forward())
					assert(turtle.turnLeft())
					assert(turtle.forward())
				else
					assert(turtle.back())
					assert(turnOp2())
					assert(turtle.forward())
					assert(turnOp())
					break
				end
			end
			forwarding = not forwarding
		end
		lastMarkFacing = facing
	end
end

function main()
	local maxIdel = 60 * 10
	while true do
		local count = 0
		repeat
			sleep(1)
			count = count + 1
		until checkIsLog() == 'log' or redstone.getInput('back') or count > maxIdel
		fillSupplies()
		doIter()
	end
end

main()
