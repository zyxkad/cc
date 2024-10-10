-- Digger
-- by zyxkad@gmail.com

local function recoverProg(limit)
	local function digAndForward()
		while not turtle.forward() do
			if limit then
				local ok, block = turtle.inspect()
				if ok then
					if not block.name:match(limit) then
						return false
					end
				else
					assert(turtle.forward())
				end
			end
			turtle.dig()
		end
		return true
	end

	while true do
		if not digAndForward() then
			turtle.turnRight()
		elseif not turtle.detectDown() then
			turtle.turnRight()
			turtle.turnRight()
			digAndForward()
			return true
		end
	end
end

function main(x, z, drop, limit)
	x = x and tonumber(x)
	z = z and tonumber(z) or 1
	drop = drop == 'true'

	local function digAndForward()
		while not turtle.forward() do
			if not turtle.detect() then
				assert(turtle.forward())
			end
			if limit then
				local ok, block = turtle.inspect()
				if ok and not block.name:match(limit) then
					printError('Unexpected block', block.name)
					recoverProg(limit)
					error('Progress recovered', 0)
				end
			end
			turtle.dig()
		end
	end

	turtle.select(1)
	if not x then
		turtle.dig()
		return
	end
	for i = 1, z, 2 do
		if drop and turtle.getItemCount() > 0 then
			turtle.dropUp(turtle.getItemCount() - 1)
		end
		for _ = 2, x do
			digAndForward()
		end
		if i >= z then
			assert(turtle.turnLeft())
			assert(turtle.turnLeft())
			for _ = 2, x do
				digAndForward()
			end
			break
		end
		assert(turtle.turnLeft())
		digAndForward()
		assert(turtle.turnLeft())
		for _ = 2, x do
			digAndForward()
		end
		if i + 1 >= z then
			break
		end
		assert(turtle.turnRight())
		digAndForward()
		assert(turtle.turnRight())
	end
	assert(turtle.turnLeft())
	for _ = 2, z do
		digAndForward()
	end
	assert(turtle.turnLeft())
	if drop and turtle.getItemCount() > 0 then
		turtle.dropUp(turtle.getItemCount() - 1)
	end
end

main(...)
