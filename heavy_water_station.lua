-- heavy water station for mekanism
-- by zyxkad@gmail.com

bridgeAccessSide = 'front'
refuelBelow = 0.5
refuelTo = 0.9

local fuelsId = {
	'minecraft:coal',
	'minecraft:coal_block',
}
local pumpId = 'mekanism:pump'
local pipeId = 'mekanism:pipe'
local waterBucketId = 'minecraft:water_bucket'
local bucketId = 'minecraft:bucket'

local function doUntil(c, failed, max)
	local i = 0
	local res
	repeat
		if i % 2 == 1 then
			sleep(0) -- yield once
		end
		i = i + 1
		res = {c()}
	until res[1] or (max and i >= max) or (failed and failed(table.unpack(res)))
	return table.unpack(res)
end

function main_turtle(args)
	local function selectItem(item)
		for i = 1, 16 do
			local detial = turtle.getItemDetail(i)
			if detial and detial.name == item then
				turtle.select(i)
				return true
			end
		end
		return false
	end
	local function cleanInventory()
		print('cleaning inventory')
		local rsBridge = peripheral.find('rsBridge')
		for i = 1, 16 do
			local item = turtle.getItemDetail(i)
			if item ~= nil then
				rsBridge.importItem(item, bridgeAccessSide)
			end
		end
	end
	local function importItem(name, count, nbt)
		local rsBridge = peripheral.find('rsBridge')
		if rsBridge == nil then
			return false, 'bridge not found'
		end
		if count == 0 then
			return true, 1
		end
		local res = rsBridge.exportItem({
			name = name,
			count = count,
			nbt = nbt,
		}, bridgeAccessSide)
		if res == 0 then
			if count == nil then
				return true, res
			end
			return false, 'item not found'
		end
		return true, res
	end
	local function refuel()
		local remain = turtle.getFuelLevel()
		if remain == 'unlimited' then
			return
		end
		local limit = turtle.getFuelLimit()
		if remain / limit < refuelBelow then
			print('refueling')
			ok = true
			while ok and turtle.getFuelLevel() / limit < refuelTo do
				ok = false
				for _, f in ipairs(fuelsId) do
					if importItem(f, 1) then
						ok = true
						if selectItem(f) then
							print('fueling', f)
							turtle.refuel()
						end
						break
					end
				end
			end
			print('Refuel done,', turtle.getFuelLevel(), 'out of', limit)
		end
	end
	local function _selectWaterBucket()
		return doUntil(function() return selectItem(waterBucketId) end)
	end
	local function fillWaterLine(length)
		if length < 3 then
			error('length must be at least 3')
		end
		doUntil(function() return selectItem(waterBucketId) end)
		doUntil(turtle.placeDown)
		doUntil(turtle.forward)
		doUntil(function() return selectItem(waterBucketId) end)
		doUntil(turtle.place)
		doUntil(function() return selectItem(bucketId) end)
		doUntil(turtle.placeDown)
		doUntil(function() return selectItem(bucketId) end)
		doUntil(turtle.placeDown)
		for i = 3, length, 2 do
			if i + 2 > length then
				doUntil(turtle.forward)
				doUntil(function() return selectItem(waterBucketId) end)
				doUntil(turtle.place)
				doUntil(function() return selectItem(bucketId) end)
				doUntil(turtle.placeDown)
				break
			end
			doUntil(turtle.forward)
			doUntil(turtle.forward)
			doUntil(function() return selectItem(waterBucketId) end)
			doUntil(turtle.place)
			doUntil(function() return selectItem(bucketId) end)
			doUntil(turtle.placeDown)
		end
		for i = 2, length do
			doUntil(turtle.back)
		end
	end

	cleanInventory()
	refuel()
	cleanInventory()
	importItem()
end

if turtle then
	main_turtle({...})
end
