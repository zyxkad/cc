-- Clock work Drone controller
-- by zyxkad@gmail.com

local crx = require('coroutinex')
local co_main = crx.main
local await = crx.await

local ship = peripheral.find('ship_reader')

-- constants
local startRPM = 20

local motorNames = {
	frontLeft = 'electric_motor_8',
	frontRight = 'electric_motor_9',
	backRight = 'electric_motor_10',
	backLeft = 'electric_motor_11',
}

local motors = {}
local rates = {}
local targetRPMs = {}

local function wrapScrollBehaviourEntity(e)
	assert(e.setTargetSpeed)
	local p = {}
	p.setSpeed = function(rpm)
		return e.setTargetSpeed(rpm)
	end
	p.getSpeed = function(rpm)
		return e.getTargetSpeed(rpm)
	end
	return p
end

for id, name in pairs(motorNames) do
	local m = assert(peripheral.wrap(name), string.format('[%s] motor name %s was not found', id, name))
	if not m.setSpeed then
		m = wrapScrollBehaviourEntity(m)
	end
	motors[id] = m
	rates[id] = 1
	targetRPMs[id] = 0
end

local function getRotation()
	local r = ship.getRotation()
	return {
		roll = math.deg(r.roll),
		pitch = math.deg(r.pitch),
		yaw = math.deg(r.yaw),
	}
end

-- status
local terminated = false

local shipID = ship.getShipID()
local mass = ship.getMass()
local velocity = ship.getVelocity()
local acceleration = { x=0, y=0, z=0 }
local netForce = { x=0, y=0, z=0 }
local rotation = getRotation()
local rotSpeed = { roll=0, pitch=0, yaw=0 }
local rotAccel = { roll=0, pitch=0, yaw=0 }
local postition = ship.getWorldspacePosition()

local targetRPM = 0
local status = 'Idle'
local action = ''
local forcing = false
local pressedKey = {}

-- begin utils

local function round(num)
	return math.floor(0.5 + num)
end

local function waitTimer(id)
	local _, p1
	repeat
		_, p1 = os.pullEvent('timer')
	until p1 == id
end

-- end utils

local function setSpeed(motor, speed)
	targetRPMs[motor] = speed
end

local function setFrontSpeed(speed)
	setSpeed('frontLeft', speed)
	setSpeed('frontRight', speed)
end

local function setBackSpeed(speed)
	setSpeed('backLeft', speed)
	setSpeed('backRight', speed)
end

local function setLeftSpeed(speed)
	setSpeed('frontLeft', speed)
	setSpeed('backLeft', speed)
end

local function setRightSpeed(speed)
	setSpeed('frontRight', speed)
	setSpeed('backRight', speed)
end

local function setAllSpeed(speed)
	for id, _ in pairs(targetRPMs) do
		targetRPMs[id] = speed
	end
end

local function addSpeed(motor, speed)
	targetRPMs[motor] = targetRPMs[motor] + speed
end

local function addFrontSpeed(speed)
	addSpeed('frontLeft', speed)
	addSpeed('frontRight', speed)
end

local function addBackSpeed(speed)
	addSpeed('backLeft', speed)
	addSpeed('backRight', speed)
end

local function addLeftSpeed(speed)
	addSpeed('frontLeft', speed)
	addSpeed('backLeft', speed)
end

local function addRightSpeed(speed)
	addSpeed('frontRight', speed)
	addSpeed('backRight', speed)
end

local function mulSpeed(motor, ratio)
	targetRPMs[motor] = targetRPMs[motor] * ratio
end

local function mulFrontSpeed(ratio)
	mulSpeed('frontLeft', ratio)
	mulSpeed('frontRight', ratio)
end

local function mulBackSpeed(ratio)
	mulSpeed('backLeft', ratio)
	mulSpeed('backRight', ratio)
end

local function mulLeftSpeed(ratio)
	mulSpeed('frontLeft', ratio)
	mulSpeed('backLeft', ratio)
end

local function mulRightSpeed(ratio)
	mulSpeed('frontRight', ratio)
	mulSpeed('backRight', ratio)
end

local function listenKey()
	while true do
		local event, key, held = os.pullEvent()
		if event == 'key' then
			if not held then
				if key == keys.f then
					forcing = true
				else
					pressedKey[key] = true
				end
			end
		elseif event == 'key_up' then
			if key == keys.f then
				forcing = false
			else
				pressedKey[key] = false
			end
		end
	end
end

