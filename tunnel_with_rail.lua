-- turtle tunnel with placing rail
-- by zyxkad@gmail.com

local railId = 'create:track'

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

local function digLayer()
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.turnRight)
	doUntil(turtle.turnRight)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(function() return not turtle.detectDown() or turtle.digDown() end)
	doUntil(turtle.down)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.turnLeft)
	doUntil(turtle.turnLeft)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.up)
	doUntil(turtle.turnRight)
	doUntil(function() return selectItem(railId) and turtle.placeDown() end)
	doUntil(function() return not turtle.detectUp() or turtle.digUp() end)
	doUntil(turtle.up)
	doUntil(turtle.turnLeft)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.turnRight)
	doUntil(turtle.turnRight)
	doUntil(function() return not turtle.detect() or turtle.dig() end)
	doUntil(turtle.down)
	doUntil(turtle.turnLeft)
end

function main()
	local leng = tonumber(arg[1])
	if not leng then
		print('Please pass an vaild integer')
		return
	end
	local _, y = term.getCursorPos()
	for i = 1, leng do
		term.setCursorPos(1, y)
		term.clearLine()
		term.write(string.format('Tunneling %d / %d ...', i, leng))
		digLayer()
	end
	print()
	print('Done')
end

main()
