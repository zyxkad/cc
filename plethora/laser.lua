-- Laser cleaner
-- by zyxkad@gmail.com

local laser = peripheral.find('plethora:laser')

local function fireBlock(x, y, z)
	local yaw = math.deg(math.atan2(-z, x))
	local pitch = math.deg(math.atan2(-y, math.sqrt(x * x + z * z)))
	return laser.fire(yaw, pitch, 5)
end

function main(x, y, z)
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z)

	for x1 = 1, x do
		for z1 = 1, z do
			for y1 = 1, y do
				fireBlock(x1 - 1, y1, z1 - 1)
			end
		end
	end
end

main(...)
