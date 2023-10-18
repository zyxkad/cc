-- Auto cool down pnC solar compressor
-- by zyxkad@gmail.com

local compressor = peripheral.wrap('left')

assert(compressor, 'must have a compressor connected to the left')

local coolDownAt = 360
local shutDownAt = 395

while true do
	local t = compressor.getTemperature() - 273
	print(string.format('temp: %.2f', t))
	if t > coolDownAt then
		redstone.setOutput('front', true)
		if t > shutDownAt then
			redstone.setOutput('right', true)
			print('cooling the compressor for a sec')
			sleep(1)
			redstone.setOutput('right', false)
		else
			redstone.setOutput('right', false)
		end
	else
		redstone.setOutput('front', false)
		redstone.setOutput('right', false)
	end
	sleep(0.1)
end
