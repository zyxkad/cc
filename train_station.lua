-- Create train station controller
-- by zyxkad@gmail.com


local RI = require('redstone_interface')

function main()
	local staion = peripheral.find('Create_Station')
	assert(staion, 'Station not found')
	local backLight = RI:createFromStr(nil, '#3:back')
	local function preventEnter()
		while true do
			local isasm = staion.isInAssemblyMode()
			backLight:setOutput(isasm)
			sleep(0)
		end
	end
	parallel.waitForAny(preventEnter)
end

main()
