-- Digger
-- by zyxkad@gmail.com

local function digAndForward()
	while not turtle.forward() do
		if not turtle.detect() then
			assert(turtle.forward())
		end
		turtle.dig()
	end
end

function main(x, z, drop)
	x = x and tonumber(x)
	z = z and tonumber(z) or 1
	drop = drop == 'true'

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
