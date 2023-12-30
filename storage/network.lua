-- CC Storage - underlying network
-- by zyxkad@gmail.com

local BROADCAST_CHANNEL = 65522

-- local modem = peripheral.find('modem', function(_, modem) return peripheral.hasType(modem, 'peripheral_hub') end)

local started = false
local localId = os.getComputerID()
local localType = nil

local function idToChannel(id)
	return id % 60000
end

local localReplyCh = idToChannel(localId)

local function getType()
	return localType
end

local function setType(typ)
	localType = typ
end

local openedModems = {}

local function open(modem)
	if type(modem) ~= 'string' then
		modem = peripheral.getName(modem)
	end
	assert(peripheral.hasType(modem, 'modem'))

	peripheral.call(modem, 'open', BROADCAST_CHANNEL)
	peripheral.call(modem, 'open', localReplyCh)
	openedModems[modem] = true
end

local function close(modem)
	if type(modem) ~= 'string' then
		modem = peripheral.getName(modem)
	end
	assert(openedModems[modem])
	peripheral.call(modem, 'close', BROADCAST_CHANNEL)
	peripheral.call(modem, 'close', localReplyCh)
	openedModems[modem] = nil
end

local function closeAll()
	for modem, _ in pairs(openedModems) do
		peripheral.call(modem, 'close', BROADCAST_CHANNEL)
		peripheral.call(modem, 'close', localReplyCh)
	end
	openedModems = {}
end

local function transmit(...)
	for modem, _ in pairs(openedModems) do
		peripheral.call(modem, 'transmit', ...)
	end
end

local messages = {}

local function send(target, command, payload, hasReply, replyTimeout)
	assert(type(target) == 'number')
	assert(target ~= localId, 'Should not send message to self')
	assert(type(command) == 'string')
	assert(type(hasReply) == 'nil' or type(hasReply) == 'boolean')
	assert(type(replyTimeout) == 'nil' or type(replyTimeout) == 'number')

	assert(started, 'Network is down')

	local id = nil
	if hasReply then
		repeat
			id = math.random(1, 2147483647)
		until not messages[id]
		messages[id] = true
	end

	transmit(idToChannel(target), localReplyCh, {
		id = id,
		cmd = command,
		hostType = localType,
		hostId = localId,
		targetId = target,
		payload = payload,
	})

	if not hasReply then
		return
	end

	local filter = 'modem_message'
	local timerId = nil
	if replyTimeout then
		filter = nil
		timerId = os.startTimer(replyTimeout)
	end
	while true do
		local event, p1, p2, p3, p4 = os.pullEvent(filter)
		if event == 'modem_message' then
			local fromModem, sendCh, replyCh, message = p1, p2, p3, p4
			if openedModems[fromModem] and sendCh == localReplyCh and
				 type(message) == 'table' and
				 type(message.cmd) == 'string' and message.cmd == command and
				 type(message.hostId) == 'number' and message.hostId == target and
				 type(message.targetId) == 'number' and message.targetId == localId and
				 type(message.reply) == 'number' and message.reply == id then
				local payload = message.payload
				messages[id] = nil
				return true, payload
			end
		elseif event == 'timer' and p1 == timerId then
			messages[id] = nil
			return false
		end
	end
end

local function broadcast(command, payload, replyTimeout, singleReply)
	assert(type(command) == 'string')
	assert(type(replyTimeout) == 'nil' or type(replyTimeout) == 'number')

	assert(started, 'Network is down')

	local id = nil
	if replyTimeout then
		repeat
			id = math.random(1, 2147483647)
		until not messages[id]
		messages[id] = true
	end

	transmit(BROADCAST_CHANNEL, localReplyCh, {
		cmd = command,
		hostType = localType,
		hostId = localId,
		payload = payload,
	})

	if not replyTimeout then
		return
	end

	local timerId = os.startTimer(replyTimeout)
	local replies = {}
	while true do
		local event, p1, p2, p3, p4 = os.pullEvent()
		if event == 'modem_message' then
			local fromModem, sendCh, replyCh, message = p1, p2, p3, p4
			if openedModems[fromModem] and sendCh == localReplyCh and
				 type(message) == 'table' and type(message.hostId) == 'number' and
				 type(message.cmd) == 'string' and message.cmd == command and
				 type(message.targetId) == 'number' and message.targetId == localId and
				 type(message.reply) == 'number' and message.reply == id then
				local payload = message.payload
				if singleReply then
					messages[id] = nil
					return message.hostId, payload
				end
				replies[message.hostId] = payload
			end
		elseif event == 'timer' and p1 == timerId then
			break
		end
	end
	messages[id] = nil
	return replies
end

local function _reply(command, target, replyCh, messageId, payload)
	assert(type(command) == 'string')
	assert(type(target) == 'number')
	assert(target ~= localId, 'Should not send message to self')
	assert(type(replyCh) == 'number')
	assert(type(messageId) == 'number')

	assert(started, 'Network is down')

	transmit(replyCh, localReplyCh, {
		cmd = command,
		reply = messageId,
		hostType = localType,
		hostId = localId,
		targetId = target,
		payload = payload,
	})
end

local commands = {
	['ping'] = function(_, sender, payload, reply)
		reply(payload)
	end
}

local function registerCommand(command, callback)
	assert(type(command) == 'string')
	assert(type(callback) == 'function')
	commands[command] = callback
end

local function run()
	assert(not started, 'Network was already started')
	started = true

	while true do
		local event, p1, p2, p3, p4 = os.pullEvent()
		if event == 'modem_message' then
			local fromModem, sendCh, replyCh, message = p1, p2, p3, p4
			if openedModems[fromModem] and sendCh == localReplyCh or sendCh == BROADCAST_CHANNEL and
				 type(message) == 'table' and type(message.cmd) == 'string' and type(message.hostId) == 'number' and
				 (not message.targetId or type(message.targetId) == 'number' and message.targetId == localId) and
				 not message.reply then
				local cmd, messageId, sender, payload = message.cmd, message.id, message.hostId, message.payload
				local cb = commands[cmd]
				if cb then
					local replied = false
					cb(cmd, sender, payload, function(response)
						if messageId then
							assert(not replied, 'Cannot reply twice')
							replied = true
							_reply(cmd, sender, replyCh, messageId, response)
						end
					end)
				end
			end
		end
	end
end

return {
	open = open,
	close = close,
	closeAll = closeAll,
	run = run,
	send = send,
	broadcast = broadcast,
	getType = getType,
	setType = setType,
	registerCommand = registerCommand,
}
