-- Farmer's Delight Rich Soil autocraft
-- by zyxkad@gmail.com

local compostId = 'farmersdelight:organic_compost'

local peripheralHub = assert(peripheral.find('peripheral_hub'))
local localName = peripheralHub.getNameLocal()
local inventories = {peripheral.find('inventory')}

local function selectItem(item)
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail and detail.name == item then
			turtle.select(i)
			return true
		end
	end
	return false
end

local function foundNotItem(item)
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail and detail.name ~= item then
			return i
		end
	end
	return nil
end

function main()
	rednet.open(peripheral.getName(peripheralHub))

	local lastLevel = nil
	local lastTime = 0
	local startTime = 0
	while true do
		local ok, block = turtle.inspect()
		if ok then
			if block.name == compostId then
				local level = block.state.composting
				if lastLevel ~= level then
					local now = os.clock()
					local passed = now - lastTime
					print(level, passed, now - startTime)
					rednet.broadcast({
						startAt = startTime,
						passed = passed,
						level = level,
					}, 'soil-processor')
					lastLevel = level
					lastTime = now
				end
			else
				turtle.dig()
				local slot = foundNotItem()
				if slot then
					local remain = turtle.getItemCount(slot)
					for _, inv in ipairs(inventories) do
						if remain <= 0 then
							break
						end
						remain = remain - inv.pullItems(localName, slot)
					end
				end
				ok = false
			end
		end
		if not ok then
			if not selectItem(compostId) then
				local found = false
				for _, inv in ipairs(inventories) do
					for slot, item in pairs(inv.list()) do
						if item.name == compostId then
							inv.pushItems(localName, slot, 1)
							found = true
							break
						end
					end
					if found then
						break
					end
				end
			end
			if selectItem(compostId) then
				turtle.place()
				lastLevel = 0
				startTime = os.epoch('ingame')
				lastTime = os.clock()
			end
		end
		sleep(1 - (os.clock() * 20 % 20 / 20))
	end
end

main({...})
