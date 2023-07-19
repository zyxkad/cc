-- Digital miner monitor
-- by zyxkad@gmail.com

if not parallel then
	error('Need parallel API')
end

local DATA_OFFSET = 3
local datas = {}

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

local function getTime()
	return os.epoch('ingame') / 1000 / 60
end

local function formatTime(t)
	local min = math.floor(t)
	local hour = math.floor(min / 60)
	local days = math.floor(hour / 24)
	return string.format('%d@%02d:%02d', days, hour % 24, min % 60)
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
	t.setCursorPos(mWidth / 2 - #str / 2 + 1, y)
	t.write(str)
end

local function termUpdateAtCenter(t, y, str)
	t.setCursorPos(1, y)
	t.clearLine()
	termWriteCenter(t, y, str)
end

local function listenData()
	while true do
		local id, msg = rednet.receive('digital_miner')
		local l = datas[msg.id]
		if not l or l.i == id then
			local d = datas[msg.id]
			if msg.typ == 'pos' then
				if msg.x == msg.x then -- check not be nan
					if d then
						d.t = getTime()
						d.x = msg.x
						d.y = msg.y
						d.z = msg.z
						d.fuel = msg.fuel
					else
						d = {
							t = getTime(),
							i = id,
							id = msg.id,
							x = msg.x,
							y = msg.y,
							z = msg.z,
							fuel = msg.fuel,
							msg = 'unknown',
						}
						datas[msg.id] = d
					end
				end
			elseif msg.typ == 'mining' then
				if d then
					d.t = getTime()
					d.msg = string.format('remain=%d', msg.data)
				end
			elseif msg.typ == 'error' then
				if d then
					printError('ERR:', msg.data)
					d.msg = string.format('err=%s', msg.data)
				end
			else
				if d then
					d.msg = msg.data and string.format('%s: %s', msg.typ, msg.data) or msg.typ
				end
			end
			if d then
				local path = string.format('last_pos/%s.data', msg.id)
				local fd, err = io.open(path, 'w')
				if fd then
					fd:write(textutils.serialiseJSON(d))
					fd:close()
				else
					printError('Cannot write to file :', path, ':', err)
				end
			end
		end
	end
end

local function renderData(monitor)
	local mWidth, mHeight = monitor.getSize()

	monitor.setTextColor(colors.black)
	monitor.setBackgroundColor(colors.lightGray)
	termUpdateAtCenter(monitor, 1, 'DM v1 '..gamedate(true))

	local i = DATA_OFFSET
	monitor.setTextColor(colors.white)
	monitor.setBackgroundColor(colors.black)
	for _, d in pairs(datas) do
		termUpdateAt(monitor, 1, i, string.format(' %s | %d %d %d', d.id, d.x, d.y, d.z))
		termUpdateAt(monitor, 1, i + 1, string.format('  | %s | %s | %s', formatTime(d.t), tostring(d.fuel), d.msg))
		i = i + 2
	end
	for n = i, mHeight do
		monitor.setCursorPos(1, n)
		monitor.clearLine()
	end
end

local function loadData()
	for _, f in ipairs(fs.list('last_pos')) do
		local fd = io.open('last_pos'..'/'..f)
		if fd then
			local con = fd:read('a')
			if con then
				local d = textutils.unserialiseJSON(con)
				if d then
					d.msg = d.msg and 'o='..d.msg or 'offline'
					datas[d.id] = d
					print('loaded:', d.id)
				end
			end
		end
	end
end

function main(args)
	local monitor_name = args[1]
	local monitor
	if monitor_name then
		monitor = peripheral.wrap(monitor_name)
		if not monitor then
			printError(string.format('Cannot find peripheral %s', monitor_name))
			return
		elseif peripheral.getType(monitor) ~= 'monitor' then
			printError(string.format('%s is not a monitor', monitor_name))
			return
		end
	else
		monitor = term
	end
	monitor.setTextColor(colors.white)
	monitor.setBackgroundColor(colors.black)
	monitor.clear()
	monitor.setCursorPos(1, 1)

	peripheral.find('modem', rednet.open)
	rednet.host('miner_monitor', string.format('miner_monitor_%d', os.computerID()))

	loadData()

	parallel.waitForAny(function()
		listenData()
	end, function()
		while true do
			renderData(monitor)
			sleep(0.2)
		end
	end)
end

main({...})
