-- Fission Reactor Control System (FRCS)
-- by zyxkad@gmail.com

if not redstone then
	error('Need redstone API')
end

if not parallel then
	error('Need parallel API')
end

---BEGIN default configs---
local configPath = 'reactor.cfg'

local cfg = {
	defaultEnabled = false,
	normalBurnRate = 1.0,
	overloadBurnRate = 0, -- 0 means the max burn rate
	smoothBurn = 1,
	fuelIncreaseRate = 0.5,
	alarmThreshold = 0.55,
	safeCooldownTime = 1.5,
	forceShutThreshold = 0.2,
	restartThreshold = 0.5,
	maxHeatedCoolant = 1.01,
	maxNuclearWaste = 0.9,
	maxTemperature = 850, -- 850 °C
}
---END default configs---

local ok, config_loader = pcall(require, 'config')
if ok then
	if fs.exists(configPath) then
		cfg = config_loader.load(configPath, cfg)
	else
		printError(('Config file not exists, saving default config at "%s"'):format(configPath))
		config_loader.save(configPath, cfg)
	end
else
	printError('module "config.lua" not found')
end

---BEGIN status---

enabled = cfg.defaultEnabled
statusBtn = ''
overloading = false

systemStart = os.clock()

lastUpdate = 0.0
reactorRunning = false
temperature = 0.0
fuelAmount = 0
fuelFilled = 0.0
fuelRate = 0.0
coolant = 0.0
coolantRate = 0.0
heatedCoolant = 0.0
nuclearWaste = 0
nuclearWasteFilled = 0.0
damage = 0.0

---END status---

local function formatSec2hours(sec, blink)
	local sec2 = math.floor(sec)
	local min = math.floor(sec / 60)
	local hour = math.floor(min / 60)
	local fmt = "%02d:%02d:%02d"
	if blink and sec % 1 < 0.5 then
		fmt = "%02d %02d %02d"
	end
	return string.format(fmt, hour, min % 60, sec2 % 60)
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

local function termUpdateAt(t, x, y, data)
	t.setCursorPos(x, y)
	t.clearLine()
	if data then
		t.write(data)
	end
end

local function pullMonitorClickEvent(monitor)
	if type(monitor) == 'table' then
		monitor = peripheral.getName(monitor)
	end
	local name, x, y
	repeat
		_, name, x, y = os.pullEvent('monitor_touch')
	until not monitor or name == monitor
	return x, y, name
end

local function monitorListenClick(monitor)
	local x, y = pullMonitorClickEvent(monitor)
	local mWidth, mHeight = monitor.getSize()
	if y == 2 then
		if mWidth - #statusBtn <= x and x < mWidth then
			enabled = not enabled
		elseif x == math.floor(mWidth / 2) - 1 then
			if cfg.normalBurnRate > 1 then
				cfg.normalBurnRate = cfg.normalBurnRate - 1
			end
		elseif x == math.floor(mWidth / 2) + 1 then
			cfg.normalBurnRate = cfg.normalBurnRate + 1
		end
	elseif y == 3 then
		-- TODO: click each data to switch between short and full information
	end
end

local function onUpdateData(td, reactor, overloadIn_side)
	reactorRunning = reactor.getStatus()
	temperature = reactor.getTemperature()
	local lastFuelAmount = fuelAmount
	fuelAmount = reactor.getFuel().amount
	fuelFilled = reactor.getFuelFilledPercentage()
	fuelRate = reactor.getActualBurnRate() -- per tick
	local lastCoolant = coolant
	coolant = reactor.getCoolantFilledPercentage()
	coolantRate = (coolant - lastCoolant) / td
	heatedCoolant = reactor.getHeatedCoolantFilledPercentage()
	nuclearWaste = reactor.getWaste().amount
	nuclearWasteFilled = reactor.getWasteFilledPercentage()
	damage = reactor.getDamagePercent()
	if overloadIn_side then
		overloading = redstone.getInput(overloadIn_side)
	end
