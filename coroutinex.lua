-- coroutine extra
-- simulate JavaScript async process in Lua
-- by zyxkad@gmail.com

---- BEGIN debug ----

local _eventLogFile = nil
local _DEBUG_EVENT = false
local _DEBUG_RESUME = false

local function startDebug()
	if _eventLogFile then
		return true
	end
	local err
	_eventLogFile, err = fs.open('crx.debug.log', 'w')
	if not _eventLogFile then
		return nil, err
	end
	return true
end

settings.define('coroutinex.debug', {
	description = 'Enable debug log for coroutinex',
	default = false,
	type = 'boolean',
})
settings.define('coroutinex.debug.event', {
	description = 'Record event',
	default = false,
	type = 'boolean',
})
settings.define('coroutinex.debug.resume', {
	description = 'Record thread resume',
	default = false,
	type = 'boolean',
})
settings.save()

if settings.get('coroutinex.debug', false) then
	_DEBUG_EVENT = settings.get('coroutinex.debug.event', false)
	_DEBUG_RESUME = settings.get('coroutinex.debug.resume', false)
	startDebug()
end

---- END debug ----

local EMPTY_TABLE = {}

local function execute(command, ...)
	assert(type(command) == 'string')
	local res = table.pack(coroutine.yield(nil, command, ...))
	if res[1] ~= ('^' .. command) then
		error('Tring to execute command ' .. command .. ' outside coroutinex threads', 3)
	end
	return table.unpack(res, 2, res.n)
end

local Promise = {
	PENDING   = 0,
	FULFILLED = 1,
	REJECTED  = 2,

	-- _native = nil, -- thread
	-- _result = nil, -- table list or error
	-- _status = Promise.PENDING, -- PENDING, FULFILLED, or REJECTED
	-- _runon  = nil, -- an address represent which base routine is it running on
}

function Promise.__index(pm, key)
	if key == 'native' then
		return pm._native
	elseif key == 'result' then
		return pm._result
	elseif key == 'status' then
		return pm._status
	end
	return Promise[key]
end

function Promise.__tostring(pm)
	local s = 'Promise{status='
	if pm._status == Promise.PENDING then
		s = s .. 'pending'
	elseif pm._status == Promise.FULFILLED then
		s = s .. 'fulfilled'
	elseif pm._status == Promise.REJECTED then
		s = s .. 'rejected'
	else
		s = s .. 'unknown ' .. tostring(pm._status)
	end
	s = s .. ', ' .. tostring(pm._native)
	s = s .. '}'
	return s
end

local function newPromise(thread)
	assert(type(thread) == 'thread')
	if coroutine.status(thread) == 'dead' then
		error('Cannot wrap a dead thread as promise', 2)
	end
	local pm = {}
	setmetatable(pm, Promise)
	pm._native = thread
	pm._status = Promise.PENDING
	return pm
end

local function isPromise(pm)
	return type(pm) == 'table' and getmetatable(pm) == Promise
end

local function current()
	return execute('/current')
end

local function run(pm, ...)
	if type(pm) == 'function' then
		local fn, args = pm, table.pack(...)
		pm = newPromise(coroutine.create(function() return fn(table.unpack(args, 1, args.n)) end))
	elseif type(pm) == 'thread' then
		pm = newPromise(pm)
	elseif not isPromise(pm) then
		error('Argument #1 must be function, thread, or promise, but got ' .. type(pm), 2)
	end
	local err = execute('/run', pm)
	if err then
		error(err, 2)
	end
	return pm
end

local function exit(...)
	execute('/exit', ...)
end

-- asleep(n) is an alias of `run(sleep, n)`
local function asleep(n)
	return run(sleep, n)
end

local function nextTick()
	coroutine.yield('#crx_tick')
end

local function yield()
	coroutine.yield(nil, '/yield')
end

local function asPromises(...)
	local threads = {...}
	for i, thr in ipairs(threads) do
		local typ = type(thr)
		if typ == 'function' or typ == 'thread' then
			local pm = run(thr)
			threads[i] = pm
			threads[pm] = i
		elseif isPromise(thr) then
			threads[thr] = i
		else
			error(string.format('Argument #%d is %s, expect function, thread, or promise', i, typ), 2)
		end
	end
	return threads
end

local eventCoroutineDone = '#crx_thr_done'

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
	local promises = asPromises(...)
	local rets = {}
	local count = 0
	for i, pm in ipairs(promises) do
		if pm._status == Promise.FULFILLED then
			count = count + 1
			rets[i] = pm._result
		elseif pm._status == Promise.REJECTED then
			error(newThreadErr(i, pm._result), 2)
		end
	end
	while count ~= #promises do
		local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = promises[pm]
		if i then
			if not ok then
				error(newThreadErr(i, ret), 2)
			end
			count = count + 1
			rets[i] = ret
		end
	end
	return table.unpack(rets, 1, count)
end

