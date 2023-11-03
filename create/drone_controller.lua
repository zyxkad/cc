-- Clock work Drone controller
-- by zyxkad@gmail.com

local ship = peripheral.find('ship_reader')

-- constants
local minRPM = 8

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
local velocity = ship.getVelocity()
local acceleration = { x=0, y=0, z=0 }
local rotation = getRotation()
local rotSpeed = { roll=0, pitch=0, yaw=0 }
local rotAccel = { roll=0, pitch=0, yaw=0 }
local postition = ship.getWorldspacePosition()

local maxRPM = 0
local status = 'Idle'
local action = ''
local forcing = false
local pressedKey = {}

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

local function standBy()
	setAllSpeed(0)
end

-- begin utils

local function waitTimer(id)
	local _, p1
	repeat
		_, p1 = os.pullEvent('timer')
	until p1 == id
end

-- end utils

local function listenKey()
	while true do
		local event, key, held = os.pullEventRaw()
		if event == 'terminate' then
			terminated = true
			status = 'Landing [Terminated]'
			maxRPM = 0
			for id, m in pairs(motors) do
				targetRPMs[id] = 0
			end
			sleep(0.5)
			for id, m in pairs(motors) do
				m.setSpeed(0)
			end
			error('Terminated', 0)
			return
		end
		if event == 'key' then
			if key == keys.space then
				if maxRPM < minRPM then
					maxRPM = minRPM
				else
					maxRPM = math.min(240, maxRPM + 1)
				end
			elseif key == keys.leftShift then
				maxRPM = math.max(0, maxRPM - 5)
				if maxRPM < minRPM then
					maxRPM = 0
				end
			end
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
		acceleration = {
			x = (v2.x - velocity.x) / dt,
			y = (v2.y - velocity.y) / dt,
			z = (v2.z - velocity.z) / dt,
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

local function control()
	local lastPitch = 0
	local lastYaw = 0
	local lastPitchInc = 0
	local lastYawInc = 0
	local lastPitchAcc = 0
	local lastYawAcc = 0
	local pitchRate = 0
	local yawRate = 0
	local balancedPitchRate = 0
	local balancedYawRate = 0
	local fixPitch = 0
	local lastFlipped = false
	while not terminated do
		status = 'Idle'
		action = ''
		setAllSpeed(maxRPM)
		if maxRPM > 0 then
			status = 'Flying'
			if pressedKey[keys.w] then
				if forcing then
					action = 'Forward roll'
					setFrontSpeed(-maxRPM)
				else
					action = 'Forward'
					mulFrontSpeed(0.9)
				end
			end
			if pressedKey[keys.s] then
				if forcing then
					action = 'Backward roll'
					setBackSpeed(-maxRPM)
				else
					action = 'Backward'
					mulBackSpeed(0.9)
				end
			end
			if pressedKey[keys.a] then
				if forcing then
					action = 'Left roll'
					setLeftSpeed(-maxRPM)
				else
					action = 'Left'
					mulLeftSpeed(0.9)
				end
			end
			if pressedKey[keys.d] then
				if forcing then
					action = 'Right roll'
					setRightSpeed(-maxRPM)
				else
					action = 'Right'
					mulRightSpeed(0.9)
				end
			end
			local pitch = rotation.pitch
			local yaw = rotation.yaw
			local pitchInc = pitch - lastPitch
			local yawInc = yaw - lastYaw
			local pitchAcc = pitchInc - lastPitchInc
			local yawAcc = yawInc - lastYawInc
			local flipped = false
			if action == '' then
				local nextPitch = pitch + pitchInc + pitchAcc
				local nextYaw = yaw + yawInc + yawAcc
				if pitch >= 90 and nextPitch >= 90 then
					flipped = true
					setFrontSpeed(-maxRPM)
					setBackSpeed(-maxRPM * 2 / 3)
				elseif pitch <= -90 and nextPitch <= -90 then
					flipped = true
					setBackSpeed(-maxRPM)
					setFrontSpeed(-maxRPM * 2 / 3)
				else
					if pitchRate * pitchAcc < 0 then -- not same direction
						if pitchAcc > 1 then
							pitchRate = pitchRate * 2 / 3
						elseif pitchAcc < -1 then
							pitchRate = pitchRate * 2 / 3
						else
							balancedPitchRate = pitchRate
						end
					end
					if pitch > 5 then
						if pitchRate > 0 then
							if pitchAcc > 0 then
								pitchRate = pitchRate + 0.05
							end
						else
							pitchRate = 0
						end
						pitchRate = pitchRate + 0.05
						if pitch > 50 then
							setFrontSpeed(-maxRPM / 3)
						end
					elseif pitch < -5 then
						if pitchRate < 0 then
							if pitchAcc < 0 then
								pitchRate = pitchRate - 0.05
							end
						else
							pitchRate = 0
						end
						pitchRate = pitchRate - 0.05
						if pitch < -50 then
							setBackSpeed(-maxRPM / 3)
						end
					else
						pitchRate = balancedPitchRate
					end

					if yawRate * yawAcc < 0 then
						if yawAcc > 1 then
							yawRate = yawRate * 2 / 3
						elseif yawAcc < -1 then
							yawRate = yawRate * 2 / 3
						else
							balancedYawRate = yawRate
						end
					end
					if yaw > 5 then
						if yawRate > 0 then
							if yawAcc > 0 then
								yawRate = yawRate + 0.05
							end
						else
							yawRate = 0
						end
						yawRate = yawRate + 0.05
						if yaw > 50 then
							setRightSpeed(-maxRPM / 3)
						end
					elseif yaw < -5 then
						if yawRate < 0 then
							if yawAcc < 0 then
								yawRate = yawRate - 0.05
							end
						else
							yawRate = 0
						end
						yawRate = yawRate - 0.05
						if yaw < -50 then
							setLeftSpeed(-maxRPM / 3)
						end
					else
						yawRate = balancedYawRate
					end
				end
			end
			if lastFlipped and not flipped then
				setAllSpeed(maxRPM * 3 / 2)
			end
			lastFlipped = flipped
			lastPitch = pitch
			lastYaw = yaw
			lastPitchInc = pitchInc
			lastYawInc = yawInc
			lastPitchAcc = pitchAcc
			lastYawAcc = yawAcc

			rates['frontLeft'] = 1
			rates['frontRight'] = 1
			rates['backLeft'] = 1
			rates['backRight'] = 1
			if not flipped then
				if pitchRate < 0 then
					rates['frontLeft'] = 1 - pitchRate
					rates['frontRight'] = 1 - pitchRate
				else
					rates['backLeft'] = 1 + pitchRate
					rates['backRight'] = 1 + pitchRate
				end
				if yawRate < 0 then
					rates['backRight'] = 1 - yawRate
					rates['frontRight'] = 1 - yawRate
				else
					rates['backLeft'] = 1 + yawRate
					rates['frontLeft'] = 1 + yawRate
				end
			end
		end
		for id, m in pairs(motors) do
			local r = targetRPMs[id]
			if r == 0 then
				pcall(m.setSpeed, 0)
			else
				pcall(m.setSpeed, math.min(256, math.floor(0.5 + r * rates[id])))
			end
		end
		sleep(0.35)
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

		term.setCursorPos(1, 3)
		term.clearLine()
		term.write('Action: ')
		term.write(action)

		term.setCursorPos(1, 4)
		term.clearLine()
		term.write('Max RPM: ')
		term.write(maxRPM)

		term.setCursorPos(1, 5)
		term.clearLine()
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
		term.write(string.format('%.2f', rotation.roll))
		term.setTextColor(colors.white)
		term.write(' P: ')
		term.setTextColor(colors.green)
		term.write(string.format('%.2f', rotation.pitch))
		term.setTextColor(colors.white)
		term.write(' Y: ')
		term.setTextColor(colors.blue)
		term.write(string.format('%.2f', rotation.yaw))

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
		sleep(0.1)
	end
end

function main()
	os.pullEvent = os.pullEventRaw
	parallel.waitForAll(
		listenKey,
		update,
		control,
		render
	)
end

main()
