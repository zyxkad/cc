-- Thruster direction detector
-- by zyxkad@gmail.com

local THRUSTER_TYPE = 'starlance_thruster'

if not ship then
	error('Ship API required', 0)
end

local thrusters = {peripheral.find(THRUSTER_TYPE)}
print('Found', #thrusters, 'thrusters')

local vectorMetatable = getmetatable(vector.new())

local function getAxisVectors()
	local center = ship.getShipyardPosition()

	local world = setmetatable(ship.transformPositionToWorld(center.x, center.y, center.z), vectorMetatable)
	local world_x = setmetatable(ship.transformPositionToWorld(center.x + 1, center.y, center.z), vectorMetatable)
	local world_y = setmetatable(ship.transformPositionToWorld(center.x, center.y + 1, center.z), vectorMetatable)
	local world_z = setmetatable(ship.transformPositionToWorld(center.x, center.y, center.z + 1), vectorMetatable)

	return {
		x = world_x - world,
		y = world_y - world,
		z = world_z - world,
	}
end

local function getVectorAngle(a, b)
	return math.acos(a:dot(b) / (a:length() * b:length()))
end

local function testThruster(thruster, testPower)
	local axises = getAxisVectors()
	local vel1 = setmetatable(ship.getVelocity(), vectorMetatable)
	local omega1 = setmetatable(ship.getOmega(), vectorMetatable)
	thruster.setPeripheralMode(true)
	thruster.setPower(testPower)
	sleep(0.5)
	thruster.setPower(0)
	local vel2 = setmetatable(ship.getVelocity(), vectorMetatable)
	local omega2 = setmetatable(ship.getOmega(), vectorMetatable)
	local acc = vel2 - vel1
	local accOmega = omega2 - omega1
	local dir = acc:normalize()
	local dir_x1 = getVectorAngle(dir, axises.x)
	local dir_y1 = getVectorAngle(dir, axises.y)
	local dir_z1 = getVectorAngle(dir, axises.z)
	local dir_x2 = getVectorAngle(dir, -axises.x)
	local dir_y2 = getVectorAngle(dir, -axises.y)
	local dir_z2 = getVectorAngle(dir, -axises.z)
	local min_dir_angle, axis_str = dir_x1, 'x+'
	for str, angle in pairs({
		['y+'] = dir_y1,
		['z+'] = dir_z1,
		['x-'] = dir_x2,
		['y-'] = dir_y2,
		['z-'] = dir_z2,
	}) do
		if angle < min_dir_angle then
			min_dir_angle = angle
			axis_str = str
		end
	end
	-- TODO
	-- print('accOmega:', accOmega)
	return axis_str
end

local axis_map = {}
local duplicated = {}
local dupCount = 0

local testPower = 0.0001

for _, thruster in ipairs(thrusters) do
	thruster.setPeripheralMode(true)
	thruster.setPower(0)
end

for i, thruster in ipairs(thrusters) do
	local name = peripheral.getName(thruster)
	if not duplicated[name] then
		print('Testing', name)
		local axis = testThruster(thruster, testPower)
		print('Most close axis', axis)
		local list = axis_map[axis]
		if not list then
			list = {}
			axis_map[axis] = list
		end
		list[#list + 1] = name
		-- duplicate test
		thruster.setPower(1)
		for j = i + 1, #thrusters do
			local t2 = thrusters[j]
			if t2.getPower() ~= 0 then
				printError('Duplicated', peripheral.getName(t2))
				duplicated[peripheral.getName(t2)] = true
				dupCount = dupCount + 1
			end
		end
		thruster.setPower(0)
	end
end

for axis, list in pairs(axis_map) do
	table.sort(list, function(a, b)
		local aId = a:match('_(%d+)$')
		local bId = b:match('_(%d+)$')
		if aId and bId then
			return tonumber(aId) < tonumber(bId)
		end
		return a < b
	end)
	print(axis, '=', #list)
end
print('duplicated', '=', dupCount)

local fd = assert(fs.open('thrusters.dat', 'w'))
fd.write(textutils.serialize(axis_map))
fd.close()