-- wait the first threads to return successfully
local function awaitAny(...)
	local promises = asPromises(...)
	if #promises == 0 then
		error('No threads could be run', 2)
	end
	local errors = {}
	local errCount = 0
	for i, pm in ipairs(promises) do
		if pm._status == Promise.FULFILLED then
			return i, table.unpack(pm._result, 1, pm._result.n)
		elseif pm._status == Promise.REJECTED then
			errCount = errCount + 1
			errors[i] = pm._result
		end
	end
	while true do
		local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = promises[pm]
		if i then
			if not ok then
				errCount = errCount + 1
				errors[i] = ret
				if errCount == #promises then
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
			return i, table.unpack(ret, 1, ret.n)
		end
	end
end

-- wait the threads that exit first (including error)
local function awaitRace(...)
	local promises = asPromises(...)
	if #promises == 0 then
		error('No threads could be run', 2)
	end
	for i, pm in ipairs(promises) do
		if pm._status == Promise.FULFILLED then
			return i, table.unpack(pm._result, 1, pm._result.n)
		elseif pm._status == Promise.REJECTED then
			error(newThreadErr(i, pm._result), 2)
		end
	end
	while true do
		local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = promises[pm]
		if i then
			if not ok then
				error(newThreadErr(i, ret), 2)
			end
			return i, table.unpack(ret, 1, ret.n)
		end
	end
end

local function queueInternalEvent(name, ...)
	assert(type(name) == 'string')
	execute('/queue', name, ...)
end

local function startTimerPatch(time)
	assert(type(time) == 'number' or type(time) == 'nil')
	return execute('/timer', time or 0)
end

local function cancelTimerPatch(id)
	execute('/canceltimer', id)
end

local os_startTimer = os.startTimer
local os_cancelTimer = os.cancelTimer

local function applyOSPatches()
	os_startTimer = os.startTimer
	os_cancelTimer = os.cancelTimer
	os.startTimer = startTimerPatch
	os.cancelTimer = cancelTimerPatch
end

local function revertOSPatches()
	os.startTimer = os_startTimer
	os.cancelTimer = os_cancelTimer
end

