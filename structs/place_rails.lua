

local itemId = "create:track"

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

while true do
	doUntil(function() return selectItem(itemId) end)
	doUntil(turtle.placeDown)
	doUntil(turtle.forward)
end
