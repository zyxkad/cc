-- Teleporter manger for Mekanism
-- by zyxkad@gmail.com

if not parallel then
	error('Need parallel API')
end

local NAMELIST_OFFSET = 4

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function gamedate(blink)
	local ms = os.epoch('ingame')
	local sec = math.floor(ms / 1000)
	local min = math.floor(sec / 60)
	local hour = math.floor(min / 60)
	local days = math.floor(hour / 24)
	local fmt = "Day %d %02d:%02d"
	if blink and math.floor(os.clock()) % 2 == 0 then
		fmt = "Day %d %02d %02d"
	end
	return string.format(fmt, days, hour % 24, min % 60)
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

local function termUpdateAt(t, x, y, str)
	t.setCursorPos(x, y)
	t.clearLine()
	if str then
		t.write(str)
	end
end

local function termWriteCenter(t, y, str)
	if type(y) == 'string' then
		y, str = nil, y
	end
	local mWidth, _ = t.getSize()
	if not y then
		_, y = t.getCursorPos()
	end
	t.setCursorPos(mWidth / 2 - #str / 2, y)
	t.write(str)
end

local function termUpdateAtCenter(t, y, str)
	t.setCursorPos(1, y)
	t.clearLine()
	termWriteCenter(t, y, str)
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

	local curPage = 1
	local maxPage = 1
	local eachPage = 0

	function update()
		local energy, maxEnergy = tpr.getEnergy(), tpr.getMaxEnergy()
		local targets = getFrequencies(tpr, frequency)
		local selected = tpr.hasFrequency() and tpr.getFrequency()
		local status = tpr.getStatus()
		local mWidth, mHeight = monitor.getSize()
		if not mWidth then
			printError('Monitor detached')
			sleep(3)
			return false
		end

		eachPage = (mHeight - NAMELIST_OFFSET)
		if eachPage <= 0 then
			printError(string.format('Monitor too small, need at least %d lines', NAMELIST_OFFSET + 1))
			sleep(10)
			return false
		end

		if targets then
			maxPage = math.ceil(#targets / eachPage)
			if curPage > maxPage then
				curPage = maxPage
			end
		else
			curPage = 1
			maxPage = 1
		end

		monitor.setTextColor(colors.black)
		monitor.setBackgroundColor(colors.lightGray)
		termUpdateAt(monitor, 3, 1, gamedate(true))
		termUpdateAt(monitor, 1, 2, string.format("Energy: %d / %d", energy, maxEnergy))
		monitor.setBackgroundColor(colors.black)
		monitor.setTextColor(colors.white)
		termUpdateAtCenter(monitor, 3, string.format('Page %d / %d', curPage, maxPage))
		monitor.setTextColor(colors.purple)
		monitor.setCursorPos(1, 3)
		monitor.write('[PREV]')
		monitor.setTextColor(colors.lightBlue)
		monitor.setCursorPos(mWidth - 5, 3)
		monitor.write('[NEXT]')
		termUpdateAt(monitor, 1, 4)
		if targets then
			for i = 1, eachPage do
				monitor.setCursorPos(1, i + NAMELIST_OFFSET)
				local ind = (curPage - 1) * eachPage + i
				if ind > #targets then
					monitor.clearLine()
				else
					local t = targets[ind]
					if selected and t.key == selected.key then
						monitor.setTextColor(colors.black)
						monitor.setBackgroundColor(colors.lightGray)
						monitor.clearLine()
						monitor.write(string.format("%d. %s", ind, t.key))

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
						monitor.write(string.format("%d. %s", ind, t.key))
					end
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
		local mWidth, mHeight = monitor.getSize()
		local targets = getFrequencies(tpr, frequency)
		if y > NAMELIST_OFFSET then
			local ind = (curPage - 1) * eachPage + (y - NAMELIST_OFFSET)
			if ind <= #targets then
				local tg = targets[ind].key
				local selected = tpr.hasFrequency()
				selected = selected and tpr.getFrequency()
				if not selected or selected.key ~= tg then
					monitor.setTextColor(colors.yellow)
					termUpdateAt(monitor, 1, 3, 'Switching...')
					tpr.setFrequency(tg)
				end
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
		elseif y == 3 then
			if 1 <= x and x <= 6 then -- click [PREV]
				if curPage > 1 then
					curPage = curPage - 1
				end
			elseif mWidth - 5 <= x and x <= mWidth then -- click [NEXT]
				if curPage < maxPage then
					curPage = curPage + 1
				end
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