local function update()
	local dt = 0.05
	while true do
		local timerId = os.startTimer(dt)

		local v2 = ship.getVelocity()
		local r2 = getRotation()
		mass = ship.getMass()
		acceleration = {
			x = (v2.x - velocity.x) / dt,
			y = (v2.y - velocity.y) / dt,
			z = (v2.z - velocity.z) / dt,
		}
		netForce = {
			x = acceleration.x * mass,
			y = acceleration.y * mass,
			z = acceleration.z * mass,
		}
		velocity = v2
		local rs2 = {
			roll = (r2.roll - rotation.roll) / dt,
			pitch = (r2.pitch - rotation.pitch) / dt,
			yaw = (r2.yaw - rotation.yaw) / dt,
		}
		rotation = r2
		rotAccel = {
			roll = (rs2.roll - rotSpeed.roll) / dt,
			pitch = (rs2.pitch - rotSpeed.pitch) / dt,
			yaw = (rs2.yaw - rotSpeed.yaw) / dt,
		}
		rotSpeed = rs2
		postition = ship.getWorldspacePosition()
		waitTimer(timerId)
	end
end

local function controlTakeOff()
	targetRPM = startRPM
	local startY = round(postition.y)
	local balancedRPM = 0
	while not terminated do
		targetRPM = targetRPM + 1
		if postition.y >= startY + 10 and balancedRPM ~= 0 then
			targetRPM = balancedRPM
			setAllSpeed(targetRPM)
			break
		end
		if postition.y >= startY + 5 then
			if velocity.y > 0.5 then
				targetRPM = targetRPM - 1
			end
			if acceleration.y > 0.3 then
				targetRPM = targetRPM - 1
			elseif acceleration.y > 0 then
				balancedRPM = targetRPM
			end
		end
		setAllSpeed(targetRPM)
		if acceleration.y <= 0.1 then
			sleep(1)
		else
			sleep(5)
		end
	end
	while not terminated do
		if postition.y >= startY + 10 then
			targetRPM = balancedRPM
			setAllSpeed(targetRPM)
			break
		end
		sleep(0)
	end
	return balancedRPM
end

local function controlMove(balancedRPM)
	while true do
		sleep(0.2)
		if pressedKey[keys.space] then
			targetRPM = targetRPM + 10
		end
		if pressedKey[keys.leftShift] then
			targetRPM = targetRPM - 10
			if targetRPM < startRPM then
				return balancedRPM
			end
		end
		if pressedKey[keys.a] then
			action = 'turn left'
			setSpeed('frontLeft', targetRPM - 5)
			sleep(0.2)
			setSpeed('frontLeft', targetRPM)
			setSpeed('backLeft', targetRPM - 5)
			sleep(0.2)
			setSpeed('backLeft', targetRPM)
			setSpeed('backRight', targetRPM - 5)
			sleep(0.2)
			setSpeed('backRight', targetRPM)
			setSpeed('frontRight', targetRPM - 5)
			sleep(0.2)
			setSpeed('frontRight', targetRPM)
			sleep(0.2)
		end
		if pressedKey[keys.d] then
			action = 'turn right'
			setSpeed('frontRight', targetRPM - 5)
			sleep(0.2)
			setSpeed('frontRight', targetRPM)
			setSpeed('backRight', targetRPM - 5)
			sleep(0.2)
			setSpeed('backRight', targetRPM)
			setSpeed('backLeft', targetRPM - 5)
			sleep(0.2)
			setSpeed('backLeft', targetRPM)
			setSpeed('frontLeft', targetRPM - 5)
			sleep(0.2)
			setSpeed('frontLeft', targetRPM)
			sleep(0.2)
		end
		if pressedKey[keys.w] then
			action = 'forward'
			setBackSpeed(targetRPM + 5)
			sleep(0.2)
			setBackSpeed(targetRPM)
			sleep(0.4)
			setFrontSpeed(targetRPM + 5)
			sleep(0.2)
			setFrontSpeed(targetRPM)
			sleep(0.2)
		end
		if pressedKey[keys.s] then
			action = 'backward'
			setFrontSpeed(targetRPM + 5)
			sleep(0.2)
			setFrontSpeed(targetRPM)
			sleep(0.4)
			setBackSpeed(targetRPM + 5)
			sleep(0.2)
			setBackSpeed(targetRPM)
			sleep(0.2)
		end
		action = ''
		setAllSpeed(targetRPM)
	end
	return balancedRPM
end

local function controlLand(balancedRPM)
	targetRPM = balancedRPM
	repeat
		targetRPM = math.max(0, targetRPM - 1)
		setAllSpeed(targetRPM)
		sleep(0.4)
		if targetRPM <= 0 then
			return
		end
		if acceleration.y <= 0 and acceleration.y > -0.1 then
			balancedRPM = targetRPM
		end
	until acceleration.y <= -0.1 and velocity.y < 0
	targetRPM = balancedRPM
	setAllSpeed(targetRPM)
	repeat sleep(0) until velocity.y >= 0
	targetRPM = 0
	setAllSpeed(0)
end

local function control()
	while not terminated do
		status = 'Idle'
		action = ''
		if pressedKey[keys.space] then
			status = 'Taking Off'
			local balancedRPM = controlTakeOff()
			if terminated then return end
			status = 'Controlling'
			balancedRPM = controlMove(balancedRPM)
			if terminated then return end
			status = 'Landing'
			controlLand(balancedRPM)
			if terminated then return end
		end
		sleep(1)
	end
end

