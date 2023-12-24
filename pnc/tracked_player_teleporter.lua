-- Tracked player teleporter
-- by zyxkad@gmail.com

local modemSide = 'right'
local triggerSide = 'front'
local target = 'Perfectellis19'
local srcPos = {
	x = 127497,
	y = 63,
	z = 63690,
}

local drone = assert(peripheral.find('droneInterface'))

local function waitActionDone(action, timeout)
	if not drone.isConnectedToDrone() then
		return false, 'Drone not connected'
	end
	drone.setAction(action)
	action = drone.getAction()
	local exp = timeout and (os.clock() + timeout)
	while drone.isConnectedToDrone() and drone.getAction() == action and not drone.isActionDone() do
		if timeout and exp < os.clock() then
			return false
		end
		sleep(0)
	end
	return true
end

local function _tp(x1, y1, z1, x2, y2, z2)
	if x1 == x2 and y1 == y2 or z1 == z2 then
		return false, "Cannot teleport to current location"
	end
	print("Importing current position, don't move...")
	drone.clearArea()
	drone.addArea(x1, y1, z1)
	waitActionDone('teleport')
	if not waitActionDone('entity_import', 2) then
		drone.exitPiece()
		return false, 'Cannot import entity'
	end
	print(string.format('Teleporting to [%d %d %d] ...', x2, y2, z2))
	drone.clearArea()
	drone.addArea(x2, y2, z2)
	waitActionDone('teleport')
	sleep(3)
	waitActionDone('entity_export', 2)
	pcall(drone.exitPiece)
	return true
end

local pos = nil

local function recvPos()
	rednet.open(modemSide)
	while true do
		local _, data = rednet.receive('tracker')
		if data.target == target then
			pos = data.pos
			print('Position updated:', pos.x, pos.y, pos.z)
		end
	end
end

local function waitForTp()
	repeat sleep(0.1) until pos
	while true do
		if redstone.getInput(triggerSide) then
			print('Triggered ...')
			repeat sleep(0.1) until redstone.getInput(triggerSide)
			print('Teleporting ...')
			_tp(srcPos.x, srcPos.y, srcPos.z, pos.x, pos.y, pos.z)
			print('Done')
		end
		sleep(0.1)
	end
end

function main(args)
	parallel.waitForAll(
		recvPos,
		waitForTp
	)
end

main({...})