local function main(...)
	local RUNTIME_ID = {}
	local routines = {}
	local mainThreads = {}
	local eventListeners = {}

	for i, arg in ipairs({...}) do
		if type(arg) == 'table' then
			assert(type(arg.event) == 'string')
			assert(type(arg.callback) == 'function')
			local l = eventListeners[arg.event]
			if l then
				l[#l + 1] = arg
			else
				eventListeners[arg.event] = {arg}
			end
		elseif type(arg) == 'function' then
			local pm = newPromise(coroutine.create(arg))
			routines[i] = pm
			routines[pm] = i
			mainThreads[pm] = true
		else
			error(string.format('Bad argument #%d (function or table expected, got %s)', i, type(fn)), 2)
		end
	end

	local waitingTick = false
	local timers = {
		-- [id] = os.clock(),
	}
	local timerSID = 1
	local tickTimerId = os.startTimer(0)
	local internalEvents = {}
	local eventFilter = {}
	local eventData = {}
	local queueInternalEvent = function(event, ...)
		internalEvents[#internalEvents + 1] = {event, ...}
	end
	while true do
		local instantResume = false
		local keepLoop = false
		local eventType = eventData[1]

		applyOSPatches()
		for i, r in pairs(routines) do
			if type(i) == 'number' then
				keepLoop = true
				-- only pass internal event when asked to
				if eventFilter[r] == nil and (not eventType or string.sub(eventType, 1, 1) ~= '#') or eventFilter[r] == eventType then
					if _eventLogFile and _DEBUG_RESUME then
						_eventLogFile.write(string.format('%.02f resuming %s\n', os.clock(), r))
						_eventLogFile.flush()
					end
					eventFilter[r] = nil
					local next = eventData
					repeat
						local rn = r.native
						local res = table.pack(coroutine.resume(rn, table.unpack(next, 1, next.n)))
						next = false
						local ok, data = res[1], res[2]
						if not ok then -- error occurred
							if mainThreads[r] then
								revertOSPatches()
								error(tostring(rn) .. ': ' .. tostring(data), 2)
							end
							routines[i] = nil
							routines[r] = nil
							r._status = Promise.REJECTED
							r._result = data
							if _eventLogFile then
								_eventLogFile.write(string.format('%.02f error %s\n  %s\n', os.clock(), r, tostring(data)))
								_eventLogFile.flush()
							end
							queueInternalEvent(eventCoroutineDone, r, false, data)
						else
							local isDead = coroutine.status(rn) == 'dead'
							if isDead then
								routines[i] = nil
								routines[r] = nil
								r._status = Promise.FULFILLED
								local ret = table.pack(table.unpack(res, 2, res.n))
								r._result = ret
								if _eventLogFile and _DEBUG_RESUME then
									_eventLogFile.write(string.format('%.02f done %s %s\n', os.clock(), r, textutils.serialize(ret, { compact = true, allow_repetitions = true })))
									_eventLogFile.flush()
								end
								queueInternalEvent(eventCoroutineDone, r, true, ret)
							elseif type(data) == 'string' then
								if data == '#crx_tick' then
									waitingTick = true
								end
								eventFilter[r] = data
							elseif data == nil and type(res[3]) == 'string' then
								local command = res[3]
								if command == '/exit' then
									revertOSPatches()
									return table.unpack(res, 4)
								elseif command == '/current' then
									next = {'^'..command, r}
								elseif command == '/yield' then
									instantResume = true
								elseif command == '/queue' then
									queueInternalEvent(table.unpack(res, 4, res.n))
									next = {'^'..command}
								elseif command == '/timer' then
									local time = res[4]
									timers[timerSID] = os.clock() + math.floor(time * 20 + 0.5) / 20
									next = {'^'..command, timerSID}
									timerSID = timerSID + 1
								elseif command == '/canceltimer' then
									local timerId = res[4]
									timers[timerId] = nil
									next = {'^'..command}
								elseif command == '/run' then
									local pm = res[4]
									next = {'^'..command}
									if pm._runon then
										if pm._runon ~= RUNTIME_ID then
											next = {'^'..command, string.format('%s: Promise %s is already running on a different runtime', tostring(rn), tostring(pm))}
										end
									else
										pm._runon = RUNTIME_ID
										local j = #routines + 1
										routines[j] = pm
										routines[pm] = j
										instantResume = true
									end
								elseif command == '/stop' then -- TODO: is this really needed and safe?
									local pm = res[4]
									local j = routines[pm]
									if j then
										routines[j] = nil
										routines[pm] = nil
									end
								end
							end
						end
					until not next
				end
			end
		end
		revertOSPatches()

		if not keepLoop then
			return
		end

		if #internalEvents > 0 then
			eventData = table.remove(internalEvents, 1)
		elseif instantResume then
			eventData = EMPTY_TABLE
		else
			local flag
			repeat
				flag = true
				eventData = table.pack(coroutine.yield())
				if eventData[1] == 'timer' and eventData[2] == tickTimerId then
					tickTimerId = os.startTimer(0)
					local now = os.clock()
					for id, exp in pairs(timers) do
						if exp <= now then
							timers[id] = nil
							queueInternalEvent('timer', id)
						end
					end
					if waitingTick then
						waitingTick = false
						eventData = {'#crx_tick'}
					elseif #internalEvents > 0 then
						eventData = table.remove(internalEvents, 1)
					else
						flag = false
					end
				else
					if _eventLogFile and _DEBUG_EVENT then
						local ok, str = pcall(textutils.serialize, eventData, { compact = true, allow_repetitions = true })
						if not ok then
							str = string.format('%s %s', textutils.serialize(tostring(eventData[1])), tostring(eventData[2]))
						end
						_eventLogFile.write(string.format('%.02f %s\n', os.clock(), str))
						_eventLogFile.flush()
					end
					local l = eventListeners[eventData[1]]
					if l then
						for _, d in pairs(l) do
							if d.callback(table.unpack(eventData, 1, eventData.n)) == false then
								flag = false
								break
							end
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

local eventPoolTasksDone = '#crx_pool_tasks_done'

local function newThreadPool(limit)
	assert(type(limit) == 'number', 'Thread pool limit must be a number')
	local count = 0
	local running = {}
	local waiting = {}
	local pool = {}

	pool.running = function() return count end
	pool.limit = function() return limit end

	pool.queue = function(fn, ...)
		if type(fn) ~= 'function' then
			error(string.format('Argument #1 is %s, but expect a function', type(fn)), 1)
		end
		local args = table.pack(...)
		local pm = newPromise(coroutine.create(function() fn(table.unpack(args, 1, args.n)) end))
		if count < limit then
			count = count + 1
			local i = #running + 1
			running[i] = pm
			running[pm] = i
			run(pm)
		else
			waiting[#waiting + 1] = pm
		end
		return pm
	end

	pool.exec = function(fn, ...)
		local res = await(pool.queue(fn, ...))
		return table.unpack(res, 1, res.n)
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
			coroutine.yield(eventPoolTasksDone)
		end
	end

	run(function()
		while true do
			local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
			local i = running[pm]
			if i then
				if not ok then
					error(newThreadErr(-i, ret), 2)
				end
				if #waiting > 0 then
					running[pm] = nil
					local nxt = table.remove(waiting, 1)
					running[i] = nxt
					running[nxt] = i
					run(nxt)
				else
					running[i] = nil
					running[pm] = nil
					count = count - 1
					if count == 0 then
						queueInternalEvent(eventPoolTasksDone, pool)
					end
				end
			end
		end
	end)

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
	nextTick = nextTick,
	yield = yield,
	await = await,
	awaitAny = awaitAny,
	awaitRace = awaitRace,
	main = main,

	newThreadPool = newThreadPool,
	newLock = newLock,

	startDebug = startDebug,
}