end

local function onTick(reactor, alarm_side)
	local shouldRun = enabled and
		damage == 0 and
		coolant > cfg.forceShutThreshold and
		(reactorRunning or coolant >= cfg.restartThreshold) and
		coolant + coolantRate * cfg.safeCooldownTime > 0.05 and
		heatedCoolant < cfg.maxHeatedCoolant and
		nuclearWasteFilled < cfg.maxNuclearWaste and
		temperature - 273 < cfg.maxTemperature
	local alarm = false
	if reactorRunning ~= shouldRun then
		if shouldRun then
			local ok, err = pcall(reactor.activate)
			if not ok then
				alarm = true
				printError("Can't activate reactor:", err)
			end
		else
			local ok, err = pcall(reactor.scram)
			if not ok then
				alarm = true
				printError("Can't stop reactor:", err)
			end
		end
	end
	local burnRate = 0
	if shouldRun then
		if overloading then
			if cfg.overloadBurnRate > 0 then
				burnRate = cfg.overloadBurnRate
			else
				burnRate = reactor.getMaxBurnRate()
			end
		else
			burnRate = cfg.normalBurnRate
		end
	end
	if cfg.smoothBurn == 1 or (cfg.smoothBurn == 2 and overloading) then
		local nextRate = fuelRate
		if coolantRate >= 0 then
			if cfg.smoothBurn == 2 and nextRate < cfg.normalBurnRate then
				nextRate = cfg.normalBurnRate
			elseif nextRate + cfg.fuelIncreaseRate > burnRate then
				nextRate = burnRate
			else
				nextRate = nextRate + cfg.fuelIncreaseRate
			end
		end
		reactor.setBurnRate(nextRate)
	else
		reactor.setBurnRate(burnRate)
	end
	if coolant <= cfg.alarmThreshold then
		alarm = true
	end
	if alarm_side then
		redstone.setOutput(alarm_side, alarm)
	end
end

_circleStr = {'-', '\\', '|', '/'}

