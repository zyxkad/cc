-- coroutine extra
-- simulate JavaScript async process in Lua
-- by zyxkad@gmail.com

local VERSION = '1.0.1'

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
settings.define('coroutinex.patch.os.timer', {
	description = 'Replace os timer as tick counter to reduce the queue usage for timer',
	default = true,
	type = 'boolean',
})
settings.define('coroutinex.patch.os.timer.tps', {
	description = 'Timer resolution',
	default = 20,
	type = 'number',
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
	pm._timers = {}
	return pm
end

local function isPromise(pm)
	return type(pm) == 'table' and getmetatable(pm) == Promise
end

--- current get the current running Promise
local function current()
	return execute('/current')
end

--- run starts a function/thread/Promise in the current runtime.
-- If the first argument is a function, it will be executed with the following arguments
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

--- exit will interrupt the runtime immediately
-- the runtime will return the arguments passed to this function
local function exit(...)
	execute('/exit', ...)
end

--- asleep(n) is an alias of `run(sleep, n)`
local function asleep(n)
	return run(sleep, n)
end

--- nextTick gives up current iteration round and resumes in the next tick.
local function nextTick()
	coroutine.yield('#crx_tick')
end

--- yield gives up current iteration round.
-- All other coroutines will be executed at least once before the current coroutine resumes
-- The runtime will not yield during the process
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

local _ThreadError = {}

function _ThreadError.__tostring(err)
	local trace = '\n' .. debug.traceback(err.promise.native)
	if err.index then
		return string.format('Error in thread #%d:\n %s', err.index, err.err) .. trace
	end
	return string.format('Error in %s:\n %s', err.promise.native, err.err) .. trace
end

local function newThreadErr(id, pm, value)
	local err = {
		index = id,
		promise = pm,
		err = value,
	}
	setmetatable(err, _ThreadError)
	return err
end

local _CombinedError = {}

function _CombinedError.__tostring(err)
	local str = err.msg
	for _, e in ipairs(err.errs) do
		str = str .. '\n' .. tostring(e)
	end
	return str
end

local function newCombinedError(msg, errors)
	local err = {
		msg = msg,
		errs = errors,
	}
	setmetatable(err, _CombinedError)
	return err
end

--- wait all threads to return successfully
local function await(...)
	local promises = asPromises(...)
	local rets = {}
	local count = 0
	for i, pm in ipairs(promises) do
		if pm._status == Promise.FULFILLED then
			count = count + 1
			rets[i] = pm._result
		elseif pm._status == Promise.REJECTED then
			error(newThreadErr(i, pm, pm._result), 2)
		end
	end
	while count ~= #promises do
		local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = promises[pm]
		if i then
			if not ok then
				error(newThreadErr(i, pm, ret), 2)
			end
			count = count + 1
			rets[i] = ret
		end
	end
	return table.unpack(rets, 1, count)
end

--- wait the first threads to return successfully
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
			if ok then
				return i, table.unpack(ret, 1, ret.n)
			end
			errCount = errCount + 1
			errors[i] = ret
			if errCount == #promises then
				error(newCombinedError('All threads failed', errors), 2)
			end
		end
	end
end

--- wait the threads that exit first (including error)
local function awaitRace(...)
	local promises = asPromises(...)
	if #promises == 0 then
		error('No threads could be run', 2)
	end
	for i, pm in ipairs(promises) do
		if pm._status == Promise.FULFILLED then
			return i, table.unpack(pm._result, 1, pm._result.n)
		elseif pm._status == Promise.REJECTED then
			error(newThreadErr(i, pm, pm._result), 2)
		end
	end
	while true do
		local event, pm, ok, ret = coroutine.yield(eventCoroutineDone)
		local i = promises[pm]
		if i then
			if not ok then
				error(newThreadErr(i, pm, ret), 2)
			end
			return i, table.unpack(ret, 1, ret.n)
		end
	end
end

--- registerTimer is required if you want to listen on a timer that started from another thread
local function registerTimer(id)
	local pm = current()
	pm._timers[id] = true
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

--- main create a new coroutine runtime and run the given functions as main threads
-- If any main threads throws an error, the runtime will re-throw the error to outside.
-- If all main threads are exited, the runtime will not quit but will wait for all running promises to finish.
-- Changing any settings at runtime will have no effect
local function main(...)
	local optPatchOSTimer = settings.get('coroutinex.patch.os.timer', true)
	local timerTps = settings.get('coroutinex.patch.os.timer.tps', 20)
	local timerSpt = 1 / timerTps

	local RUNTIME_DATA = {}
	local routines = {}
	local routineIds = {}
	local mainThreads = {}
	local eventListeners = {}

	local os_startTimer = os.startTimer
	local os_cancelTimer = os.cancelTimer

	local function applyOSPatches()
		if optPatchOSTimer then
			os_startTimer = os.startTimer
			os_cancelTimer = os.cancelTimer
			os.startTimer = startTimerPatch
			os.cancelTimer = cancelTimerPatch
		end
	end

	local function revertOSPatches()
		if optPatchOSTimer then
			os.startTimer = os_startTimer
			os.cancelTimer = os_cancelTimer
		end
	end

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
			routineIds[i] = pm
			routines[pm] = i
			mainThreads[pm] = true
		else
			error(string.format('Bad argument #%d (function or table expected, got %s)', i, type(fn)), 2)
		end
	end

	local waitingTick = false
	local timers = {
		-- [os.clock()] = id,
	}
	local timerSID = 1
	local tickTimerId = os.startTimer(0)
	local internalEvents = {}
	local eventFilter = {}
	local eventData = {}
	local function run(pm)
		pm._runon = RUNTIME_DATA
		local j = #routineIds + 1
		routineIds[j] = pm
		routines[pm] = j
	end
	local function queueInternalEvent(event, ...)
		internalEvents[#internalEvents + 1] = {event, ...}
	end

	local function terminateAll(...)
		for i, r in pairs(routines) do
			if type(i) == 'number' then
				if coroutine.status(r.native) ~= 'dead' then
					coroutine.resume(r.native, 'terminate', ...)
				end
			end
		end
	end

	RUNTIME_DATA.activePools = {}

	local function coroutineDoneHook_Pool(pm, ok, ret)
		local pool = RUNTIME_DATA.activePools[pm]
		if not pool then
			return
		end
		RUNTIME_DATA.activePools[pm] = nil
		if pool._destroyed then
			return
		end
		local running = pool._running
		local waiting = pool._waiting
		local i = running[pm]
		if not i then
			return
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
			pool._count = pool._count - 1
			if pool._count == 0 then
				queueInternalEvent(eventPoolEmpty, pool)
			end
		end
	end

	local function queueCoroutineDoneEvent(r, ok, data)
		queueInternalEvent(eventCoroutineDone, r, ok, data)
		coroutineDoneHook_Pool(r, ok, data)
	end

	while true do
		local instantResume = false
		local keepLoop = false
		local eventType = eventData[1]

		applyOSPatches()
		for i, r in pairs(routineIds) do
			keepLoop = true
			local filter = eventFilter[r]
			local filterOk = filter == nil or filter == eventType
			if filterOk and eventType == 'timer' then
				local timerId = eventData[2]
				if r._timers[timerId] then
					r._timers[timerId] = nil
				else
					filterOk = false
				end
			end
			if filterOk and eventType:sub(1, 1) == '#' then
				filterOk = filter == '#' or filter == eventType
			end
			if filterOk then
				eventFilter[r] = nil
				if _eventLogFile and _DEBUG_RESUME then
					_eventLogFile.write(string.format('%.02f resuming %s\n', os.clock(), r))
					_eventLogFile.flush()
				end
				local next = eventData
				repeat
					local rn = r.native
					local res = table.pack(coroutine.resume(rn, table.unpack(next, 1, next.n)))
					next = false
					local ok, data = res[1], res[2]
					if not ok then -- error occurred
						if mainThreads[r] then
							revertOSPatches()
							terminateAll('thread error')
							error(newThreadErr(nil, r, data), 2)
						end
						routineIds[i] = nil
						routines[r] = nil
						r._status = Promise.REJECTED
						r._result = data
						if _eventLogFile then
							_eventLogFile.write(string.format('%.02f error %s\n  %s\n', os.clock(), r, tostring(data)))
							_eventLogFile.flush()
						end
						queueCoroutineDoneEvent(r, false, data)
					else
						local isDead = coroutine.status(rn) == 'dead'
						if isDead then
							routineIds[i] = nil
							routines[r] = nil
							r._status = Promise.FULFILLED
							local ret = table.pack(table.unpack(res, 2, res.n))
							r._result = ret
							if _eventLogFile and _DEBUG_RESUME then
								_eventLogFile.write(string.format('%.02f done %s %s\n', os.clock(), r, textutils.serialize(ret, { compact = true, allow_repetitions = true })))
								_eventLogFile.flush()
							end
							queueCoroutineDoneEvent(r, true, ret)
						elseif type(data) == 'string' then
							if data == '#crx_tick' then
								waitingTick = true
							end
							eventFilter[r] = data
						elseif data == nil and type(res[3]) == 'string' then
							local command = res[3]
							if command == '/exit' then
								revertOSPatches()
								terminateAll('/exit')
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
								local exp = os.clock() + math.floor(time * timerTps + timerSpt) * timerSpt
								local id = timers[exp]
								if not id then
									id = timerSID
									timerSID = timerSID + 1
									timers[exp] = id
								end
								r._timers[id] = true
								next = {'^'..command, id}
							elseif command == '/canceltimer' then -- cannot cancel a timer currently
								local timerId = res[4]
								-- timers[timerId] = nil
								next = {'^'..command}
							elseif command == '/run' then
								local pm = res[4]
								next = {'^'..command}
								if pm._runon then
									if pm._runon ~= RUNTIME_DATA then
										next = {'^'..command, string.format('%s: Promise %s is already running on a different runtime', tostring(rn), tostring(pm))}
									end
								else
									run(pm)
									instantResume = true
								end
							elseif command == '/stop' then
								local pm = res[4]
								if pm._runon ~= RUNTIME_DATA then
									next = {'^'..command, 'Tring to terminate a promise that does not belong to current runtime'}
								end
								local j = routines[pm]
								if j then
									local ok, data = coroutine.resume(pm.native, 'terminate', '/stop', r)
									if not ok or not data then
										routineIds[j] = nil
										routines[pm] = nil
										pm._status = Promise.REJECTED
										pm._result = data
										if _eventLogFile then
											_eventLogFile.write(string.format('%.02f terminated %s\n', os.clock(), pm))
											_eventLogFile.flush()
										end
										queueCoroutineDoneEvent(r, false, data)
									end
								end
							end
						end
					end
				until not next
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
					for exp, id in pairs(timers) do
						if exp < now + timerSpt then
							timers[exp] = nil
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
				terminateAll(table.unpack(eventData, 2, eventData.n))
				error('Terminated', 0)
			end
		end
	end
end

local eventPoolEmpty = '#crx_pool_empty'
local eventPoolDestroy = '#crx_pool_destroy'

--- newThreadPool create a thread pool which ensure only limited tasks can be run at same time.
-- The task will be start in the order of they queue into the pool.
--
-- It is safe to create pool outside of a coroutinex context.
-- The internal pool manager will be run in the current context as soon as the first task is queued.
-- User should call destroy after the pool is no longer used to release resources.
local function newThreadPool(limit)
	assert(type(limit) == 'number', 'Thread pool limit must be a number')
	local running = {}
	local waiting = {}
	local pool = {
		_count = 0,
		_running = running,
		_waiting = waiting,
		_destroyed = false,
	}

	pool.running = function() return pool._count end
	pool.limit = function() return limit end
	pool.isDestroyed = function() return pool._destroyed end

	pool.queue = function(fn, ...)
		if type(fn) ~= 'function' then
			error(string.format('Argument #1 is %s, but expect a function', type(fn)), 1)
		end
		local args = table.pack(...)
		local pm = newPromise(coroutine.create(function() fn(table.unpack(args, 1, args.n)) end))

		if pool._count < limit then
			pool._count = pool._count + 1
			local i = #running + 1
			running[i] = pm
			running[pm] = i
			current()._runon.activePools[pm] = pool
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

	-- -- release the current thread from the pool
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
		while pool._count > 0 do
			local event, p = coroutine.yield('#') -- for both eventPoolEmpty and eventPoolDestroy
			if event == eventPoolDestroy and p == poll then
				return false
			end
		end
		return true
	end

	pool.destroy = function()
		if pool._destroyed then
			return {}
		end
		pool._destroyed = true
		queueInternalEvent(eventPoolDestroy, pool)
		return waiting
	end

	return pool
end

local eventLockIdle = '#crx_lock_idle'

--- newLock creates a non-reentrant read write lock
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
	VERSION = VERSION,

	Promise = Promise,
	isPromise = isPromise,
	registerTimer = registerTimer,

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
