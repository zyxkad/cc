-- Simple tank controller
-- by zyxkad@gmail.com

local leftTrackName = 'Create_RotationSpeedController_0'
local rightTrackName = 'Create_RotationSpeedController_1'

local function round(num)
	return math.floor(num + 0.5)
end

local RedstoneAccessor = {}
RedstoneAccessor.mt = { __index = RedstoneAccessor }

function RedstoneAccessor:new(obj, name, side)
	obj = obj or {}
	setmetatable(obj, self.mt)
	obj._peripheral = type(name) == 'table' and name or assert(peripheral.wrap(name))
	obj._side = side
	return obj
end

for _, name in ipairs({'getInput', 'getAnalogInput', 'getOutput', 'getAnalogOutput', 'setOutput', 'setAnalogOutput'}) do
	RedstoneAccessor[name] = function(accessor, value)
		return accessor._peripheral[name](accessor._side, value)
	end
end

local ResistorPair = {}
ResistorPair.mt = { __index = ResistorPair }

function ResistorPair:new(obj, gearshiftName, gearshiftSide, resistorName, resistorSide)
	obj = obj or {}
	setmetatable(obj, self.mt)
	obj._gearshift = assert(peripheral.wrap(gearshiftName))
	obj._gearshiftSide = gearshiftSide
	obj._resistor = assert(peripheral.wrap(resistorName))
	obj._resistorSide = resistorSide
	return obj
end

function ResistorPair:setPower(power)
	local reversed = power < 0
	if reversed then
		power = -power
	end
	power = math.min(power, 1)
	local level = round((1 - power) * 15)
	if level < 15 then
		self._gearshift.setOutput(self._gearshiftSide, reversed)
	end
	self._resistor.setAnalogOutput(self._resistorSide, level)
end

function main()
	local yawController = ResistorPair:new(nil, 'redstone_relay_0', 'front', 'redstone_relay_1', 'front')
	local pitchController = ResistorPair:new(nil, 'redstone_relay_1', 'top', 'redstone_relay_2', 'top')
	local leftTrackController = assert(peripheral.wrap(leftTrackName))
	local rightTrackController = assert(peripheral.wrap(rightTrackName))

	local leftXNInput = RedstoneAccessor:new(nil, 'redstone_relay_2', 'left')
	local leftXPInput = RedstoneAccessor:new(nil, 'redstone_relay_2', 'right')
	local leftYNInput = RedstoneAccessor:new(nil, 'redstone_relay_2', 'front')
	local leftYPInput = RedstoneAccessor:new(nil, 'redstone_relay_2', 'back')
	local sprintInput = RedstoneAccessor:new(nil, 'redstone_relay_2', 'top')

	local rightXNInput = RedstoneAccessor:new(nil, 'redstone_relay_0', 'right')
	local rightXPInput = RedstoneAccessor:new(nil, 'redstone_relay_0', 'left')
	local rightYNInput = RedstoneAccessor:new(nil, 'redstone_relay_1', 'right')
	local rightYPInput = RedstoneAccessor:new(nil, 'redstone_relay_1', 'left')

	local function tick()
		local sprinting = sprintInput:getInput()
		local turnPower = (leftXNInput:getAnalogInput() - leftXPInput:getAnalogInput()) / 15
		local forwardPower = (leftYNInput:getAnalogInput() - leftYPInput:getAnalogInput()) / 15
		local yawPower = -(rightXNInput:getAnalogInput() - rightXPInput:getAnalogInput()) / 15
		local pitchPower = (rightYNInput:getAnalogInput() - rightYPInput:getAnalogInput()) / 15

		if not sprinting then
			forwardPower = forwardPower * 0.7
		end

		local leftTrackPower = forwardPower - turnPower
		local rightTrackPower = forwardPower + turnPower
		if turnPower ~= 0 then
			leftTrackPower = leftTrackPower / 2
			rightTrackPower = rightTrackPower / 2
		end

		pitchController:setPower(pitchPower)
		yawController:setPower(yawPower)
		leftTrackController.setTargetSpeed(round(leftTrackPower * 256))
		rightTrackController.setTargetSpeed(round(rightTrackPower * 256))
	end

	while true do
		tick()
		sleep(0.1)
	end
end

main()
