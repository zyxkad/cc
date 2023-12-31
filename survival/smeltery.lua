-- Tconstruct Smeltery Controller
-- by zyxkad@gmail.com

local drainName = 'tconstruct:drain_0'
local basinName = 'tconstruct:basin_0'
local monitorName = 'monitor_1'

local drain = peripheral.wrap(drainName)
local basin = peripheral.wrap(basinName)
local monitor = peripheral.wrap(monitorName)

local fluids = {}

local exporting = nil
local exportLocked = false
local exportLockDeadline = nil
local exportPulled = false

local function render()
	monitor.setTextScale(0.5)

	while true do
		local width, height = monitor.getSize()
		monitor.setBackgroundColor(colors.black)
		monitor.clear()

		monitor.setTextColor(colors.black)
		monitor.setBackgroundColor(colors.lightGray)
		monitor.setCursorPos(1, 1)
		monitor.clearLine()
		if not exporting then
			monitor.write(' Click to export fluid as block')
		elseif exportLocked then
			monitor.write(' Click to stop export ' .. exporting:gsub('.+:', ''))
		else
			monitor.write(' Click this bar to lock export')
		end
		monitor.setTextColor(colors.white)
		monitor.setBackgroundColor(colors.black)

		local y = 2
		for _, tank in ipairs(fluids) do
			monitor.setCursorPos(1, y)
			if tank.name == exporting then
				monitor.setTextColor(colors.orange)
			elseif tank.amount >= 1000 then
				monitor.setTextColor(colors.green)
			else
				monitor.setTextColor(colors.lightGray)
			end
			monitor.write(tank.name:gsub('.+:', ''))
			local b = string.format('%.2fB', tank.amount / 1000)
			monitor.setCursorPos(width - #b + 1, y)
			monitor.write(b)
			y = y + 1
		end
		sleep(0.1)
	end
end

local function pullEvent()
	while true do
		local event, p1, p2, p3 = os.pullEvent()
		if event == 'monitor_touch' and p1 == monitorName then
			local x, y = p2, p3
			if y == 1 then
				if exporting then
					if exportLocked then
						exporting = nil
					else
						exportLocked = true
					end
				end
			elseif y >= 2 and y < 2 + #fluids then
				local fluid = fluids[y - 1]
				if fluid.amount >= 1000 then
					exporting = fluid.name
					exportLocked = false
					exportLockDeadline = os.clock() + 3
					exportPolled = false
				end
			end
		end
	end
end

local function pollExport()
	while true do
		local tanks = drain.tanks()
		table.sort(tanks, function(a, b) return a.amount > b.amount end)
		fluids = tanks

		if exporting then
			for _, fluid in pairs(fluids) do
				if fluid.name == exporting then
					if not exportLocked and exportPolled then
						if os.clock() > exportLockDeadline then
							exporting = nil
						end
					elseif fluid.amount >= 1000 then
						basin.pullFluid(drainName, 1000, exporting)
						exportPolled = true
					end
					break
				end
			end
		end
		sleep(0)
	end
end

function main()
	parallel.waitForAny(pullEvent, render, pollExport)
end

main()
