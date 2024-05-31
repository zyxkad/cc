-- Farmer's Delight Rich Soil autocraft controller
-- by zyxkad@gmail.com

local peripheralHub = assert(peripheral.find('peripheral_hub'))
local inventories = {peripheral.find('inventory')}

local function pollEvents()
	local event, p1, p2, p3 = os.pullEvent()
	if event == 'rednet_message' then
		local sender, message, protocol = p1, p2, p3
		if protocol == 'soil-processor' then
			if type(message) == 'table' then
				print(sender, message.level, message.startAt, message.passed)
			end
		end
	end
end

local function update()
end

local function render(monitor)
end

function main(args)
	local monitorSide = args[1]
	local monitor = nil
	if monitorSide then
		monitor = assert(peripheral.find(monitorSide))
	end
	if not monitor then
		monitor = term
	end

	rednet.open(peripheral.getName(peripheralHub))

	parallel.waitForAny(function()
		while true do
			pollEvents()
		end
	end,
	function()
		while true do
			update()
			sleep(0.1)
		end
	end,
	function()
		if monitor.setTextScale then
			monitor.setTextScale(1)
		end
		monitor.clear()
		while true do
			render(monitor)
			sleep(0.1)
		end
	end)
end

main({...})
