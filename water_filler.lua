-- Water filler
-- by zyxkad@gmail.com

local function doUntil(c, failed, max)
	local i = 0
	local res
	repeat
		i = i + 1
		res = {c()}
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

function main()
	local lastChange = os.clock()
	while true do
		local now = os.clock()
		repeat
			if not selectItem('minecraft:bucket') then
				if not selectItem('minecraft:water_bucket') then
					printError('No bucket found')
					break
				end
			else
				turtle.dropDown()
				turtle.suckDown()
				if not selectItem('minecraft:water_bucket') then
					printError('No water bucket found')
					break
				end
			end
			local ok, data = turtle.inspectUp()
			if not ok or not data.state or not data.state.level or data.state.level > 0 then
				lastChange = now
				turtle.placeUp()
			elseif lastChange + 10 < now and ok and data.name == 'minecraft:water' then
				turtle.placeUp()
				turtle.placeUp()
			end
		until true
		sleep(0.2)
	end
end

main()
