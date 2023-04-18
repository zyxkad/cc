-- Create mod rotate door controller
-- by zyxkad@gmail.com

local moveSpeed = 10
local statFile = 'door_closed.json'

local motorId = 'electric_motor'
local playerDetectorId = 'playerDetector'

if not parallel then
	error('Need parallel API')
end

function readStat()
	local fd = io.open(statFile, 'r')
	if fd then
		local data = textutils.unserialiseJSON(fd:read('*all'))
		fd:close()
		return data
	end
	return false
end

function saveStat(data)
	local fd, err = io.open(statFile, 'w')
	if not fd then
		printError('E:', err)
	end
	fd:write(textutils.serialiseJSON(data))
	fd:close()
end

function main(args)
	local motor = peripheral.find(motorId)
	local moving = false
	local nextOpen = readStat()
	function switchDoor()
		if moving then
			return false
		end
		moving = true
		sleep(motor.rotate(90, nextOpen and -moveSpeed or moveSpeed))
		motor.stop()
		nextOpen = not nextOpen
		saveStat(nextOpen)
		moving = false
		return true
	end
	function pollRedStone()
		while true do
			if redstone.getInput('front') then
				local ok = not moving
				if ok then
					switchDoor()
				end
				repeat sleep(0) until not redstone.getInput('front')
				if ok then
					redstone.setOutput('front', true)
					sleep(0.1)
					redstone.setOutput('front', false)
				end
			end
			sleep(0.1)
		end
	end
	function pollPlayerClick()
		while true do
			local _, player = os.pullEvent('playerClick')
			switchDoor()
		end
	end
	function pollAutomaticDoor()
		while true do
			local pd = peripheral.find(playerDetectorId)
			if pd then
				if nextOpen and #(pd.getPlayersInRange(1)) > 0 then
					if switchDoor() then
						repeat sleep(0) until not moving
						pd = peripheral.find(playerDetectorId)
						while pd == nil do -- since the player detector's id will change after move
							sleep(0)
							pd = peripheral.find(playerDetectorId)
						end
						while not nextOpen and not moving do -- close the door
							local ps = pd.getPlayersInRange(2.7)
							if ps and #ps == 0 then
								switchDoor()
								break
							end
							sleep(0) -- yield
						end
					end
				end
			end
			sleep(0.05)
		end
	end
	parallel.waitForAny(
		pollRedStone,
		pollPlayerClick,
		pollAutomaticDoor)
end

main({...})
