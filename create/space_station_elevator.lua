-- Space Station Elevator
-- by zyxkad@gmail.com

local RedstoneInterface = require('redstone_interface')

local triggerUpDetector = 'playerDetector_7'
local triggerDownDetector = 'playerDetector_5'
local outsideCallButton = RedstoneInterface:new(nil, redstone, 'top')
local triggerElevatorOutput = RedstoneInterface:new(nil, redstone, 'left')
local elevatorStateInput = RedstoneInterface:new(nil, redstone, 'bottom')
local elevatorMoveDelay = 10

function main(args)
	while true do
		local _, pid = os.pullEvent('playerClick')
	end
end

main({...})
