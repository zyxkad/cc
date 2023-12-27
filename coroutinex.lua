-- coroutine extra
-- by zyxkad@gmail.com

local function current()
	return coroutine.yield('/current')
end

local function run(fn, ...)
	if type(fn) == 'thread' then
		assert(#{...} == 0, 'thread cannot have any argument')
	else
		assert(type(fn) == 'function', 'Argument #1(fn) must be a function or a coroutine thread')
	end
	local thr = coroutine.yield('/run', fn, ...)
	return thr
end

local function exit(...)
	coroutine.yield('/exit', ...)
end

local function asleep(n)
	return run(sleep, n)
end

local function asThreads(...)
	local threads = {...}
	for i, fn in ipairs(threads) do
		local typ = type(fn)
		if typ == 'function' then
			local t = run(fn)
			threads[i] = t
			threads[t] = i
		elseif typ ~= 'thread' then
			error(string.format('Argument #%d is %s, expect a coroutine thread or a function',
				i, typ), 2)
		else
			threads[fn] = i
		end
	end
	return threads
end

local eventCoroutineDone = '#cox_thr_done'

local function newThreadErr(id, value)
	local err = {
		index = id,
		err = value,
	}
	setmetatable(err, {
		__tostring = function(err)
			return string.format('Error in thread #%d:\n %s', err.index, err.err)
		end,
	})
	return err
end

-- wait all threads to return successfully
local function await(...)
	local threads = asThreads(...)
	local rets = {}
	local count = 0
	while count ~= #threads do
		local event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = threads[thr]
		if i then
			if not ok then
				error(newThreadErr(i, ret), 2)
			end
			count = count + 1
			rets[i] = ret
		end
	end
	return table.unpack(rets)
end

-- wait the first threads to return successfully
local function awaitAny(...)
	local threads = asThreads(...)
	if #threads == 0 then
		error('No threads could be run', 2)
	end
	local errors = {}
	local errCount = 0
	while true do
		local event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = threads[thr]
		if i then
			if not ok then
				errCount = errCount + 1
				errors[i] = ret
				if errCount == #threads then
					local err = {
						msg = 'All threads failed',
						errs = errors,
					}
					setmetatable(err, {
						__tostring = function(err)
							local str = err.msg
							for _, e in ipairs(err.errs) do
								str = str .. '\n' .. tostring(e)
							end
							return str
						end,
					})
					error(err, 2)
				end
			end
			return i, ret
		end
	end
end

-- wait the threads that exit first (including error)
local function awaitRace(...)
	local threads = asThreads(...)
	if #threads == 0 then
		error('No threads could be run', 2)
	end
	while true do
		local event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = threads[thr]
		if i then
			if not ok then
				error(newThreadErr(i, ret), 2)
			end
			return i, ret
		end
	end
end

local function clearTable(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

local function queueInternalEvent(name, ...)
	assert(type(name) == 'string')
	coroutine.yield('/queue', name, ...)
end

local function main(...)
	local routines = {}
	local mainThreads = {}
	local eventListeners = {}

	for i, fn in ipairs({...}) do
		if type(fn) == 'table' then
			assert(type(fn.event) == 'string')
			assert(type(fn.callback) == 'function')
			local l = eventListeners[fn.event]
			if l then
				l[#l + 1] = fn
			else
				eventListeners[fn.event] = {fn}
			end
		elseif type(fn) == 'function' then
			thr = coroutine.create(fn)
			routines[i] = thr
			routines[thr] = i
			mainThreads[thr] = true
		else
			error(string.format('Bad argument #%d (function expected, got %s)', i, type(fn)), 2)
		end
	end

	local internalEvents = {}
	local eventFilter = {}
	local eventData = {}
	local instantResume = false
	while true do
		instantResume = false
		local keepLoop = false
		local eventType = eventData[1]
		for i, r in pairs(routines) do
			if type(i) == 'number' then
				keepLoop = true
				if eventFilter[r] == nil and (not eventType or string.sub(eventType, 1, 1) ~= '#') or eventFilter[r] == eventType then
					eventFilter[r] = nil
					local next = eventData
					repeat
						local res = {coroutine.resume(r, table.unpack(next))}
						next = false
						local ok, data = res[1], res[2]
						if not ok then -- error occurred
							if mainThreads[r] then
								error(data, 1)
							end
							routines[i] = nil
							routines[r] = nil
							internalEvents[#internalEvents + 1] = {eventCoroutineDone, r, false, data}
						else
							local isDead = coroutine.status(r) == 'dead'
							if isDead then
								routines[i] = nil
								routines[r] = nil
								local ret = {table.unpack(res, 2)}
								internalEvents[#internalEvents + 1] = {eventCoroutineDone, r, true, ret}
							elseif type(data) == 'string' then
								if data == '/exit' then
									return table.unpack(res, 3)
								elseif data == '/current' then
									next = {r}
								elseif data == '/yield' then
									instantResume = true
								elseif data == '/queue' then
									internalEvents[#internalEvents + 1] = {table.unpack(res, 3)}
									next = {}
								elseif data == '/run' then
									local thr
									local p2 = res[3]
									if type(p2) == 'thread' then
										thr = p2
									else
										local fn = p2
										local args = {table.unpack(res, 4)}
										thr = coroutine.create(function() return fn(table.unpack(args)) end)
									end
									local j = #routines + 1
									routines[j] = thr
									routines[thr] = j
									next = {thr}
									instantResume = true
								elseif data == '/stop' then -- TODO: is this really needed and safe?
									local thr = res[3]
									local j = routines[thr]
									if j then
										routines[j] = nil
										routines[thr] = nil
									end
								else
									eventFilter[r] = data
								end
							end
						end
					until not next
				end
			end
		end

		if not keepLoop then
			return
		end

		if #internalEvents > 0 then
			eventData = table.remove(internalEvents, 1)
		elseif instantResume then
			eventData = {}
		else
			local flag
			repeat
				flag = true
				eventData = {os.pullEventRaw()}
				local l = eventListeners[eventData[1]]
				if l then
					for _, d in pairs(l) do
						if d.callback(table.unpack(eventData)) == false then
							flag = false
							break
						end
					end
				end
			until flag
			if eventData[1] == 'terminate' then
				error('Terminated', 0)
			end
		end
	end
end

local function newThreadPool(limit)
	local count = 0
	local running = {}
	local waiting = {}
	local pool = {}

	pool.running = function() return count end
	pool.limit = function() return limit end

	pool.queue = function(fn, ...)
		local typ = type(fn)
		if typ ~= 'function' then
			error(string.format('Argument #1 is %s, but expect a function', typ), 2)
		end
		local args = {...}
		local thr = coroutine.create(function() fn(table.unpack(args)) end)
		if count < limit then
			count = count + 1
			local i = #running + 1
			running[i] = thr
			running[thr] = i
			run(thr)
		else
			waiting[#waiting + 1] = thr
		end
		return thr
	end

	pool.exec = function(fn, ...)
		return table.unpack(await(pool.queue(fn, ...)))
	end

	-- -- release the current thread fron the pool
	-- pool.release = function()
	-- 	local thr = current()
	-- 	local i = running[thr]
	-- 	if i then
	-- 		if #waiting > 0 then
	-- 			running[thr] = nil
	-- 			local nxt = table.remove(waiting, 1)
	-- 			running[i] = nxt
	-- 			running[nxt] = i
	-- 			run(nxt)
	-- 		else
	-- 			running[i] = nil
	-- 			running[thr] = nil
	-- 			count = count - 1
	-- 		end
	-- 		return true
	-- 	end
	-- 	return false
	-- end

	pool.waitForAll = function()
		while count > 0 do
			local event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
			local i = running[thr]
			if i then
				if not ok then
					error(newThreadErr(-i, ret), 2)
				end
				if #waiting > 0 then
					running[thr] = nil
					local nxt = table.remove(waiting, 1)
					running[i] = nxt
					running[nxt] = i
					run(nxt)
				else
					running[i] = nil
					running[thr] = nil
					count = count - 1
				end
			end
		end
	end

	return pool
end

local eventLockIdle = '#crx_lock_idle'

local function newLock()
	local lock = {}
	local count = 0 -- 0: idle, -1: write locked, 1+: read locked

	-- write lock
	lock.lock = function()
		while count ~= 0 do
			coroutine.yield(eventLockIdle)
		end
		count = -1
	end

	lock.tryLock = function()
		if count ~= 0 then
			return false
		end
		count = -1
		return true
	end

	-- write unlock
	lock.unlock = function()
		assert(count == -1)
		count = 0
		queueInternalEvent(eventLockIdle, lock)
	end

	-- read lock
	lock.rLock = function()
		while count < 0 do
			coroutine.yield(eventLockIdle)
		end
		count = count + 1
	end

	lock.tryRLock = function()
		if count < 0 then
			return false
		end
		count = count + 1
		return true
	end

	-- read unlock
	lock.rUnlock = function()
		assert(count > 0)
		count = count - 1
		if count == 0 then
			queueInternalEvent(eventLockIdle, lock)
		end
	end

	return lock
end

return {
	current = current,
	run = run,
	exit = exit,
	asleep = asleep,
	await = await,
	awaitAny = awaitAny,
	awaitRace = awaitRace,
	main = main,

	newThreadPool = newThreadPool,
	newLock = newLock,
}
