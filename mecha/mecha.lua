-- Mecha Controller
-- by zyxkad@gmail.com

local servos = {}
local grasps = {}

local feedForwardForces = {
	leftTopLeg = 1.429e7,
	rightTopLeg = 1.429e7,
	leftBtmLeg = 5.3155e6,
	rightBtmLeg = 5.3155e6,
	leftTopLeg_sp = -2.8e7,
	rightTopLeg_sp = -2.8e7,
	leftBtmLeg_sp = -3.71e7,
	rightBtmLeg_sp = -3.71e7,
}

local PeripheralList = {}

function PeripheralList.__index(list, method)
	if type(method) ~= 'string' then
		return nil
	end
	if method == 'atleast' then
		return function (method, need)
			for i, p in ipairs(list) do
				local r = p[method]()
				if r then
					need = need - 1
					if need <= 0 then
						return true
					end
				end
			end
			return false
		end
	end
	if list[1] == nil or type(list[1][method]) ~= 'function' then
		return nil
	end

	local m = function(...)
		local args = table.pack(...)
		local fns = {}
		for i, p in ipairs(list) do
			local pm = p[method]
			fns[i] = function() pm(table.unpack(args)) end
		end
		parallel.waitForAll(table.unpack(fns))
	end
	list[method] = m
	return m
end

