-- coroutine extra
-- by zyxkad@gmail.com

local function run(fn, ...)
	assert(type(fn) == 'function', 'Argument #1(fn) must be a function')
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
		end
		threads[fn] = i
	end
	return threads
end

local eventCoroutineDone = '#cox_thr_done'

-- wait all threads to return successfully
local function await(...)
	local threads = asThreads(...)
	local rets = {}
	local event, thr, ret
	while #rets ~= #threads do
		event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		assert(event == eventCoroutineDone, 'event ~= eventCoroutineDone')
		local i = threads[thr]
		if i then
			if not ok then
				error({
					msg = string.format('Error in thread #%d: %s', i, ret),
					index = i,
					err = ret,
				}, 2)
			end
			rets[i] = ret
		end
	end
	return table.unpack(rets)
end

-- wait the first threads to return successfully
local function awaitAny(...)
	local threads = asThreads(...)
	if #threads == 0 then
		error({
			msg = 'No threads could be run',
		}, 2)
	end
	local event, thr, ret
	local errors = {}
	while true do
		event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		assert(event == eventCoroutineDone, 'event ~= eventCoroutineDone')
		local i = threads[thr]
		if i then
			if not ok then
				errors[#i] = ret
				if #errors == #threads then
					error({
						msg = 'All threads failed',
						errs = errors,
					}, 2)
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
		error({
			msg = 'No threads could be run',
		}, 2)
	end
	local event, thr, ret
	while true do
		event, thr, ok, ret = coroutine.yield(eventCoroutineDone)
		assert(event == eventCoroutineDone, 'event ~= eventCoroutineDone')
		local i = threads[thr]
		if i then
			if not ok then
				error({
					msg = 'Thread failed',
					index = i,
					err = ret,
				}, 2)
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
						local ok, data, p2 = table.unpack(res)
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
							elseif data == '/exit' then
								return table.unpack(res, 3)
							elseif data == '/yield' then
								instantResume = true
							elseif data == '/run' then
								local fn = p2
								local args = {table.unpack(res, 4)}
								local thr = coroutine.create(function() return fn(table.unpack(args)) end)
								local j = #routines + 1
								routines[j] = thr
								routines[thr] = j
								next = {thr}
								instantResume = true
							elseif data == '/stop' then -- TODO: is this really needed and safe?
								local thr = p2
								local j = routines[thr]
								if j then
									routines[j] = nil
									routines[thr] = nil
								end
							elseif type(data) == 'string' then
								eventFilter[r] = data
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
			eventData = internalEvents[1]
			internalEvents = {table.unpack(internalEvents, 2)}
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

return {
	run = run,
	exit = exit,
	await = await,
	awaitAny = awaitAny,
	main = main,
}
