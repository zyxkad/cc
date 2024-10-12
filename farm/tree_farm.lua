-- Tree Farmer
-- by zyxkad@gmail.com

local connectMark = 'minecraft:wall_torch'
local turnRightMark = 'minecraft:soul_wall_torch'
local turnLeftMark = 'minecraft:redstone_wall_torch'

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

local function getMark()
	local ok, block = turtle.inspectDown()
	return ok and block.name
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

local function plantSaplingAndForward()
	if not turtle.detectDown() and turtle.getItemCount(1) > 1 then
		turtle.select(1)
		turtle.placeDown()
	end
	assert(turtle.forward())
	assert(turtle.down())
	turtle.select(2)
	turtle.dropDown(turtle.getItemCount() - 1)
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
	plantSaplingAndForward()
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

function doIter()
	while true do
		doAStep()
		local mark = getMark()
		if mark ~= connectMark then
			local turnOp = mark == turnRightMark and turtle.turnRight or turtle.turnLeft
			local turnOp2 = mark == turnRightMark and turtle.turnLeft or turtle.turnRight
			assert(turnOp())
			assert(turtle.forward())
			assert(turnOp())
			assert(turtle.forward())
			if not getMark() then
				if mark == turnRightMark then
					assert(turtle.turnLeft())
					assert(turtle.turnLeft())
				end
				returnToHome()
				return
			end
			assert(turtle.back())
			assert(turnOp2())
			assert(turtle.forward())
			assert(turnOp())
		end
	end
end

local function recoverProg()
	local ok, block = turtle.inspectDown()
	if ok then
		if block.name == 'minecraft:barrel' then
			return
		elseif block.name == connectMark then
			doIter()
			return
		end
	end
	ok, block = turtle.inspectUp() 
	if ok then
		if block.tags['minecraft:logs'] then
			digTree()
		end
	else
		assert(turtle.up())
		ok, block = turtle.inspectUp() 
		if ok and block.tags['minecraft:logs'] then
			digTree()
		else
			assert(turtle.down())
		end
	end
	ok, block = turtle.inspectDown()
	if ok and block.name == 'minecraft:dirt' then
		assert(turtle.up())
		plantSaplingAndForward()
		doIter()
		return
	end
end

local function countDown(seconds, hint, condition)
	hint = hint or 'waiting'
	local _, y = term.getCursorPos()
	for i = seconds, 1, -1 do
		local before = os.clock()
		if condition() then
			print()
			return true
		end
		sleep(1 - os.clock() + before)
		term.setCursorPos(1, y)
		term.clearLine()
		term.write(hint .. ' ' .. i)
	end
	print()
	if condition() then
		return true
	end
	return false
end

function main()
	recoverProg()
	local maxIdel = 60 * 4
	while true do
		countDown(maxIdel, 'Waiting tree grow up', function() return checkIsLog() == 'log' or redstone.getInput('back') end)
		fillSupplies()
		doIter()
	end
end

main()