local function updateMotor()
	while true do
		local threads = {}
		for id, m in pairs(motors) do
			local r = targetRPMs[id]
			local t = math.min(256, round(r * rates[id]))
			if r == 0 then
				t = 0
			end
			threads[#threads + 1] = function()
				if t ~= m.getSpeed() then
					pcall(m.setSpeed, t)
				end
			end
		end
		await(table.unpack(threads))
		sleep(0)
	end
end

local function render()
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.clear()
	while true do
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.black)

		term.setCursorPos(1, 2)
		term.clearLine()
		term.write('Status: ')
		term.write(status)
		if action ~= '' then
			term.write(' ('..action..')')
		end

		term.setCursorPos(1, 3)
		term.clearLine()
		term.write('RPM: ')
		term.write(targetRPM)

		term.setCursorPos(1, 4)
		term.clearLine()
		term.write('Mass: ')
		term.write(mass)

		term.setCursorPos(1, 5)
		term.clearLine()
		term.setTextColor(colors.white)
		term.write('Speed:')
		term.setTextColor(colors.white)
		term.write(' X: ')
		term.setTextColor(colors.red)
		term.write(string.format('%.2f', velocity.x))
		term.setTextColor(colors.white)
		term.write(' Y: ')
		term.setTextColor(colors.green)
		term.write(string.format('%.2f', velocity.y))
		term.setTextColor(colors.white)
		term.write(' Z: ')
		term.setTextColor(colors.blue)
		term.write(string.format('%.2f', velocity.z))

		term.setCursorPos(1, 6)
		term.clearLine()
		term.setTextColor(colors.white)
		term.write('Rotate:')
		term.setTextColor(colors.white)
		term.write(' R: ')
		term.setTextColor(colors.red)
		term.write(string.format('%.1f (%+.1f)', rotation.roll, rotSpeed.roll))
		term.setTextColor(colors.white)
		term.write(' P: ')
		term.setTextColor(colors.green)
		term.write(string.format('%.1f (%+.1f)', rotation.pitch, rotSpeed.pitch))
		term.setTextColor(colors.white)
		term.write(' Y: ')
		term.setTextColor(colors.blue)
		term.write(string.format('%.1f (%+.1f)', rotation.yaw, rotSpeed.yaw))

		term.setCursorPos(1, 7)
		term.clearLine()
		term.setTextColor(colors.white)
		term.write('Acc:')
		term.setTextColor(colors.white)
		term.write(' X: ')
		term.setTextColor(colors.red)
		term.write(string.format('%+.2f', acceleration.x))
		term.setTextColor(colors.white)
		term.write(' Y: ')
		term.setTextColor(colors.green)
		term.write(string.format('%+.2f', acceleration.y))
		term.setTextColor(colors.white)
		term.write(' Z: ')
		term.setTextColor(colors.blue)
		term.write(string.format('%+.2f', acceleration.z))

		term.setCursorPos(1, 8)
		term.clearLine()
		term.setTextColor(colors.white)
		term.write('Force:')
		term.setTextColor(colors.white)
		term.write(' X: ')
		term.setTextColor(colors.red)
		term.write(string.format('%+06d', netForce.x))
		term.setTextColor(colors.white)
		term.write(' Y: ')
		term.setTextColor(colors.green)
		term.write(string.format('%+06d', netForce.y))
		term.setTextColor(colors.white)
		term.write(' Z: ')
		term.setTextColor(colors.blue)
		term.write(string.format('%+06d', netForce.z))

		term.setTextColor(colors.yellow)
		term.setCursorPos(1, 14)
		term.clearLine()
		term.write(string.format('%.1f', targetRPMs['frontLeft'] * rates['frontLeft']))
		term.setCursorPos(7, 14)
		term.write(string.format('%.1f', targetRPMs['frontRight'] * rates['frontRight']))
		term.setCursorPos(14, 14)
		term.write(string.format('%.1f', rates['frontLeft']))
		term.setCursorPos(20, 14)
		term.write(string.format('%.1f', rates['frontRight']))
		term.setCursorPos(1, 15)
		term.clearLine()
		term.write(string.format('%.1f', targetRPMs['backLeft'] * rates['backLeft']))
		term.setCursorPos(7, 15)
		term.write(string.format('%.1f', targetRPMs['backRight'] * rates['backRight']))
		term.setCursorPos(14, 15)
		term.write(string.format('%.1f', rates['backLeft']))
		term.setCursorPos(20, 15)
		term.write(string.format('%.1f', rates['backRight']))
		sleep(0)
	end
end

function main()
	co_main(
		listenKey,
		update,
		control,
		updateMotor,
		render,
		{
			event = 'terminate',
			callback = function()
				terminated = true
				status = 'Terminated'
				targetRPM = 0
				setAllSpeed(0)
				sleep(0.4)
				local threads = {}
				for id, m in pairs(motors) do
					threads[#threads + 1] = function()
						m.setSpeed(0)
					end
				end
				co_main(table.unpack(threads))
				return true
			end
		}
	)
end

main()
