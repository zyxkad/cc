-- coroutine extra
-- by zyxkad@gmail.com

local eventCoroutineCreate = 'coroutine_create'
local eventCoroutineDone = 'coroutine_done'

local function run(fn, ...)
	assert(type(fn) == 'function', 'Argument #1(fn) must be a function')
	local event, ofn, thr = coroutine.yield('/run', fn, ...)
	assert(event == eventCoroutineCreate, 'event ~= eventCoroutineCreate')
	while ofn ~= fn do
		event, ofn, thr = coroutine.yield(eventCoroutineCreate)
		assert(event == eventCoroutineCreate, 'event ~= eventCoroutineCreate')
	end
	return thr
end

local function asleep(n)
	return run(sleep, n)
end

local function checkThreads(...)
	local threads = {...}
	for i, fn in ipairs(threads) do
		local typ = type(fn)
		if typ == 'function' then
			threads[i] = run(fn)
		elseif typ ~= 'thread' then
			error(string.format('Argument #%d is %s, expect a coroutine thread or a function',
				i, typ), 2)
		end
		threads[fn] = i
	end
	return threads
end

-- await all threads
local function await(...)
	local threads = checkThreads(...)
	local rets = {}
	local event, thr, ret
	repeat
		event, thr, ret = coroutine.yield(eventCoroutineDone)
		assert(event == eventCoroutineDone, 'event ~= eventCoroutineDone')
		local i = threads[thr]
		if i then
			rets[i] = ret
		end
	until #rets == #threads
	return table.unpack(rets)
end

-- await any threads
local function awaitAny(...)
	local threads = checkThreads(...)
	local event, thr, ret
	while true do
		event, thr, ret = coroutine.yield(eventCoroutineDone)
		assert(event == eventCoroutineDone, 'event ~= eventCoroutineDone')
		local i = threads[thr]
		if i then
			return i, ret
		end
	end
end


local function main(...)
	local routines = {}

	for i, fn in ipairs({...}) do
			if type(fn) ~= "function" then
					error(string.format('Bad argument #%d (function expected, got %s)', i, type(fn)), 2)
			end
			routines[i] = coroutine.create(fn)
	end

	local eventFilter = {}
	local eventData = {}
	while true do
		for i, r in pairs(routines) do
			if eventFilter[r] == nil or eventFilter[r] == eventData[1] then
				eventFilter[r] = nil
				local res = {coroutine.resume(r, table.unpack(eventData))}
				local ok, data, p2 = table.unpack(res)
				if not ok then
					error(data, 0)
				end
				local isDead = coroutine.status(r) == 'dead'
				if isDead then
					routines[i] = nil
				end
				if data == '/run' then
					local fn = p2
					local args = {table.unpack(res, 4)}
					local thr = coroutine.create(function()
						local ret = {fn(table.unpack(args))}
						return '/return', ret
					end)
					routines[#routines + 1] = thr
					eventFilter[r] = eventCoroutineCreate
					os.queueEvent(eventCoroutineCreate, fn, thr)
				elseif data == '/return' and isDead then -- check if it's dead
					local ret = p2
					os.queueEvent(eventCoroutineDone, r, ret)
				elseif type(data) == 'string' then
					if not isDead then -- check not dead
						eventFilter[r] = data
					end
				end
			end
		end
		eventData = {os.pullEvent()}
	end
end

return {
	run = run,
	main = main,
}
