-- Botania Runic Altar Autocrafting (Upper part)
-- by zyxkad@gmail.com

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
		local detail = turtle.getItemDetail(i)
		if detail and detail.name == item then
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
			return i, detail.name
		end
	end
	return nil
end

local function searchAndDropAll()
	local count = 0
	local livingRock = nil
	while count < 10 or not livingRock do -- wait for 1s
		local i, name = searchNonEmpty()
		if i then
			if name == 'botania:livingrock' then
				if not livingRock then
					livingRock = i
					count = 0
				else
					count = count + 1
					sleep(0.1)
				end
			else
				turtle.select(i)
				turtle.drop()
				count = 0
			end
		else
			count = count + 1
			sleep(0.1)
		end
	end
	return livingRock
end

local function craft()
	redstone.setOutput('front', true)
	print('Dropping materials ...')
	local livingRock = searchAndDropAll()
	print('Waiting for alter ready ...')
	repeat sleep(0.2) until redstone.getInput('right')
	turtle.select(livingRock)
	turtle.drop()
	sleep(1)
	redstone.setOutput('front', false)
	sleep(0.1)
	-- trigger wand
	print('Triggering wand ...')
	redstone.setOutput('bottom', true)
	repeat sleep(0.1) until redstone.getInput('bottom')
	redstone.setOutput('bottom', false)
	print('Done!')
end

function main()
	while true do
		if searchNonEmpty() then
			craft()
			-- we have to wait the cooldown for the runic altar
			sleep(5)
		else
			sleep(0.1)
		end
	end
end

main()