for _, servo in pairs({peripheral.find('servo')}) do
	local name = servo.getName()
	if name == nil then
		servo.setEnabled(false)
	else
		-- print('Found servo:', peripheral.getName(servo), name)
		local list = servos[name]
		if not list then
			list = setmetatable({}, PeripheralList)
			servos[name] = list
		end
		servo.setEnabled(true)
		servo.setPositionMode(true)
		servo.setMaxRotationSpeed(math.rad(360))
		list[#list + 1] = servo
	end
end

for _, grasp in pairs({peripheral.find('electro_grasp')}) do
	local name = grasp.getName()
	if name ~= nil then
		local list = grasps[name]
		if not list then
			list = setmetatable({}, PeripheralList)
			grasps[name] = list
		end
		grasp.setEnabled(true)
		list[#list + 1] = grasp
	end
end

print('Servos:')
for name, list in pairs(servos) do
	print(string.format(' %s -- %d', name, #list))
end

print('Grasps:')
for name, list in pairs(grasps) do
	print(string.format(' %s -- %d', name, #list))
end

local rightAngleOffset = 0
local leftAngleOffset = 0

local supportingPID = {2e7, 1e6, 0}
local steppingPID = {6e6, 1e6, 0}
local supporting = {
	leftTopLeg = false,
	leftBtmLeg = false,
	rightTopLeg = false,
	rightBtmLeg = false
}

local function setLeftVelPID(p, i, d)
	servos.leftTopLeg.setVelPID(p, i, d)
	servos.leftBtmLeg.setVelPID(p, i, d)
end

local function setRightVelPID(p, i, d)
	servos.rightTopLeg.setVelPID(p, i, d)
	servos.rightBtmLeg.setVelPID(p, i, d)
end

local function feedForwarder(servoGroup)
	local pollEvent = '_poll_' .. servoGroup
	local list = servos[servoGroup]
	local list1 = list[1]
	local force = feedForwardForces[servoGroup]
	local forceSp = feedForwardForces[servoGroup .. '_sp']
	while true do
		local angle = list1.getCurrentAngle()
		list.setFeedForwardForce((supporting[servoGroup] and forceSp or force) * math.sin(angle))
		os.queueEvent(pollEvent)
		os.pullEvent(pollEvent)
	end
end

local function resetPID()
	local servosList = {servos.leftTopLeg, servos.leftBtmLeg, servos.rightTopLeg, servos.rightBtmLeg}
	do
		local p, i, d = 7, 0, 4
		print('Setting position PID:', p, i, d)

		for _, l in ipairs(servosList) do
			l.setPosPID(p, i, d)
		end
	end
	do
		local p, i, d = table.unpack(steppingPID)
		print('Setting velocity PID:', p, i, d)

		setLeftVelPID(p, i, d)
		setRightVelPID(p, i, d)
	end
	-- do
	-- 	local alpha = 0
	-- 	print('Setting feed forward alpha:', alpha)

	-- 	for _, l in ipairs(servosList) do
	-- 		l.setFeedForwardAlpha(alpha)
	-- 	end
	-- end
end

local function moveTo(servos, target, err)
	err = err or math.rad(3)
	servos.setTargetAngle(target)
	while math.abs(servos[1].getCurrentAngle() - target) > err do
		sleep()
	end
end

local function stepRight()
	moveTo(servos.rightBtmLeg, rightAngleOffset + math.rad(-60), math.rad(15))
	parallel.waitForAll(function()
		moveTo(servos.rightTopLeg, rightAngleOffset + math.rad(60), math.rad(25))
		moveTo(servos.rightBtmLeg, rightAngleOffset + math.rad(27), math.rad(45))
	end, function()
		moveTo(servos.leftTopLeg, leftAngleOffset - math.rad(-30), math.rad(24))
	end)
	servos.leftBtmLeg.setTargetAngle(leftAngleOffset - math.rad(-60))

	servos.rightTopLeg.setTargetAngle(rightAngleOffset + math.rad(20))
	sleep(0.3)
end

local function stepLeft()
	moveTo(servos.leftBtmLeg, leftAngleOffset - math.rad(-60), math.rad(15))
	parallel.waitForAll(function()
		moveTo(servos.leftTopLeg, leftAngleOffset - math.rad(60), math.rad(25))
		moveTo(servos.leftBtmLeg, leftAngleOffset - math.rad(27), math.rad(45))
	end, function()
		moveTo(servos.rightTopLeg, rightAngleOffset + math.rad(-30), math.rad(24))
	end)
	servos.rightBtmLeg.setTargetAngle(rightAngleOffset + math.rad(-60))

	servos.leftTopLeg.setTargetAngle(leftAngleOffset - math.rad(20))
	sleep(0.3)
end

function runFeedForwarders()
	parallel.waitForAny(
		function() feedForwarder('leftTopLeg') end,
		function() feedForwarder('leftBtmLeg') end,
		function() feedForwarder('rightTopLeg') end,
		function() feedForwarder('rightBtmLeg') end
	)
end

function walk(n)
	grasps.leftFoot.attach()
	grasps.rightFoot.detach()
	setLeftVelPID(table.unpack(supportingPID))
	setRightVelPID(table.unpack(steppingPID))
	print('left attached:', grasps.leftFoot[1].isAttached())

	for i = 1, n do
		print('stepRight')
		stepRight()
		print('attaching right')
		repeat grasps.rightFoot.detach() sleep(0.1) grasps.rightFoot.attach() until grasps.rightFoot.atleast('isAttached', 5)
		print('right attached')
		grasps.leftFoot.detach()
		setRightVelPID(table.unpack(supportingPID))
		setLeftVelPID(table.unpack(steppingPID))
		supporting.rightTopLeg = true
		supporting.rightBtmLeg = true
		supporting.leftTopLeg = false
		supporting.leftBtmLeg = false
		print('stepLeft')
		stepLeft()
		print('attaching left')
		repeat grasps.leftFoot.detach() sleep(0.1) grasps.leftFoot.attach() until grasps.leftFoot.atleast('isAttached', 5)
		print('left attached')
		grasps.rightFoot.detach()
		setLeftVelPID(table.unpack(supportingPID))
		setRightVelPID(table.unpack(steppingPID))
		supporting.rightTopLeg = false
		supporting.rightBtmLeg = false
		supporting.leftTopLeg = true
		supporting.leftBtmLeg = true
	end

	servos.leftTopLeg.setTargetAngle(leftAngleOffset)
	servos.leftBtmLeg.setTargetAngle(leftAngleOffset)
	servos.rightTopLeg.setTargetAngle(rightAngleOffset)
	servos.rightBtmLeg.setTargetAngle(rightAngleOffset)
end

local args = {...}
local command = args[1]
if command == 'pid' then
	resetPID()
elseif command == 'lockRight' then
	grasps.rightFoot.attach()
	print(grasps.rightFoot.any('isAttached'))
elseif command == 'lockLeft' then
	grasps.leftFoot.attach()
	print(grasps.leftFoot.any('isAttached'))
elseif command == 'unlockRight' then
	grasps.rightFoot.detach()
elseif command == 'unlockLeft' then
	grasps.leftFoot.detach()
elseif command == 'unlock' then
	parallel.waitForAll(grasps.leftFoot.detach, grasps.rightFoot.detach)
elseif command == 'walk' then
	parallel.waitForAny(runFeedForwarders, function() walk(50) end)
elseif command == 'stand' then
	servos.leftTopLeg.setTargetAngle(leftAngleOffset)
	servos.leftBtmLeg.setTargetAngle(leftAngleOffset)
	servos.rightTopLeg.setTargetAngle(rightAngleOffset)
	servos.rightBtmLeg.setTargetAngle(rightAngleOffset)
elseif command == 'retractRight' then
	setLeftVelPID(table.unpack(supportingPID))
	setRightVelPID(table.unpack(steppingPID))
	servos.leftTopLeg.setTargetAngle(leftAngleOffset)
	servos.leftBtmLeg.setTargetAngle(leftAngleOffset)
	servos.rightTopLeg.setTargetAngle(rightAngleOffset + math.rad(60))
	servos.rightBtmLeg.setTargetAngle(rightAngleOffset - math.rad(60))
elseif command == 'test' then
	parallel.waitForAny(runFeedForwarders, function()
		while true do
			print('a')
			servos.leftTopLeg.setTargetAngle(leftAngleOffset - math.rad(45))
		servos.rightTopLeg.setTargetAngle(rightAngleOffset + math.rad(45))
			sleep(7)
			print('b')
			servos.leftTopLeg.setTargetAngle(leftAngleOffset + math.rad(45))
			servos.rightTopLeg.setTargetAngle(rightAngleOffset - math.rad(45))
			sleep(7)
		end
	end, function()
		while true do
			servos.leftBtmLeg.setTargetAngle(leftAngleOffset - math.rad(-45))
			servos.rightBtmLeg.setTargetAngle(rightAngleOffset + math.rad(-45))
			sleep(4)
			servos.leftBtmLeg.setTargetAngle(leftAngleOffset + math.rad(-45))
			servos.rightBtmLeg.setTargetAngle(rightAngleOffset - math.rad(-45))
			sleep(4)
		end
	end)
end
