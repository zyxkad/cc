-- Starlance ship controller
-- by zyxkad@gmail.com

local THRUSTER_TYPE = 'starlance_thruster'

local shipName = ''
local subThrusterProtocol = ''
local thrusters = {}
local pressedKey = {}

local function newPID(kP, kI, kD, bias)
	bias = bias or 0
	local errorPrior = 0
	local integralPrior = 0

	local pid = {}

	pid.calc = function(target, actual)
		target = target or 0
		local err = target - actual
		local integral = integralPrior + err
		local derivative = err - errorPrior
		local out = kP * err + kI * integral + kD * derivative + bias
		errorPrior, integralPrior = err, integral
		return out
	end

	pid.reset = function()
		errorPrior = 0
		integralPrior = 0
	end

	return pid
end

local function setThrusterPower(axis, power)
	power = math.max(power, 0)
	local list = thrusters[axis]
	if list then
		for _, t in ipairs(list) do
			t.setPower(power)
		end
	end
	rednet.broadcast({'power', axis, power}, subThrusterProtocol)
end

local function pollEvents()
	local event, p1, p2 = os.pullEvent()
	if event == 'key' then
		pressedKey[p1] = true
	elseif event == 'key_up' then
		pressedKey[p1] = false
	end
end

local function getTargetPower()
	local power = vector.new(0, 0, 0)
	if pressedKey[keys.w] then
		power.z = power.z - 1
	end
	if pressedKey[keys.s] then
		power.z = power.z + 1
	end
	if pressedKey[keys.a] then
		power.x = power.x - 1
	end
	if pressedKey[keys.d] then
		power.x = power.x + 1
	end
	if pressedKey[keys.leftShift] then
		power.y = power.y - 1
	end
	if pressedKey[keys.space] then
		power.y = power.y + 1
	end
	return power
end

local velocityPidX = newPID(0.25, 0.001, 0.08)
local velocityPidY = newPID(0.1, 0.001, 0.08)
local velocityPidZ = newPID(0.25, 0.001, 0.08)
local power = vector.new(0, 0, 0)
local target = vector.new(0, 0, 0)
local velocity = vector.new(0, 0, 0)

local function getCurrentVelocity()
	local vel = ship.getVelocity()
	local quat = ship.getQuaternion()

	local qx, qy, qz, qw = quat.x, quat.y, quat.z, quat.w
	local qx2, qy2, qz2, qw2 = qx * qx, qy * qy, qz * qz, qw * qw
	local n = 1 / (qx2 + qy2 + qz2 + qw2)
	local nn = n * n
	local xx, yy, zz, ww = qx2 * nn, qy2 * nn, qz2 * nn, qw2 * nn
	local xy, xz, yz = qx * qy * nn, qx * qz * nn, qy * qz * nn
	local xw, zw, yw = qx * qw * nn, qz * qw * nn, qy * qw * nn
	local k = 1 / (xx + yy + zz + ww)
	return vector.new(
		(xx - yy - zz + ww) * k * vel.x + (2 * (xy + zw) * k * vel.y + (2 * (xz - yw) * k) * vel.z),
		2 * (xy - zw) * k * vel.x + ((yy - xx - zz + ww) * k * vel.y + (2 * (yz + xw) * k) * vel.z),
		2 * (xz + yw) * k * vel.x + (2 * (yz - xw) * k * vel.y + ((zz - xx - yy + ww) * k) * vel.z))
end

local function update()
	power = getTargetPower()
	velocity = getCurrentVelocity()
	target = vector.new(power.x * 10, power.y * 2, power.z * 10)
	power.x = velocityPidX.calc(target.x, velocity.x)
	power.y = velocityPidY.calc(target.y, velocity.y)
	power.z = velocityPidZ.calc(target.z, velocity.z)
	setThrusterPower('x+', power.x)
	setThrusterPower('x-', -power.x)
	setThrusterPower('y+', power.y)
	setThrusterPower('y-', -power.y)
	setThrusterPower('z+', power.z)
	setThrusterPower('z-', -power.z)
end

local function render(monitor)
	monitor.setCursorPos(1, 2)
	monitor.clearLine()
	monitor.write(string.format('veloc : %+.5f, %+.5f, %+.5f', velocity.x, velocity.y, velocity.z))
	monitor.setCursorPos(1, 3)
	monitor.clearLine()
	monitor.write(string.format('target: %+.5f, %+.5f, %+.5f', target.x, target.y, target.z))
	monitor.setCursorPos(1, 4)
	monitor.clearLine()
	monitor.write(string.format('power : %+.5f, %+.5f, %+.5f', power.x, power.y, power.z))
end

function main(shipName0)
	assert(type(shipName0) == 'string', 'need provide a ship name')
	shipName = shipName0
	subThrusterProtocol = 'spaceship-sub_thruster-' .. shipName

	if fs.exists('thrusters.dat') then
		local fd = assert(fs.open('thrusters.dat', 'r'))
		local thrusterNames = textutils.unserialize(fd.readAll())
		fd.close()
		for axis, names in pairs(thrusterNames) do
			local list = {}
			for i, n in ipairs(names) do
				local t = peripheral.wrap(n)
				assert(peripheral.hasType(t, THRUSTER_TYPE), n .. ' is not a thruster')
				t.setPeripheralMode(true)
				-- t.setMode('global')
				t.setPower(0)
				list[i] = t
			end
			thrusters[axis] = list
		end
	end

	local ok, err = pcall(function()
		parallel.waitForAny(function()
			while true do
				pollEvents()
			end
		end, function()
			while true do
				update()
				sleep(0.1)
			end
		end, function()
			local monitor = peripheral.find('monitor') or term
			if monitor.setTextScale then
				monitor.setTextScale(0.5)
			end
			monitor.clear()
			while true do
				render(monitor)
				sleep(0.2)
			end
		end)
		rednet.broadcast({'off'}, subThrusterProtocol)
		assert(ok, err)
	end)
end

main(...)
