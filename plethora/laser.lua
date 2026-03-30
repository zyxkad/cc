-- Laser cleaner
-- by zyxkad@gmail.com

local laser = peripheral.find('plethora:laser')

local function fireBlock(x, y, z)
	local yaw = math.deg(math.atan2(-z, x))
	local pitch = math.deg(math.atan2(y, math.sqrt(x * x + z * z)))
	return laser.fire(yaw, pitch, 5)
end

function main(x, y, z, startY)
	x = tonumber(x)
	y = tonumber(y)
	z = tonumber(z)
	startY = tonumber(startY) or 0

	for y1 = startY, y do
		print('y:', y1)
		for x1 = -x, x do
			for z1 = -z, z do
				fireBlock(x1, y1, z1)
			end
		end
	end
end

main(...)
