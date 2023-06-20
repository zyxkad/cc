-- Websocket controller daemon
-- by zyxkad@gmail.com

local VERSION = '0.1'

settings.define('wsd.shell', {
	description = 'The shell path to start program',
	type = 'string',
	default='rom/programs/shell.lua',
})
settings.define('wsd.host', {
	description = 'The local server id',
	type = 'string',
})
settings.define('wsd.server', {
	description = 'The remote server URL for wsd',
	type = 'string',
})
settings.define('wsd.auth', {
	description = 'The auth token for wsd',
	type = 'string',
})
settings.define('wsd.reconnect', {
	description = 'Try reconnect after failed',
	type = 'boolean',
	default = true,
})
settings.define('wsd.terminate', {
	description = 'Set to false to prevent default terminate behavior',
	type = 'boolean',
	default = true,
})

do
	local function setNilSetting(name)
		if not settings.get(name, nil) then
			local details = settings.getDetails(name)
			print(string.format('%s [%s](%s) is not defined, please enter a value of it:',
				details.type or '', name, details.description))
			local v = read()
			settings.set(name, v)
		end
	end
	-- Installer
	if arg[1] == 'i' or arg[1] == 'install' or arg[1] == 'set' or arg[1] == 'setup' then
		local function hadPrefix(str, prefix)
			return #str > #prefix and str:sub(1, #prefix) == prefix
		end
		local progPath = shell.resolveProgram(arg[0])
		if not progPath then
			printError("Couldn't resolve this program's path")
			return false
		end
		if hadPrefix(progPath, '/startup') or hadPrefix(progPath, 'startup') then -- either /startup.lua or /startup/*.lua
			printError('Program is already in startups')
			return false
		end

		local completion = require('cc.completion')

		setNilSetting('wsd.host')
		setNilSetting('wsd.server')
		setNilSetting('wsd.auth')
		settings.save()

		if fs.exists('/startup.lua') then
			write('`/startup.lua` is already exists, do you want to move it to `/startup/00_startup.lua`? (yes/No)')
			if read(nil, nil,
				function(t) return completion.choice(t:lower(), {'yes', 'no'}) end):sub(1, 1):lower() ~= 'y' then
				printError('Setup cancelled')
				return false
			end
			if fs.exists('/startup/00_startup.lua') then
				printError('`/startup/00_startup.lua` is already exists')
				return false
			end
			fs.move('/startup.lua', '/startup/00_startup.lua')
		end
		print(string.format('Moving %s to /startup.lua', progPath))
		fs.move(progPath, '/startup.lua')
		return true
	end -- End Installer
end



local crx = require('coroutinex')
local co_run = crx.run
local co_exit = crx.exit
local co_main = crx.main

local function mustGetSetting(name)
	local v = settings.get(name, nil)
	if v == nil then
		error(string.format(
			"[%s] is not set, please use `set %s <value>` to set the setting", name, name
		), 2)
	end
	return v
end

local SHELL_PATH = settings.get('wsd.shell', 'rom/programs/shell.lua')
local SERVER = mustGetSetting('wsd.host')
local HOST = mustGetSetting('wsd.server')
local AUTH_TOKEN = mustGetSetting('wsd.auth')

local ignoreEvents = {
	-- From coroutinex
	queue_push = true,
	queue_pull = true,

	-- From wsd
	_wsd_reply = true,
	_yield = true,
}

local blockPassingEvents = {
	-- From CC
	char = true,
	file_transfer = true,
	key = true,
	key_up = true,
	mouse_click = true,
	mouse_drag = true,
	mouse_scroll = true,
	mouse_up = true,
	paste = true,
	term_resize = true,
}

local ws = nil -- see below `tryConnect`

---- BEGIN utils functions ----

local oldTerm = nil
local native_print = print

local function print(...)
	if oldTerm then
		local t = term.redirect(oldTerm)
		native_print(...)
		term.redirect(t)
	else
		native_print(...)
	end
end

local function getDeviceType()
	if pocket then -- Pocket computer
		return 'pocket'
	elseif turtle then -- Turtle
		return 'turtle'
	else -- Computer block
		return 'computer'
	end
end

local askinc = 0
local asking = {}

local function ask(typ, data)
	local id = askinc + 1
	while asking[id] do
		id = (id + 1) % 0x10000000
	end
	askinc = id
	asking[id] = true
	ws.send(textutils.serialiseJSON({
		type = typ,
		id = id,
		data = data,
	}))
	while true do
		local _, i, res = os.pullEvent('_wsd_reply')
		if i == id then
			asking[id] = nil
			return res
		end
	end
end

local function reply(id, data)
	ws.send(textutils.serialiseJSON({
		type = 'reply',
		id = id,
		data = data,
	}))
end

local function newFakeTerm(id)
	local fkTerm = {
		isFake = true,
	}

	local running = true

	local function checkRunning()
		if not running then
			error('Trying to oper a closed term', 2)
		end
	end

	function fkTerm.isRunning()
		return running
	end

	function fkTerm.close()
		running = false
	end

	local function newOper(name)
		return function(...)
			checkRunning()
			local args = {...}
			if #args == 0 then
				args = textutils.empty_json_array
			end
			local res = ask('term_oper', {
				term = id,
				oper = name,
				args = args,
			})
			if res.status ~= 'ok' then
				error(err, 1)
			end
			if res.res then
				return table.unpack(res.res)
			else
				return
			end
		end
	end

	for n, _ in pairs(term.native()) do
		fkTerm[n] = newOper(n)
	end

	return fkTerm
end

---- END utils functions ----

local function tryConnect()
	assert(not ws, 'websocket already connected')
	local err
	while true do
		print('Connecting to ['..HOST..'] ...')
		ws, err = http.websocket(
			HOST,
			{
				['User-Agent'] = string.format('cc-websocket-daemon/%s (%s)', VERSION, _HOST),
				['X-CC-Auth'] = AUTH_TOKEN,
				['X-CC-Host'] = SERVER,
				['X-CC-ID'] = ''..os.getComputerID(),
				['X-CC-Device'] = getDeviceType(),
			}
		)
		if ws then
			print('Remote connected')
			co_exit(ws)
			return ws
		end
		if not settings.get('wsd.reconnect', true) then
			error(string.format('Cannot connect to [%s]: %s', HOST, err), 3)
		end
		printError("Couldn't connect:", err)
		sleep(3)
	end
end

local programs = {}

local function create_program(tid, path, args)
	local prog = {
		queuedEvents = {},
	}
	programs[tid] = prog
	function prog.queueEvent(event, ...)
		prog.queuedEvents[#prog.queuedEvents + 1] = {
			event, ...,
		}
		os.queueEvent('_yield')
	end
	local progTerm = newFakeTerm(tid)
	local env = { shell = shell, multishell = multishell }
	prog.term = progTerm
	prog.thr = coroutine.create(function()
		local ok
		if path == SHELL_PATH then
			ok = os.run(env, path, table.unpack(args))
		else
			ok = os.run(env, SHELL_PATH, path, table.unpack(args))
		end
		progTerm.close()
		programs[tid] = nil
		reply(tid, ok)
	end)

	os.queueEvent('_yield')
	return prog
end

local function programRunner()
	local eventFilter = {}
	local eventData = {}
	local function resume_program(prog, eventData)
		if eventData[1] == 'char' then
			print('char input:', eventData[2])
		end
		if eventFilter[prog] == nil or eventFilter[prog] == eventData[1] then
			eventFilter[prog] = nil
			oldTerm = term.redirect(prog.term)
			local ok, data = coroutine.resume(prog.thr, table.unpack(eventData))
			prog.term = term.redirect(oldTerm)
			oldTerm = nil
			if not ok then
				error(data, 0)
			end
			if coroutine.status(prog.thr) == 'dead' then
				programs[i] = nil
				return false
			elseif type(data) == 'string' then
				eventFilter[prog] = data
			end
		else -- put event back to the queue
			prog.queuedEvents[#prog.queuedEvents + 1] = eventData
		end
		return true
	end
	while true do
		for i, prog in pairs(programs) do
			if resume_program(prog, eventData) and #prog.queuedEvents > 0 then
				local events = prog.queuedEvents
				prog.queuedEvents = {}
				for _, edata in ipairs(events) do
					resume_program(prog, edata)
				end
			end
		end
		local flag
		repeat
			flag = true
			eventData = {os.pullEvent()}
			local eventTyp = eventData[1]
			if blockPassingEvents[eventTyp] then
				flag = false
			end
		until flag
	end
end

local function _keyProcessor(code, ...)
	return keys[code], ...
end

local eventPreProcessors = {
	key = _keyProcessor,
	key_up = _keyProcessor,
}

local function listenWs()
	local handlers = {
		terminate = function(msg)
			error("Remotely Terminated", 0)
		end,
		reply = function(msg)
			os.queueEvent('_wsd_reply', msg.id, msg.data)
		end,

		exec = function(msg)
			local id = msg.id
			if type(msg.data) ~= 'string' then
				reply(id, {
					status = 'compile_err',
					err = string.format('Unexpect data type %s, expect string', type(msg.data)),
				})
				return
			end
			local fn, err = loadstring(msg.data)
			if fn then
				co_run(function()
					local res = {pcall(fn)}
					if res[1] then
						local ress = {table.unpack(res, 2)}
						if #ress == 0 then
							ress = textutils.empty_json_array
						end
						reply(id, {
							status = 'ok',
							res = ress,
						})
					else
						reply(id, {
							status = 'err',
							err = res[2],
						})
					end
				end)
			else
				reply(id, {
					status = 'compile_err',
					err = err,
				})
			end
		end,
		run = function(msg)
			local id = msg.id
			print('Creating program:', msg.data.prog)
			local path = shell.resolveProgram(msg.data.prog)
			local args = msg.data.args or {}
			if not path then
				reply(id, 'Program not found')
				return
			end
			local prog = create_program(id, path, args)
			prog.queueEvent('char', 't')
			prog.queueEvent('char', 'e')
			prog.queueEvent('char', 's')
			prog.queueEvent('char', 't')
		end,
		term_event = function(msg)
			local tid = msg.term
			local event = msg.event
			local args = msg.args or {}
			local prog = programs[tid]
			if prog then
				local processor = eventPreProcessors[event]
				if processor then
					prog.queueEvent(event, processor(table.unpack(args)))
				else
					prog.queueEvent(event, table.unpack(args))
				end
			end
		end
	}
	while true do
		local data, bin = ws.receive()
		if data then
			if bin then
				printError('WARN: Unexpect binary data received')
			else
				local msg = textutils.unserialiseJSON(data)
				local h = handlers[msg.type]
				if h then
					h(msg)
				else
					printError('WARN: Unexpect msg type ['..msg.type..']')
				end
			end
		else
			printError('Websocket closed')
			co_exit(settings.get('wsd.reconnect'))
			break
		end
	end
end

local function listenEvent()
	while true do
		local event = {os.pullEvent()}
		local eventTyp = event[1]
		if not ignoreEvents[eventTyp] then
			local eventArgs = {table.unpack(event, 2)}
			pcall(ws.send, textutils.serialiseJSON({
				type = 'event',
				event = eventTyp,
				args = eventArgs,
			}))
		end
	end
end

local function main()
	local reconnect
	repeat
		ws = nil
		co_main(tryConnect, {
			event = 'terminate',
			callback = function()
				return settings.get('wsd.terminate', true)
			end
		})
		reconnect = co_main(listenWs, listenEvent, programRunner, {
			event = 'terminate',
			callback = function()
				if settings.get('wsd.terminate', true) then
					ws.send(textutils.serialiseJSON({
						type = 'terminated',
					}))
					return true
				end
				ws.send(textutils.serialiseJSON({
					type = 'terminate',
				}))
				return false
			end,
		})
	until not reconnect
end

main()