local function updateMonitor(monitor)
	local now = os.clock()
	local mWidth, mHeight = monitor.getSize()
	--- update header
	monitor.setBackgroundColor(colors.lightGray)
	monitor.setTextColor(colors.black)
	termUpdateAt(monitor, 3, 1, 'FRCS running '..formatSec2hours(now - systemStart, true))
	--- update status
	local statusStr, statusColor
	local stars = nil
	if reactorRunning then
		statusStr, statusColor = 'REACTING', colors.orange
		local i = math.floor(now * 4)
		stars = string.rep(_circleStr[i % 4 + 1], #statusStr + 2)
	elseif enabled then
		statusStr, statusColor = 'COOLING', colors.blue
		stars = string.rep(math.floor(now * 1.5) % 2 and '+' or '*', #statusStr + 2)
	else
		statusStr, statusColor = 'DISABLED', colors.red
		stars = string.rep(math.floor(now) % 2 and '@' or '#', #statusStr + 2)
	end
	monitor.setBackgroundColor(colors.black)
	monitor.setTextColor(colors.yellow)
	termUpdateAt(monitor, 2, 2, stars)
	monitor.setTextColor(statusColor)
	monitor.setCursorPos(3, 2)
	monitor.write(statusStr)
	monitor.setTextColor(colors.white)
	monitor.setCursorPos(math.floor(mWidth / 2) - 1, 2)
	monitor.write('-/+')
	if enabled then
		statusBtn, statusColor = '[SCRAM] ', colors.red
	else
		statusBtn, statusColor = '[ENABLE]', colors.green
	end
	monitor.setTextColor(statusColor)
	monitor.setCursorPos(mWidth - #statusBtn, 2)
	monitor.write(statusBtn)
	--- update temperature
	monitor.setTextColor(colors.yellow)
	termUpdateAt(monitor, 1, 3, '   Temp')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	local tempC = temperature - 273 -- use °C insteat of K
	if tempC >= cfg.maxTemperature then
		monitor.setTextColor(colors.red)
	elseif tempC >= 500 then
		monitor.setTextColor(colors.orange)
	elseif tempC >= 250 then
		monitor.setTextColor(colors.yellow)
	elseif tempC >= 100 then
		monitor.setTextColor(colors.white)
	else
		monitor.setTextColor(colors.blue)
	end
	monitor.write(string.format('%.1f°C', tempC))
	--- update fuel
	monitor.setTextColor(colors.lightGray)
	termUpdateAt(monitor, 1, 4, '   Fuel')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	monitor.write(string.format('%dmB [%.2fmB/t]', fuelAmount, fuelRate))
	--- update coolant
	monitor.setTextColor(colors.cyan)
	termUpdateAt(monitor, 1, 5, 'Coolant')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	if coolant <= cfg.forceShutThreshold then
		monitor.setTextColor(colors.red)
	elseif coolant <= cfg.restartThreshold then
		monitor.setTextColor(colors.yellow)
	else
		monitor.setTextColor(colors.blue)
	end
	monitor.write(string.format('%.1f%%', coolant * 100))
	monitor.write(string.format(' [%+3.2f/s]', coolantRate * 100))
	--- update heated coolant
	monitor.setTextColor(colors.orange)
	termUpdateAt(monitor, 1, 6, ' Heated')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	monitor.write(string.format('%.1f%%', heatedCoolant * 100))
	--- update waste
	monitor.setTextColor(colors.brown)
	termUpdateAt(monitor, 1, 7, '  Waste')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	monitor.write(string.format('%.1f%%', nuclearWasteFilled * 100))
	--- update damage
	monitor.setTextColor(colors.white)
	termUpdateAt(monitor, 1, 8, ' Damage')
	monitor.setTextColor(colors.white)
	monitor.write(' | ')
	if damage > 0 then
		monitor.setTextColor(colors.red)
	else
		monitor.setTextColor(colors.white)
	end
	monitor.write(string.format('%.1f%%', damage))
end

local function main(args)
	local reactor_name = args[1]
	if not reactor_name then
		printError('You must give a reactor name')
		return
	end
	local monitor_name = args[2]
	if not monitor_name then
		printError('You must give a monitor name for display reactor status')
		return
	end
	local alarm_side = args[3]
	if not alarm_side or #alarm_side == 0 then
		alarm_side = false
	end
	local overloadIn_side = args[4]
	if not overloadIn_side or #overloadIn_side == 0 then
		overloadIn_side = false
	elseif not alarm_side then
		printError('You must give an alarm when you want to use overload input')
		return
	end
	local reactor = peripheral.wrap(reactor_name)
	if not reactor then
		printError(string.format('Cannot find peripheral %s', reactor_name))
		return
	elseif peripheral.getType(reactor) ~= 'fissionReactorLogicAdapter' then
		printError(string.format('%s is not a reactor', reactor_name))
		return
	end
	local monitor = peripheral.wrap(monitor_name)
	if not monitor then
		printError(string.format('Cannot find peripheral %s', monitor_name))
		return
	elseif peripheral.getType(monitor) ~= 'monitor' then
		printError(string.format('%s is not a monitor', monitor_name))
		return
	end
	monitor.setBackgroundColor(colors.black)
	monitor.setTextColor(colors.white)
	monitor.clear()

	parallel.waitForAny(function()
		local lastTick = os.clock()
		while true do
			local now = os.clock()
			onUpdateData(now - lastTick, reactor, overloadIn_side)
			lastTick = now
			onTick(reactor, alarm_side)
			sleep(0)
		end
	end, function()
		while true do
			updateMonitor(monitor)
			sleep(0.1)
		end
	end, function()
		while true do
			monitorListenClick(monitor)
		end
	end)
end

main({...})
