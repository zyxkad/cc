-- broadcast players' pos from pnC drone
-- by zyxkad@gmail.com

-- ${$player_pos=<name>}

local drone = assert(peripheral.find('droneInterface'))
local chatbox = assert(peripheral.find('chatBox'))

local whitelist = require('whitelist')

local function inWhitelist(item)
	item = item:lower()
	return table.foreachi(whitelist, function(_, v) return v:lower() == item or nil end) or nil
end

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function getPlayerPos(player)
	if not drone.isConnectedToDrone() then
		return nil, 'Drone not connected'
	end
	local x, y, z = drone.getVariable('$player_pos='..player)
	if x == 0 and y == 0 and z == 0 then
		return nil, 'Player is not online'
	end
	return x, y, z
end

local function queryPlayer(player, target)
	if #target < 3 or #target > 16 or target:find('%s') then
		return
	end
	local x, y, z = getPlayerPos(target)
	if not x then
		chatbox.sendMessageToPlayer('Error: '..y, player, 'Tracker')
		return
	end
	chatbox.sendMessageToPlayer(string.format('X: %d Y: %d Z: %d', x, y, z), player, 'Tracker')
end

local function command()
	while true do
		local _, player, msg = os.pullEvent('chat')
		if inWhitelist(player) then
			if startswith(msg, '.w ') then
				local target = msg:sub(#'.w ' + 1)
				queryPlayer(player, target)
			elseif startswith(msg, 'w ') then
				local target = msg:sub(#'w ' + 1)
				queryPlayer(player, target)
			elseif startswith(msg, 'where ') then
				local target = msg:sub(#'where ' + 1)
				queryPlayer(player, target)
			end
			sleep(1)
		end
	end
end

function main(args)
	parallel.waitForAny(
		command
	)
end

main({...})
