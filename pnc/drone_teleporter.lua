
local triggerSide = 'front'
local enable_whitelist = false
local maxSpawnRetry = 15
local waitBeforeRetry = 6

local whitelist = enable_whitelist and require('whitelist') or nil

local drone = peripheral.find('drone_interface')
if not drone then
	printError('No drone interface was found')
	return
end

local chatBox = peripheral.find('chatBox')
if not chatBox then
	printError('No chat box was found')
	return
end

local function inList(list, item)
	return table.foreachi(list, function(_, v) return v == item or nil end) or false
end

local function hadPrefix(str, prefix)
	return #str > #prefix and str:sub(1, #prefix) == prefix
end

local function findBetween(str, prefix, suffix, starti, endi)
	local i = str:find(prefix, starti, endi)
	if not i then
		return nil
	end
	i = i + #prefix
	local j = str:find(suffix, i, endi)
	if not j then
		return nil
	end
	j = j - #suffix
	local res = str:sub(i, j)
	return res, i, j
end

local function sendError(msg, player)
	return chatBox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
		text = '',
		extra = {
			{
				text = msg,
				color = 'red',
				underlined = true,
			}
		}
	}), player, 'DT ERR')
end

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
		sleep(0.1)
	end
	return true
end

local function getPlayerPos(player)
	if not drone.isConnectedToDrone() then
		return nil, 'Drone not connected'
	end
	local x, y, z = drone.getVariable('$player_pos='..player)
	if x == 0 and y == 0 and z == 0 then
		return nil, 'Player is not online'
	end
	return {
		x=x,
		y=y,
		z=z,
	}
end

local function spawnDrone()
	for i = 1, maxSpawnRetry do
		if drone.isConnectedToDrone() then
			return true
		end
		redstone.setOutput(triggerSide, true)
		sleep(0.1)
		redstone.setOutput(triggerSide, false)
		sleep(waitBeforeRetry)
	end
	return false
end

local function _tp(sender, x1, y1, z1, x2, y2, z2)
	if x1 == x2 and y1 == y2 or z1 == z2 then
		return false, "Cannot teleport to current location"
	end
	if not spawnDrone() then
		return false, 'Cannot spawn drone'
	end
	chatBox.sendMessageToPlayer('Importing current position, don\'t move...', sender, 'DT')
	drone.clearArea()
	drone.addArea(x1, y1, z1)
	waitActionDone('teleport')
	if not waitActionDone('entity_import', 2) then
		drone.exitPiece()
		return false, 'Cannot import entity'
	end
	chatBox.sendMessageToPlayer(string.format('Teleporting to [%d %d %d] ...', x2, y2, z2), sender, 'DT')
	drone.clearArea()
	drone.addArea(x2, y2, z2)
	waitActionDone('teleport')
	sleep(100)
	waitActionDone('entity_export', 2)
	pcall(drone.exitPiece)
	return true
end

local function tp2(sender, arg)
	if enable_whitelist and not inList(whitelist, sender) then
		return false, 'You are not in the whitelist, contact <ckupen> or <zyxkad#4421> in discord to get whitelist'
	end
	local target = arg
	if target == sender then
		return false, "Cannot teleport to your self"
	end
	if enable_whitelist and not inList(whitelist, target) then
		return false, 'The target player are not in the whitelist'
	end
	local tg = getPlayerPos(target)
	if not tg then
		return false, "Target wasn't found"
	end
	local sd = getPlayerPos(sender)
	if not sd then
		return false, "Cannot locate current position"
	end
	local ok, err = _tp(sender, sd.x, sd.y, sd.z, tg.x, tg.y, tg.z)
	if not ok then
		return false, err
	end
	chatBox.sendMessageToPlayer('Done', sender, 'DT')
	return true
end

