-- Create Big Cannon Controller
-- by zyxkad@gmail.com

local RedstoneInterface = require('redstone_interface')

---- BEGIN configs ----
local assembleSide = '#0:back'
local reloadSide = '#3:back'
local reloadDoneSide = '#3:up'
local triggerSide = '#2:back'
local motorPitchName = 'electric_motor_0'
local motorYawName = 'electric_motor_1'
local pitchRotateRate = -8
local yawRotateRate = 8
local maxPitchUp = 45
local maxPitchDown = -45
local maxRPM = 3 * 16
local initSpeed = 10 -- m / s
local gravity = 9.81 -- m / s^2
local cannonPos = {
	x = 0,
	y = 0,
	z = 0
}
local cannonFacing = '+x' -- must be constant for now
---- ENG configs ----

local motorPitch = assert(peripheral.wrap(motorPitchName))
local motorYaw = assert(peripheral.wrap(motorYawName))
local assembleRI = RedstoneInterface:createFromStr(nil, assembleSide)
local reloadRI = RedstoneInterface:createFromStr(nil, reloadSide)
local reloadDoneRI = RedstoneInterface:createFromStr(nil, reloadDoneSide)
local triggerRI = RedstoneInterface:createFromStr(nil, triggerSide)

local function fastRotate(motor, deg)
	if deg == 0 then
		return
	end
	local rpm = math.floor(deg * 10 / 3)
	local ext = deg - rpm / 10 * 3
	if rpm ~= 0 then
		if rpm > maxRPM or rpm < -maxRPM then
			local t = math.floor(math.abs(rpm / maxRPM))
			local r = maxRPM
			if rpm < 0 then
				r = -r
				rpm = rpm + t * maxRPM
			else
				rpm = rpm - t * maxRPM
			end
			motor.setSpeed(r)
			sleep(t * 0.05)
		end
		if rpm >= 1 or rpm <= -1 then
			motor.setSpeed(rpm)
			sleep(0.05)
		end
	end
	if ext ~= 0 then
		sleep(motor.rotate(ext, 1))
	end
	motor.stop()
end

local function rotatePitch(deg)
	fastRotate(motorPitch, deg * pitchRotateRate)
end

local function rotateYaw(deg)
	fastRotate(motorYaw, deg * yawRotateRate)
end

local function guessPitch(x, y)
	local minDt = x / initSpeed
	local minVy = 2 * gravity * y
	local minRad = math.sqrt(minVy) / initSpeed
	print('x:', x, 'y:', y, 'minDt:', minDt, 'minVy:', minVy, 'minRad:', minRad)
	return minRad / math.pi * 360
end

local function calcPitchYaw(dx, dy, dz)
	local distance = math.sqrt(dx * dx + dz * dz)
	local yaw = math.abs(math.atan(dz / dx) * 180 / math.pi)
	if cannonFacing ~= '+x' then
		return false, 'Unexpected caonnon facing side '..cannonFacing
	end
	if dz >= 0 then
		if dx >= 0 then -- 1
			yaw = -yaw
		else -- 2
			yaw = yaw - 180
		end
	else -- if dz < 0
		if dx >= 0 then -- 3
			-- yaw = yaw
		else -- 4
			yaw = 180 - yaw
		end
	end
	local pitch = guessPitch(distance, dy)
	return true, pitch, yaw
end

local function turnTo(dx, dy, dz)
	assembleRI:setOutput(true)
	local ok, pitch, yaw = calcPitchYaw(dx, dy, dz)
	if not ok then
		return false, pitch
	end
	print('Aiming: pitch =', pitch, 'yaw =', yaw)
	parallel.waitForAll(
		function() rotatePitch(pitch) end,
		function() rotateYaw(yaw) end
	)
end

local function parseXYZ(line)
	local pos = {}
	local i, j = line:find('%s+')
	if not i then
		return false, 'Position format error'
	end
	pos.x = tonumber(line:sub(1, i - 1))
	local l = j + 1
	i, j = line:find('%s+', l)
	if not i then
		return false, 'Position format error'
	end
	pos.y = tonumber(line:sub(l, i - 1))
	pos.z = tonumber(line:sub(j + 1))
	return true, pos
end

function help()
	print('Usage:')
	print(' <x> <y> <z> [<flag>...]')
	print()
	print('Flags:')
	print(' dryrun: d | dry')
	print("  Only aiming the cannon but don't reload or fire")
end

function main(args)
	if #args < 3 then
		help()
		return
	end
	local x = tonumber(args[1])
	local y = tonumber(args[2])
	local z = tonumber(args[3])
	local flagDryrun = false
	for i = 4, #args do
		local f = args[i]:lower()
		if f == 'd' or f == 'dry' or f == 'dryrun' then
			flagDryrun = true
		end
	end

	assembleRI:setOutput(false)
	if not flagDryrun then
		print('Reloading ...')
		reloadRI:setOutput(true)
		sleep(0.1)
		reloadRI:setOutput(false)
	end
	repeat sleep(0) until reloadDoneRI:getInput()
	local dx = x - cannonPos.x
	local dz = z - cannonPos.z
	local dy = y - cannonPos.y
	turnTo(dx, dy, dz)
	sleep(0.1)
	if not flagDryrun then
		triggerRI:setOutput(true)
		sleep(0.1)
		triggerRI:setOutput(false)
	end
	assembleRI:setOutput(false)

	print('DONE')
end

main({...})
