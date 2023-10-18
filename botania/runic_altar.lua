-- Botania Runic Altar Autocrafting
-- by zyxkad@gmail.com

local core = assert(peripheral.find('weakAutomata'), 'No automata core installed')
local wandId = 'botania:twig_wand'

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

local function searchNonEmpty()
	for i = 1, 16 do
		local detail = turtle.getItemDetail(i)
		if detail ~= nil and detail.name ~= wandId then
			return i
		end
	end
	return nil
end

local function searchAndDropAll()
	local count = 0
	while count < 10 do -- wait for 1s
		local i = searchNonEmpty()
		if i then
			turtle.select(i)
			turtle.drop()
			count = 0
		else
			count = count + 1
			sleep(0.1)
		end
	end
end

local function craft()
	print('Crafting ...')
	searchAndDropAll()
	repeat sleep(0.2) until redstone.getInput('right')
	redstone.setOutput('top', true)
	sleep(1)
	redstone.setOutput('top', false)
	print('Finding '..wandId)
	doUntil(function() return selectItem(wandId) end)
	doUntil(function() return pcall(core.useOnBlock) end)
	print('Done!')
end

function main()
	while true do
		if searchNonEmpty() then
			craft()
		end
		-- we have to wait the cooldown for the runic altar
		sleep(3)
	end
end

main()
