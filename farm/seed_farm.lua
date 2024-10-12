-- Seed Farmer
-- by zyxkad@gmail.com

local frontMark = 'minecraft:nether_bricks'
local topMark = 'minecraft:polished_andesite'
local sideMark1 = 'minecraft:torch'
local sideMark2 = 'minecraft:polished_diorite'
local homeMark = 'minecraft:barrel'

local function checkEnoughFuel()
	local level = turtle.getFuelLevel()
	return level == 'unlimited' or level >= 1000
end

local function fillSupplies()
	print('Filling supplies ...')
	repeat until not turtle.suck()
	print('Refueling (' .. turtle.getFuelLevel() .. ') ...')
	turtle.select(9)
	while not checkEnoughFuel() do
		turtle.refuel(turtle.getItemCount() - 1)
		turtle.suck()
	end
	print('Turtle prepared')
end

local function triggerWater()
	print('Watering farmland ...')
	redstone.setOutput('right', true)
	sleep(3)
	redstone.setOutput('right', false)
end

local function moveAndAssert(move)
	local ok, err = move()
	if not ok then
		if err ~= 'Movement obstructed' then
			error(err, 1)
		end
		return false
	end
	return true
end

local function moveUpLevel()
	while true do
		local ok, block = turtle.inspectDown()
		if ok then
			if block.name == 'minecraft:dirt' then
				turtle.up()
				turtle.digDown()
				return
			end
			if not block.tags['minecraft:crops'] then
				break
			end
		end
		if not moveAndAssert(turtle.forward) then
			break
		end
	end
	local ok, block = turtle.inspect()
	if ok and block.tags['minecraft:crops'] then
		turtle.up()
		turtle.forward()
	end
end

local function plantSeed(plantingSeed)
	local slot = plantingSeed * 2 - 1
	turtle.select(slot)
	local planting = turtle.getItemDetail().name
	if turtle.getItemCount() <= 1 then
		if turtle.getItemDetail(slot + 1).name == planting then
			turtle.select(slot + 1)
		end
		if turtle.getItemCount() <= 1 then
			return
		end
	end
	if not turtle.detectDown() and not turtle.placeDown() then
		turtle.digDown()
		turtle.placeDown()
	end
end

local function plantALevel(plantingSeed, totalSeeds)
	assert(turtle.turnRight())
	while true do
		repeat
			plantSeed(plantingSeed)
		until not turtle.back()
		plantingSeed = plantingSeed % totalSeeds + 1
		assert(turtle.turnLeft())
		if not turtle.forward() then
			return plantingSeed
		end
		local ok, block = turtle.inspectDown()
		if ok and block.name == 'minecraft:dirt' then
			assert(turtle.back())
		end
		assert(turtle.turnRight())
		repeat
			plantSeed(plantingSeed)
		until not turtle.forward()
		plantingSeed = plantingSeed % totalSeeds + 1
		local ok, block = turtle.inspect()
		if ok and block.name == sideMark2 then
			assert(turtle.up())
			assert(turtle.turnLeft())
			assert(turtle.forward())
			return plantingSeed
		end
		assert(turtle.turnLeft())
		if not turtle.forward() then
			return plantingSeed
		end
		assert(turtle.turnRight())
	end
end

local function returnToHome()
	print('Returning to home ...')
	while true do
		local ok, block = turtle.inspect()
		if not ok or block.name ~= sideMark2 then
			while true do
				local ok, block = turtle.inspectUp()
				if ok and block.name == topMark then
					break
				end
				if not moveAndAssert(turtle.back) then
					assert(turtle.turnRight())
				end
			end
			local ok, block = turtle.inspect()
			if not ok then
				for _ = 1, 3 do
					assert(turtle.turnRight())
					ok, block = turtle.inspect()
					if ok then
						break
					end
				end
				if not ok then
					error('Turtle state is broken, expect a valid side mark, but found nothing')
				end
			end
			if block.name == sideMark1 then
				assert(turtle.down())
			elseif block.name == sideMark2 then
			elseif block.name == homeMark then
				return
			else
				error('Turtle state is broken, expect a valid side mark, but found ' .. block.name)
			end
		end
		assert(turtle.turnLeft())
		moveAndAssert(turtle.back)
	end
end

local function waitForCropGrowup()
	local ok, crop = turtle.inspectDown()
	if ok and crop.tags['minecraft:crops'] then
		write('Waiting crop to grow up ')
		local x, y = term.getCursorPos()
		while true do
			ok, crop = turtle.inspectDown()
			if not ok or not crop.tags['minecraft:crops'] then
				break
			end
			term.setCursorPos(x, y)
			term.write(crop.state.age)
			local maxAge = 4
			if crop.name == 'minecraft:beetroots' then
				maxAge = 3
			end
			if crop.state.age >= maxAge then
				break
			end
		end
		term.setCursorPos(1, y + 1)
	end
end

function main()
	local LEVEL_NUM = 4
	local totalSeeds = 4
	local plantingSeed = 1
	waitForCropGrowup()
	while true do
		returnToHome()
		waitForCropGrowup()
		fillSupplies()
		assert(turtle.turnLeft())
		for i = 1, LEVEL_NUM do
			moveUpLevel()
			waitForCropGrowup()
		end
		triggerWater()
		returnToHome()
		fillSupplies()
		assert(turtle.turnLeft())
		for i = 1, LEVEL_NUM do
			plantingSeed = plantALevel(plantingSeed, totalSeeds)
		end
	end
end

main()
