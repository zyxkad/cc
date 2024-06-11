-- GeoScanner Miner Monitor
-- by zyxkad@gmail.com

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
	local id, msg = rednet.receive('turtle_geo_miner')
	if type(msg) ~= 'table' then
		return
	end
	local l = datas[msg.name]
	if not l or l.i == id then
		local d = datas[msg.name]
		if msg.x == msg.x then -- check not be nan
			if d then
				d.t = getTime()
				d.x = msg.x
				d.y = msg.y
				d.z = msg.z
				d.fuel = msg.fuel
				d.act = msg.act
			else
				d = {
					t = getTime(),
					i = id,
					name = msg.name,
					x = msg.x,
					y = msg.y,
					z = msg.z,
					fuel = msg.fuel,
					act = msg.act,
				}
				datas[msg.name] = d
			end
		end
		if d then
			local path = string.format('last_pos/%s.dat', msg.name)
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

local function renderDataMonitor(monitor)
	local mWidth, mHeight = monitor.getSize()

	monitor.setTextColor(colors.black)
	monitor.setBackgroundColor(colors.lightGray)
	termUpdateAtCenter(monitor, 1, 'GM v1 ' .. gamedate(true))

	local i = DATA_OFFSET
	monitor.setTextColor(colors.white)
	monitor.setBackgroundColor(colors.black)
	for _, d in pairs(datas) do
		termUpdateAt(monitor, 1, i, string.format(' %s | %s %s %s', d.name, d.x, d.y, d.z))
		termUpdateAt(monitor, 1, i + 1, string.format('  | %s | %s | %s', formatTime(d.t), tostring(d.fuel), d.act))
		i = i + 2
	end
	for n = i, mHeight do
		monitor.setCursorPos(1, n)
		monitor.clearLine()
	end
end

local function renderDataPocket()
	local mWidth, mHeight = term.getSize()

	term.setTextColor(colors.black)
	term.setBackgroundColor(colors.lightGray)
	termUpdateAtCenter(term, 1, 'GM v1 ' .. gamedate(true))

	local i = DATA_OFFSET
	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	local dataList = {}
	for _, d in pairs(datas) do
		dataList[#dataList + 1] = d
	end
	table.sort(dataList, function(a, b) return a.t > b.t end)
	for _, d in ipairs(dataList) do
		termUpdateAt(term, 1, i, string.format(' - %s', d.name))
		termUpdateAt(term, 1, i + 1, string.format(' | %s %s %s', d.x, d.y, d.z))
		termUpdateAt(term, 1, i + 2, string.format(' | %s | %s', formatTime(d.t), tostring(d.fuel)))
		termUpdateAt(term, 1, i + 3, string.format(' | %s', d.act))
		i = i + 4
	end
	for n = i, mHeight do
		term.setCursorPos(1, n)
		term.clearLine()
	end
end

local function loadData()
	if fs.exists('last_pos') then
		for _, f in ipairs(fs.list('last_pos')) do
			local fd = fs.open(fs.combine('last_pos', f), 'r')
			if fd then
				local con = fd.readAll()
				if con then
					local d = textutils.unserialiseJSON(con)
					if d then
						datas[d.name] = d
						print('loaded:', d.name)
					end
				end
			end
		end
	else
		print('last_pos not exists, creating one')
		fs.makeDir('last_pos')
	end
end

function main(monitorSide)
	local renderData
	if pocket then
		renderData = renderDataPocket
	else
		local monitor
		if monitorSide then
			monitor = peripheral.wrap(monitorSide)
			if not monitor then
				printError(string.format('Cannot find peripheral %s', monitorSide))
				return
			elseif not peripheral.hasType(monitor, 'monitor') then
				printError(string.format('%s is not a monitor', monitorSide))
				return
			end
		else
			monitor = term
		end
		monitor.setTextColor(colors.white)
		monitor.setBackgroundColor(colors.black)
		monitor.clear()
		monitor.setCursorPos(1, 1)
		renderData = function()
			renderDataMonitor(monitor)
		end
	end

	peripheral.find('modem', function(m)
		return peripheral.call(m, 'isWireless') and rednet.open(m)
	end)
	rednet.host('miner_monitor', string.format('miner_monitor_%d', os.computerID()))

	loadData()

	parallel.waitForAny(function()
		while true do
			listenData()
		end
	end, function()
		while true do
			renderData()
			sleep(0.2)
		end
	end)
end

main(...)
