-- Teleporter manger for Mekanism
-- by zyxkad@gmail.com

if not parallel then
	error('Need parallel API')
end

local NAMELIST_OFFSET = 3

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function gamedate()
	local sec = math.floor(os.epoch('ingame') / 1000)
	local min = math.floor(sec / 60)
	local hour = math.floor(min / 60)
	local days = math.floor(hour / 24)
	return string.format("Day %d %02d:%02d:%02d", days, hour % 24, min % 60, sec % 60)
end

local function getFrequencies(teleporter, frequency)
	local res = {}
	local ls = teleporter.getFrequencies()
	for _, v in ipairs(ls) do
		if v.key ~= frequency then
			res[#res + 1] = v
		end
	end
	return res
end

local function hasFrequency(teleporter, frequency)
	local ls = teleporter.getFrequencies()
	for _, v in ipairs(ls) do
		if v.key == frequency then
			return true
		end
	end
	return false
end

local function getFrequencyHostname(frequency)
	return string.format("teleporter-[%s]", frequency)
end

local function termUpdateAt(t, x, y, data)
	t.setCursorPos(x, y)
	t.clearLine()
	if data then
		t.write(data)
	end
end

local function waiting_reply(sender, protocol, timeout)
	local src, reply, prot
	local begin = os.clock()
	local endtime
	if timeout then
		endtime = begin + timeout
	end
	repeat
		timeout = endtime - os.clock()
		if timeout < 0 then
			return nil
		end
		src, reply, prot = rednet.receive(protocol, timeout)
	until not sender or src == sender
	return src, reply, prot
end

-- local osPullEvent, osPullEventRaw = os.pullEvent, os.pullEventRaw
-- local eventListener = {}
-- local timerListener = {}
-- local cleanups = {}
-- local function setTimeout(timeout, callback, ...)
-- 	local arg = {...}
-- 	local tid = os.startTimer(timeout)
-- 	local canceler = function() timerListener[tid] = nil end
-- 	cleanups[#cleanups + 1] = canceler
-- 	timerListener[tid] = function()
-- 		timerListener[tid] = nil
-- 		callback(table.unpack(arg))
-- 		return true
-- 	end
-- 	return canceler
-- end
-- local function setInterval(interval, callback, ...)
-- 	local arg = {...}
-- 	local tid
-- 	local canceled = false
-- 	local canceler = function() canceled = true; timerListener[tid] = nil end
-- 	cleanups[#cleanups + 1] = canceler
-- 	local wrap
-- 	wrap = function()
-- 		timerListener[tid] = nil
-- 		local passed = false
-- 		tid = os.startTimer(interval)
-- 		-- print('new tid:', tid)
-- 		timerListener[tid] = function() passed = true; timerListener[tid] = nil end
-- 		callback(table.unpack(arg))
-- 		if not canceled then
-- 			if passed then
-- 				-- call immedialy
-- 				print('debug', 'a interval tick passed')
-- 				wrap()
-- 			else
-- 				timerListener[tid] = wrap
-- 			end
-- 		end
-- 		return true
-- 	end
-- 	tid = os.startTimer(interval)
-- 	timerListener[tid] = wrap
-- 	return canceler
-- end
-- local eventQueue = nil
-- local function wrappedOsRawEventPuller(filter, noraw)
-- 	if eventQueue then
-- 		local e = eventQueue
-- 		if not filter or e.name == filter then
-- 			eventQueue = e.next
-- 			return table.unpack(e.val)
-- 		end
-- 		local s
-- 		while e.next do
-- 			s, e = e, e.next
-- 			if e.name == filter then
-- 				s.next = e.next
-- 				return table.unpack(e.val)
-- 			end
-- 		end
-- 	end
-- 	while true do
-- 		local event = {osPullEventRaw()}
-- 		local name = event[1]
-- 		if name == 'terminate' then
-- 			print('cleanups:', #cleanups)
-- 			for _, c in ipairs(cleanups) do
-- 				c()
-- 			end
-- 			cleanups = {}
-- 			os.pullEvent, os.pullEventRaw = osPullEvent, osPullEventRaw
-- 			if noraw then
-- 				error('Wrapped Terminate')
-- 			end
-- 		end
-- 		local listener = (name == 'timer' and timerListener[event[2]]) or (eventListener[name])
-- 		if not listener or not listener(table.unpack(event)) then
-- 			if not filter or filter == name then
-- 				return table.unpack(event)
-- 			end
-- 			eventQueue = {
-- 				name = name,
-- 				val = event,
-- 				next = eventQueue,
-- 			}
-- 		end
-- 	end
-- end
-- os.pullEventRaw = wrappedOsRawEventPuller
-- os.pullEvent = function(filter)
-- 	return wrappedOsRawEventPuller(filter, true)
-- end

local function main(arg)
	local frequency = arg[1]
	local teleporter_name = arg[2]
	local monitor_name = arg[3]

	if not frequency then
		printError('You must give a frequency for this teleporter point')
		print('Usage: <frequency> <teleporter name> [<monitor name>]')
		return
	end
	if not teleporter_name then
		printError('You must give a peripheral name of the teleporter')
		print('Usage: <frequency> <teleporter name> [<monitor name>]')
		return
	end
	local tpr = peripheral.wrap(teleporter_name)
	if not tpr then
		printError(string.format('Cannot find peripheral %s', teleporter_name))
		return
	end
	if peripheral.getType(tpr) ~= 'teleporter' then
		printError(string.format('%s is not a teleporter', teleporter_name))
		return
	end

	if not hasFrequency(tpr, frequency) then
		tpr.createFrequency(frequency)
	end
	tpr.setFrequency(frequency)

	local monitor
	if monitor_name then
		monitor = peripheral.wrap(monitor_name)
		if not monitor then
			printError(string.format('Cannot find peripheral %s, using default terminal', monitor_name))
			sleep(1.5)
		elseif peripheral.getType(monitor) ~= 'monitor' then
			printError(string.format('%s is not a monitor', monitor_name))
			return
		end
	end
	if not monitor then
		monitor = term
	end

	peripheral.find('modem', rednet.open)
	if not rednet.isOpen() then
		printError('No any modem was found')
		return
	end
	rednet.host('teleporter', getFrequencyHostname(frequency))

	function update()
		local energy, maxEnergy = tpr.getEnergy(), tpr.getMaxEnergy()
		local targets = getFrequencies(tpr, frequency)
		local selected = tpr.hasFrequency() and tpr.getFrequency()
		local status = tpr.getStatus()
		local mWidth, mHeight = monitor.getSize()
		if not mWidth then
			error('monitor detached')
		end
		monitor.setTextColor(colors.black)
		monitor.setBackgroundColor(colors.lightGray)
		termUpdateAt(monitor, 3, 1, gamedate())
		termUpdateAt(monitor, 1, 2, string.format("Energy: %d / %d", energy, maxEnergy))
		if targets then
			for i, t in ipairs(targets) do
				monitor.setCursorPos(1, i + NAMELIST_OFFSET)
				if selected and t.key == selected.key then
					monitor.setTextColor(colors.black)
					monitor.setBackgroundColor(colors.lightGray)
					monitor.clearLine()
					monitor.write(string.format("%d. %s", i, t.key))

					monitor.setCursorPos(mWidth - #status - 3, i + NAMELIST_OFFSET)
					if status:lower() == 'ready' then
						monitor.setTextColor(colors.green)
					else
						monitor.setTextColor(colors.red)
					end
					monitor.setBackgroundColor(colors.black)
					local status = '['..status..']'
					monitor.write(status)
				else
					monitor.setTextColor(colors.white)
					monitor.setBackgroundColor(colors.black)
					monitor.clearLine()
					monitor.write(string.format("%d. %s", i, t.key))
				end
			end
			monitor.setTextColor(colors.white)
			monitor.setBackgroundColor(colors.black)
			local extra_offset = NAMELIST_OFFSET + #targets + 1
			for i = extra_offset, mWidth do
				termUpdateAt(monitor, 1, i)
			end
		else
			monitor.setTextColor(colors.red)
			termUpdateAt(monitor, 1, 1 + NAMELIST_OFFSET, 'ERROR: Cannot get frequencies')
		end
		if tpr.hasFrequency() then
			tpr.incrementFrequencyColor()
		end
	end

	monitor.setTextColor(colors.white)
	monitor.setBackgroundColor(colors.black)
	termUpdateAt(monitor, 1, 3)

	function onclick(x, y)
		local targets = getFrequencies(tpr, frequency)
		if NAMELIST_OFFSET < y and y <= #targets + NAMELIST_OFFSET then
			local tg = targets[y - NAMELIST_OFFSET].key
			local selected = tpr.hasFrequency()
			selected = selected and tpr.getFrequency()
			if not selected or selected.key ~= tg then
				monitor.setTextColor(colors.yellow)
				termUpdateAt(monitor, 1, 3, 'Switching...')
				tpr.setFrequency(tg)
				monitor.setTextColor(colors.yellow)
				termUpdateAt(monitor, 1, 3, 'Trying lookup hoster...')
				local id = rednet.lookup('teleporter', getFrequencyHostname(tg))
				if id then
					monitor.setTextColor(colors.yellow)
					termUpdateAt(monitor, 1, 3, 'Querying remote teleporter...')
					rednet.send(id, frequency, 'teleporter-query')
					local src, reply = waiting_reply(id, 'teleporter-query-reply', 3)
					if src then
						if reply == 'busy' then
							monitor.setTextColor(colors.red)
							termUpdateAt(monitor, 1, 3, 'Remote is BUZY')
						elseif reply == 'ok' then
							monitor.setTextColor(colors.green)
							termUpdateAt(monitor, 1, 3, 'Remote synced')
						elseif startswith(reply, 'error:') then
							monitor.setTextColor(colors.red)
							termUpdateAt(monitor, 1, 3, reply:sub(7))
						end
					else
						monitor.setTextColor(colors.red)
						termUpdateAt(monitor, 1, 3, "Cannot connect to remote port")
					end
					sleep(0.5)
				end
				termUpdateAt(monitor, 1, 3)
			end
		end
	end

	parallel.waitForAny(function()
		while true do
			update()
			sleep(0.5)
		end
	end, function()
		while true do
			local _, sender, msg, protocol = os.pullEvent('rednet_message')
			if protocol == 'teleporter-query' then
				monitor.setTextColor(colors.yellow)
				termUpdateAt(monitor, 1, 3, string.format('Sync with [%s]...', msg))
				local reply
				local ok, err = pcall(tpr.setFrequency, frequency)
				if ok then
					reply = 'ok'
				else
					reply = string.format('error:%s', err)
				end
				rednet.send(sender, reply, 'teleporter-query-reply')
			end
		end
	end, function()
		while true do
			if monitor == term then
				local event, p1, p2, p3 = os.pullEvent('mouse_click')
				onclick(p2, p3)
			else
				local event, p1, p2, p3 = os.pullEvent('monitor_touch')
				if p1 == monitor_name then
					onclick(p2, p3)
				end
			end
		end
	end)
end

main({...})