local function tp3(sender, arg)
	if enable_whitelist and not inList(whitelist, sender) then
		return false, "You are not in the whitelist, contact <ckupen> or <zyxkad#4421> in discord to get whitelist"
	end
	local x, y, z
	local i = arg:find(' ')
	if not i then
		return false, 'Missing 2 args, Usage: .tp3 <x> <y> <z>'
	end
	x, arg = tonumber(arg:sub(1, i - 1)), arg:sub(i + 1)
	i = arg:find(' ')
	if not i then
		return false, 'Missing 1 arg, Usage: .tp3 <x> <y> <z>'
	end
	y, arg = tonumber(arg:sub(1, i - 1)), arg:sub(i + 1)
	z = tonumber(arg)
	if not x then
		return false, "argument 'x' must be a number"
	end
	if not y then
		return false, "argument 'y' must be a number"
	end
	if not z then
		return false, "argument 'z' must be a number"
	end
	local sd = getPlayerPos(sender)
	if not sd then
		return false, "Cannot locate current position"
	end
	local ok, err = _tp(sender, sd.x, sd.y, sd.z, x, y, z)
	if not ok then
		return false, err
	end
	chatBox.sendMessageToPlayer('Done', sender, 'DT')
	return true
end

local function warp(sender, arg)
	if enable_whitelist and not inList(whitelist, sender) then
		return false, "You are not in the whitelist, contact <ckupen> or <zyxkad#4421> in discord to get whitelist"
	end
	local target = arg
	local sd = getPlayerPos(sender)
	if not sd then
		return false, "Cannot locate current position"
	end
	if target == 'spawn' then
		return _tp(sender, sd.x, sd.y, sd.z, 0, 67, 0)
	end
	return false, 'Target not found'
end

local function addWaypoint(sender, arg)
	-- [name:"SPAWN", x:0, y:67, z:0, dim:minecraft:overworld]
	local name, x, y, z
	name = findBetween(arg, 'name:"', '"')
	if not name then
		return false
	end
	x = tonumber(({findBetween(arg, 'x:', ',')})[1])
	if not x then
		return false
	end
	y = tonumber(({findBetween(arg, 'y:', ',')})[1])
	if not y then
		return false
	end
	z = tonumber(({findBetween(arg, 'z:', ',')})[1])
	if not z then
		return false
	end
	chatBox.sendFormattedMessage(textutils.serialiseJSON({
		text = '',
		extra = {
			{
				text = 'Recevied a waypoint from ',
			},
			{
				text = sender,
				color = 'yellow',
				clickEvent = {
					action = 'suggest_command',
					value = sender,
				},
			},
			{
				text = string.format(' (%s)[%d %d %d]', name, x, y, z),
				color = 'aqua',
				underlined = true,
				clickEvent = {
					action = 'suggest_command',
					value = string.format('.tp3 %d %d %d', x, y, z),
				},
				hoverEvent = {
					action = 'show_text',
					value = 'Click to teleport',
				},
			}
		}
	}), 'DT')
end

while true do
	if drone.isConnectedToDrone() then
		drone.exitPiece()
	end
	local _, sender, msg = os.pullEvent('chat')
	if msg == '.tp' then
		chatBox.sendFormattedMessage(textutils.serialiseJSON({
			text = '',
			extra = {
				{
					text = 'Recevied a waypoint from ',
				},
				{
					text = sender,
					color = 'yellow',
					clickEvent = {
						action = 'suggest_command',
						value = sender,
					},
				},
				{
					text = string.format(' (%s)[%d %d %d]', name, x, y, z),
					color = 'aqua',
					underlined = true,
					clickEvent = {
						action = 'suggest_command',
						value = string.format('.tp3 ', x, y, z),
					},
					hoverEvent = {
						action = 'show_text',
						value = '.tp3',
					},
				}
			}
		}), 'DT')
	elseif msg == '.tp2' then
		sendError('Usage: .tp2 <player>', sender)
	elseif hadPrefix(msg, '.tp2 ') then
		local ok, err = tp2(sender, msg:sub(6))
		if not ok then
			sendError(err, sender)
		end
	elseif msg == '.tp3' then
		sendError('Usage: .tp3 <x> <y> <z>', sender)
	elseif hadPrefix(msg, '.tp3 ') then
		local ok, err = tp3(sender, msg:sub(6))
		if not ok and err then
			sendError(err, sender)
		end
	elseif msg == '.warp' then
	elseif hadPrefix(msg, '.warp ') then
		local ok, err = warp(sender, msg:sub(7))
		if not ok and err then
			sendError(err, sender)
		end
	else
		if msg:sub(1, 1) == '[' and msg:sub(-1) == ']' then
			msg = msg:sub(2, -2)
			if msg:find('dim:minecraft:overworld') then
				local ok, err = addWaypoint(sender, msg)
				if not ok and err then
					sendError(err, sender)
				end
			end
		end
	end
end

