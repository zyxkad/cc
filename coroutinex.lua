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
	error('TODO')
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
	error('TODO')
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

local function clearTable(t)
	for k, _ in pairs(t) do
		t[k] = nil
	end
end

-- Queue constructor
local function queue(size)
	size = size or -1
	local que = {
		size = size,
		_cache = {},
		_offset = 0,
		_pulling = nil,
		_pulling_last = nil,
	}

	local function waitFor(etyp)
		local q
		repeat
			_, q = coroutine.yield(etyp)
		until q == que
	end

	function que.len()
		return #que._cache - que._offset
	end

	function que.push(ele)
		while que.size >= 0 and que.len() >= que.size do
			if que._pulling then
				local cb
				cb, que._pulling = que._pulling.cb, que._pulling.next
				if not que._pulling then
					que._pulling_last = nil
				end
				cb(ele)
				return
			end
			waitFor('queue_pull')
		end
		que._cache[#que._cache] = ele
		os.queueEvent('queue_push', que)
	end

	function que.pull()
		if #que._cache <= que._offset then
			local ok, ret = false, nil
			local n = {
				cb = function(res)
					ok, ret = true, res
				end,
				next = nil,
			}
			if que._pulling then
				que._pulling_last.next = n
			else
				que._pulling = n
			end
			que._pulling_last = n
			os.queueEvent('queue_pull', que)
			while #que._cache <= que._offset do
				waitFor('queue_push')
				if ok then
					return ret
				end
			end
		end
		que._offset = que._offset + 1
		local ele = que._cache[que._offset]
		if #que._cache == que._offset then
			que._offset = 0
			clearTable(que._cache)
		else
			que._cache[que._offset] = 0
		end
		return ele
	end
end

local function main(...)
	local routines = {}
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
			routines[i] = coroutine.create(fn)
		else
			error(string.format('Bad argument #%d (function expected, got %s)', i, type(fn)), 2)
		end
	end

	local eventFilter = {}
	local eventData = {}
	while true do
		for i, r in pairs(routines) do
			if eventFilter[r] == nil or eventFilter[r] == eventData[1] then
				eventFilter[r] = nil
				local flag = true
				while flag do
					local res
					if flag == true then
						res = {coroutine.resume(r, table.unpack(eventData))}
					else
						res = {coroutine.resume(r, table.unpack(flag))}
					end
					flag = false
					local ok, data, p2 = table.unpack(res)
					if not ok then
						error(data, 0)
					end
					local isDead = coroutine.status(r) == 'dead'
					if isDead then
						routines[i] = nil
					end
					if data == '/exit' then
						return table.unpack(res, 3)
					end
					if data == '/run' then
						local fn = p2
						local args = {table.unpack(res, 4)}
						local thr = coroutine.create(function()
							local ret = {fn(table.unpack(args))}
							return '/return', ret
						end)
						routines[#routines + 1] = thr
						flag = {thr}
					elseif data == '/return' then
						if isDead then -- check if it's dead
							-- TODO
							-- local ret = p2
							-- os.queueEvent(eventCoroutineDone, r, ret)
						end
					elseif type(data) == 'string' then
						if not isDead then -- check not dead
							eventFilter[r] = data
						end
					end
				end
			end
		end
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

return {
	run = run,
	exit = exit,
	await = await,
	awaitAny = awaitAny,
	main = main,
}
