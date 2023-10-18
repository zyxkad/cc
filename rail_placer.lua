-- Rail placer
-- by zyxkad@gmail.com

local rails = {
	'minecraft:detector_rail',
	'minecraft:powered_rail',
}

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

local function doUntil(c, max)
	local i = 1
	local res
	while true do
		res = {c()}
		if res[1] or (max and i >= max) then
			break
		end
		sleep(0)
		i = i + 1
	end
	return table.unpack(res)
end

function main()
	while true do
		for _, v in ipairs(rails) do
			doUntil(turtle.forward)
			doUntil(function() return selectItem(v) end)
			doUntil(turtle.placeDown)
		end
	end
end

main()
