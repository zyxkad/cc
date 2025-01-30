-- Simple ship controller
-- by zyxkad@gmail.com

local maxEngineSpeed = 256
local minEngineSpeed = -256
local engineSpeedMultiplier = -1
local engineTargetSpeed = 0
local leftResistor = 0
local rightResistor = 0

local pressedKey = {}

local function pollEvents()
	while true do
		local event, v1, v2 = os.pullEvent()
		if event == 'key' then
			pressedKey[v1] = true
		elseif event == 'key_up' then
			pressedKey[v1] = nil
		end
	end
end

local function update()
	while true do
		sleep(0.1)
		if pressedKey[keys.space] then
			engineTargetSpeed = 0
		else
			if pressedKey[keys.w] then
				engineTargetSpeed = math.min(engineTargetSpeed + 1, maxEngineSpeed)
			end
			if pressedKey[keys.s] then
				engineTargetSpeed = math.max(engineTargetSpeed - 1, minEngineSpeed)
			end
		end
		if pressedKey[keys.a] then
			leftResistor = 15
		else
			leftResistor = 0
		end
		if pressedKey[keys.d] then
			rightResistor = 15
		else
			rightResistor = 0
		end
	end
end

local function render(monitor)
	monitor.clear()
	while true do
		sleep(0)
		monitor.setCursorPos(1, 1)
		monitor.clearLine()
		monitor.write('Time: ' .. os.clock())
		monitor.setCursorPos(1, 2)
		monitor.clearLine()
		monitor.write('Power: ' .. engineTargetSpeed)
	end
end

function main(...)
	local engineController = peripheral.wrap('Create_RotationSpeedController_0')
	local leftResistorRelay = peripheral.wrap('redstone_relay_0')
	local rightResistorRelay = peripheral.wrap('redstone_relay_1')

	parallel.waitForAny(
		pollEvents,
		update,
		function() render(term) end,
		function()
			while true do
				sleep(0.5)
				engineController.setTargetSpeed(engineTargetSpeed * engineSpeedMultiplier)
				leftResistorRelay.setAnalogOutput('front', leftResistor)
				rightResistorRelay.setAnalogOutput('front', rightResistor)
			end
		end)
end

main(...)
