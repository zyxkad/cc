-- RS external storage placer
-- by zyxkad@gmail.com

local cableId = 'refinedstorage:cable'
local extstorageId = 'refinedstorage:external_storage'

local function doUntil(c, failed, max)
	if type(failed) == 'number' then
		failed, max = nil, failed
	end
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
		sleep(0)
	until res[1] or (max and i >= max) or (failed and failed(table.unpack(res)))
	return table.unpack(res)
end

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


for i = 1, 32 do
	doUntil(turtle.turnRight)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(function() return selectItem(extstorageId) end)
	doUntil(turtle.place)
	doUntil(turtle.turnLeft)
	doUntil(turtle.forward)
	doUntil(turtle.turnRight)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(function() return selectItem(cableId) end)
	doUntil(turtle.place)
	doUntil(turtle.turnLeft)
	doUntil(turtle.forward)
end

for i = 1, 32 * 2 do
	doUntil(turtle.back)
end

doUntil(turtle.up)
doUntil(turtle.up)
