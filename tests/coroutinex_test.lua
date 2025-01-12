
local cox = require('coroutinex')

print('COX version:', cox.VERSION)

local co_main = cox.main
local co_run = cox.run
local yield = cox.yield
local await = cox.await
local awaitAny = cox.awaitAny
local awaitRace = cox.awaitRace

local function loopPrint(prefix, to, interval)
	local i = 0
	interval = interval or 0.25
	while true do
		i = i + 1
		print('loop ['..prefix..'] '..i)
		if i == to then
			break
		end
		sleep(interval)
	end
	return prefix
end

print('Start...')
co_main(function()
	local thrs, ret, err, start, amount, maxTicks, timerId

	print()
	print('==> testing await...')
	ret = {await(
		function() return loopPrint('await_1', 5) end,
		function() return loopPrint('await_2', 3) end,
		function() sleep(3) return 'sleep(3)' end
	)}
	print('await return: '..textutils.serialise(ret))
	sleep(0.5)

	print()
	print('==> testing await with error...')
	ret = {pcall(await,
		function() return loopPrint('await_1', 5) end,
		function() return loopPrint('await_2', 3) end,
		function() error('break', 0) end
	)}
	assert(not ret[1])
	err = ret[2]
	assert(type(err) == 'table' and err.index == 3 and err.err == 'break')
	print('await returned')
	sleep(1.5)

	print()
	print('==> testing awaitAny...')
	ret = {awaitAny(
		function() return loopPrint('awaitAny_1', 5) end,
		function() return loopPrint('awaitAny_2', 3) end,
		function() sleep(3) return 'sleep(3)' end
	)}
	print('awaitAny return: '..textutils.serialise(ret))
	sleep(0.5)

	print()
	print('==> testing awaitAny with slow error...')
	ret = {awaitAny(
		function() return loopPrint('awaitAny_3', 5) end,
		function() return loopPrint('awaitAny_4', 3) end,
		function() sleep(3) error('break', 0) end
	)}
	print('awaitAny return: '..textutils.serialise(ret))
	sleep(0.5)

	print()
	print('==> testing awaitAny with fast error...')
	ret = {awaitAny(
		function() return loopPrint('awaitAny_5', 5) end,
		function() return loopPrint('awaitAny_6', 3) end,
		function() error('break', 0) end
	)}
	print('awaitAny return: '..textutils.serialise(ret))
	sleep(0.5)

	print()
	print('==> testing awaitAny with all error...')
	ret = {pcall(awaitAny,
		function() loopPrint('awaitAny_1', 5) error('awaitAny_1', 0) end,
		function() loopPrint('awaitAny_2', 3) error('awaitAny_2', 0) end,
		function() error('break', 0) end
	)}
	assert(not ret[1])
	err = ret[2]
	assert(type(err) == 'table' and #(err.errs) == 3)
	assert(err.errs[1] == 'awaitAny_1' and err.errs[2] == 'awaitAny_2' and err.errs[3] == 'break')
	print('awaitAny returned')
	sleep(0.5)

	amount = 500

	print()
	print('==> testing massive os timer stop at same time...')
	thrs = {}
	for i = 1, amount do
		thrs[i] = co_run(function() sleep(0.05) end)
	end
	start = os.epoch('utc')
	await(table.unpack(thrs))
	print('used time:', os.epoch('utc') - start)
	sleep(0.5)

	print()
	print('==> testing massive os timer stop at different time...')
	thrs = {}
	maxTicks = 10
	for i = 1, amount * maxTicks do
		thrs[i] = co_run(function() sleep(0.05 + 0.05 * i / amount) end)
	end
	sleep(0.05)
	start = os.epoch('utc')
	print('ideal delay:', maxTicks * 0.05 * 1000)
	await(table.unpack(thrs))
	print('used time:', os.epoch('utc') - start)
	sleep(0.5)

	print()
	print('==> testing registerTimer...')
	co_run(function()
		timerId = os.startTimer(0.2)
	end)
	await(function()
		local timeoutId = os.startTimer(1)
		cox.registerTimer(timerId)
		while true do
			local event, id = os.pullEvent()
			if event == 'timer' then
				if id == timerId then
					print('timer triggered!')
					return true
				elseif id == timeoutId then
					error('timer did not trigger')
				end
			end
		end
	end, function()
		local timeoutId = os.startTimer(1)
		while true do
			local event, id = os.pullEvent()
			if event == 'timer' then
				if id == timerId then
					error('timer unexpectedly triggered')
				elseif id == timeoutId then
					print('timer safely ignored')
					return true
				end
			end
		end
	end)
	sleep(0.5)
end)
print('End...')
