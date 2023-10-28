-- Auto cool down pnC solar compressor
-- by zyxkad@gmail.com

local compressor = peripheral.wrap('left')

assert(compressor, 'must have a compressor connected to the left')

local coolDownAt = 360
local shutDownAt = 390

local temp = compressor.getTemperature() - 273
local cooling = false
local disabled = false

local function update()
	while true do
		temp = compressor.getTemperature() - 273
		if temp > coolDownAt then
			redstone.setOutput('front', true)
			if temp > shutDownAt then
				redstone.setOutput('right', true)
				cooling = true
				sleep(1)
				cooling = false
			end
		else
			redstone.setOutput('front', false)
		end
		redstone.setOutput('right', disabled)
		sleep(0.1)
	end
end

local function draw()
	while true do
		term.clear()
		term.setCursorPos(1, 2)
		term.write(string.format('temp: %.2f', temp))
		term.setCursorPos(1, 3)
		term.write('Click to: ')
		term.write(disabled and 'ENABLE' or 'DISABLE')
		sleep(0.1)
	end
end

local function listen()
	while true do
		local event, p1, p2, p3 = os.pullEvent()
		if event == 'mouse_click' then
			local x, y = p2, p3
			if y == 3 then
				disabled = not disabled
			end
		end
	end
end

local function main()
	parallel.waitForAny(update, draw, listen)
end

main()
