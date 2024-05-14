-- Large storage placer
-- by zyxkad@gmail.com

local chestId = 'minecraft:chest'
local modemId = 'computercraft:wired_modem_full'

local automata = assert(peripheral.find('weakAutomata'))

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

local function doUntil(c, max)
	if c == nil then
		error('the first arguemnt is not a function')
	end
	local i = 1
	local res
	while true do
		res = {c()}
		if res[1] or (max and i >= max) then
			break
		end
		i = i + 1
		sleep(0)
	end
	return table.unpack(res)
end

local function placeBlockDown(item)
	while not selectItem(item) do sleep(1) end
	if not turtle.detectDown() then
		doUntil(turtle.placeDown)
	end
end

local function placeChestCol()
	for i = 3, 13 do
		placeBlockDown(chestId)
		doUntil(turtle.back)
	end
	placeBlockDown(chestId)
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	for i = 3, 13 do
		placeBlockDown(chestId)
		doUntil(turtle.forward)
	end
	placeBlockDown(chestId)
end

local function waitForCooldown(oper)
	while true do
		local cd = automata.getOperationCooldown(oper)
		if cd <= 0 then
			break
		end
		print('waiting for', math.floor(cd / 1000), 's')
		sleep(cd / 1000)
	end
end

local function discardAllEvents()
	local count = 0
	local timer = os.startTimer(0.5)
	while true do
		local event, id = os.pullEvent()
		if event == 'timer' and id == timer then
			print('discarded', count, 'events')
			return
		else
			count = count + 1
			os.cancelTimer(timer)
			timer = os.startTimer(0.5)
		end
	end
end

local function noCareAction(action, ...)
	local thr = coroutine.create(action)
	coroutine.resume(thr, ...)
	discardAllEvents()
end

local function placeModemCol()
	noCareAction(turtle.down)
	for i = 2, 13 do
		-- print('DBUG: moving back')
		noCareAction(turtle.back)
		-- print('DBUG: selecting modem')
		while not selectItem(modemId) do sleep(0.1) end
		-- print('DBUG: placing modem')
		noCareAction(turtle.place)
		-- print('DBUG: activing modem')
		waitForCooldown('useOnBlock')
		-- print('DBUG: using on block')
		automata.useOnBlock()
		discardAllEvents()
	end
	noCareAction(turtle.up)
	for i = 2, 13 do
		noCareAction(turtle.forward)
	end
end

local function placeLayer()
	placeChestCol()
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	placeModemCol()
	noCareAction(turtle.turnRight)
	noCareAction(turtle.forward)
	noCareAction(turtle.turnLeft)
	placeChestCol()
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	placeChestCol()
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	placeModemCol()
	noCareAction(turtle.turnRight)
	noCareAction(turtle.forward)
	noCareAction(turtle.turnLeft)
	placeChestCol()
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	placeChestCol()
	doUntil(turtle.turnRight)
	doUntil(turtle.forward)
	doUntil(turtle.turnLeft)
	placeModemCol()
	noCareAction(turtle.turnLeft)
	for i = 1, 12 do
		noCareAction(turtle.forward)
	end
	noCareAction(turtle.turnRight)
	doUntil(turtle.up)
end

function main(args)
	num = tonumber(args[1]) or 1
	for i = 1, num do
		placeLayer()
	end
end

main({...})
