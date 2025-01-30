-- Websocket controller daemon
-- by zyxkad@gmail.com

--[==[package:identifier
ID = 'wsd'
VERSION = '0.1.0'
REQUIREMENTS = {
	'coroutinex' = '^1.3.0'
}
--]==]

local expect = require('cc.expect')

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
	--- Begin Installer
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
		settings.set('motd.enable', false)
		settings.save()

		if fs.exists('/startup.lua') then
			fs.delete('/startup.lua')
			-- write('`/startup.lua` is already exists, do you want to move it to `/startup/00_startup.lua`? (yes/No)')
			-- if read(nil, nil,
			-- 	function(t) return completion.choice(t:lower(), {'yes', 'no'}) end):sub(1, 1):lower() ~= 'y' then
			-- 	printError('Setup cancelled')
			-- 	return false
			-- end
			-- if fs.exists('/startup/00_startup.lua') then
			-- 	printError('`/startup/00_startup.lua` is already exists')
			-- 	return false
			-- end
			-- fs.move('/startup.lua', '/startup/00_startup.lua')
		end
		print(string.format('Moving %s to /startup.lua', progPath))
		fs.move(progPath, '/startup.lua')
		return true
	end --- End Installer
end

local wsdPkg = {} -- export package:wsd
local servicePkg = {} -- export package:service

local crx = require('coroutinex')
local Promise = crx.Promise
local co_run = crx.run
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

local function hadSuffix(str, suffix)
	return #str > #suffix and str:sub(-#suffix) == suffix
end

local function removeSuffix(str, suffix)
	if hadSuffix(str, suffix) then
		return true, str:sub(1, - #suffix - 1)
	end
	return false, str
end

local SHELL_PATH = settings.get('wsd.shell', 'rom/programs/shell.lua')
local SERVER = mustGetSetting('wsd.host')
local HOST = mustGetSetting('wsd.server')
local AUTH_TOKEN = mustGetSetting('wsd.auth')
local TERMINATE_MAX_TRY = 10

local ignoreEvents = {
	-- From CC
	-- websocket_message = true,
	-- From wsd
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

local ws = nil

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
	asking[id] = crx.current()
	ws.send(textutils.serialiseJSON({
		type = typ,
		id = id,
		data = data,
	}))
	while true do
		local _, i, res = os.pullEvent('wsd_reply')
		if i == id then
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

local fetchingFiles = {}

local function allocTempDir()
	local dirName = string.format('/tmp/D%06d', math.floor(math.random() * 1000000))
	fs.makeDir(dirName)
	return dirName
end

local function downloadAndOpenFiles(files)
	-- global: ws, fetchingFiles
	if #files == 0 then
		return {}
	end

	local tmpDir = allocTempDir()
	local fileList = {}
	local fileFlags = {}

	local function fileCloser(index)
		if not fileFlags[index] then
			return
		end
		local path = fs.combine(tmpDir, string.format('F%02d.bin', index))
		fs.delete(path)
		fileFlags[index] = nil
		if not next(fileFlags) then
			fs.delete(tmpDir)
		end
	end

	local currentPromise = crx.current()
	for _, id in ipairs(files) do
		fetchingFiles[id] = currentPromise
	end
	ws.send(textutils.serialiseJSON({
		type = 'file_contents',
		ids = files,
	}))
	for i, id in ipairs(files) do
		local fid, content
		repeat
			_, fid, content = os.pullEvent('wsd_file_content')
		until fid == id

		local path = fs.combine(tmpDir, string.format('F%02d.bin', i))
		local handler = fs.open(path, 'w+b')
		local handler_close = handler.close
		handler.close = function()
			handler_close()
			fileCloser(i)
		end

		handler.write(content)
		handler.flush()
		handler.seek('set', 0)

		fileList[i] = handler
		fileFlags[i] = true
	end
	return fileList
end

local function _newDefaultPalette()
	-- have to be sync with https://tweaked.cc/module/colors.html
	local palette = {
		[colors.white]     = 0xF0F0F0,
		[colors.orange]    = 0xF2B233,
		[colors.magenta]   = 0xE57FD8,
		[colors.lightBlue] = 0x99B2F2,
		[colors.yellow]    = 0xDEDE6C,
		[colors.lime]      = 0x7FCC19,
		[colors.pink]      = 0xF2B2CC,
		[colors.gray]      = 0x4C4C4C,
		[colors.lightGray] = 0x999999,
		[colors.cyan]      = 0x4C99B2,
		[colors.purple]    = 0xB266E5,
		[colors.blue]      = 0x3366CC,
		[colors.brown]     = 0x7F664C,
		[colors.green]     = 0x57A64E,
		[colors.red]       = 0xCC4C4C,
		[colors.black]     = 0x111111,
	}
	return palette
end

local function newFakeTerm(id, width, height)
	expect(1, id, 'number')
	expect(2, width, 'number')
	expect(3, height, 'number')

	local usingWindowProxy = true
	local fkTerm = {
		isFake = true,
		_cursorBlink = false,
		_cursorX = 1,
		_cursorY = 1,
		_width = width,
		_height = height,
		_textColor = colors.white,
		_backgroundColor = colors.black,
		_palette = _newDefaultPalette(),
		_lines = {},
		_updatedLines = {},
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
			ws.send(textutils.serialiseJSON({
				type = 'term_oper',
				data = {
					term = id,
					oper = name,
					args = args,
				},
			}))
		end
	end

	local noReplyMethods = {
		scroll = true,
		clear = true,
		clearLine = true,
	}
	for n, _ in pairs(noReplyMethods) do
		fkTerm[n] = newOper(n)
	end

	function fkTerm.getSize()
		return fkTerm._width, fkTerm._height
	end

	local _setCursorPos = newOper('setCursorPos')

	function fkTerm.setCursorPos(x, y)
		expect(1, x, 'number')
		expect(2, y, 'number')
		if x == fkTerm._cursorX and y == fkTerm._cursorY then
			return
		end
		_setCursorPos(x, y)
		fkTerm._cursorX, fkTerm._cursorY = x, y
	end

	function fkTerm.getCursorPos()
		return fkTerm._cursorX, fkTerm._cursorY
	end

	local _setCursorBlink = newOper('setCursorBlink')

	function fkTerm.setCursorBlink(blink)
		expect(1, blink, 'boolean')
		if blink == fkTerm._cursorBlink then
			return
		end
		_setCursorBlink(blink)
		fkTerm._cursorBlink = blink
	end

	function fkTerm.getCursorBlink()
		return fkTerm._cursorBlink
	end

	local _setTextColor = newOper('setTextColor')

	function fkTerm.setTextColor(color)
		expect(1, color, 'number')
		if color == fkTerm._textColor then
			return
		end
		_setTextColor(color)
		fkTerm._textColor = color
	end
	fkTerm.setTextColour = fkTerm.setTextColor

	function fkTerm.getTextColor()
		return fkTerm._textColor
	end
	fkTerm.getTextColour = fkTerm.getTextColor

	local _setBackgroundColor = newOper('setBackgroundColor')

	function fkTerm.setBackgroundColor(color)
		expect(1, color, 'number')
		if color == fkTerm._backgroundColor then
			return
		end
		_setBackgroundColor(color)
		fkTerm._backgroundColor = color
	end
	fkTerm.setBackgroundColour = fkTerm.setBackgroundColor

	function fkTerm.getBackgroundColor()
		return fkTerm._backgroundColor
	end
	fkTerm.getBackgroundColour = fkTerm.getBackgroundColor

	local _write = newOper('write')
	function fkTerm.write(text)
		if usingWindowProxy then
			error('You should not modify the terminal by raw', 1)
		end
		text = tostring(text)
		if #text == 0 then
			return
		end
		_write(text)
		fkTerm._cursorX = fkTerm._cursorX + #text
	end

	local _blit = newOper('blit')
	function fkTerm.blit(text, color, bgColor)
		expect(1, text, 'string')
		expect(2, color, 'string')
		expect(3, bgColor, 'string')
		local len = #text
		if len ~= #color or len ~= #bgColor then
			error('The arguments must have the same length', 2)
		end
		if usingWindowProxy and len ~= fkTerm._width then
			error('You should not modify the terminal by raw', 1)
		end
		if len == 0 then
			return
		end
		fkTerm._cursorX = fkTerm._cursorX + len
		if usingWindowProxy then
			fkTerm._updatedLines[tostring(fkTerm._cursorY)] = {text, color, bgColor}
		else
			_blit(text, color, bgColor)
		end
	end

	function fkTerm.isColor()
		return true
	end
	fkTerm.isColour = fkTerm.isColor

	local _setPaletteColor = newOper('setPaletteColor')

	function fkTerm.setPaletteColor(color, r, g, b)
		expect(1, color, 'number')
		if fkTerm._palette[color] == nil then
			error('Unknown color ' .. color, 2)
		end
		expect(2, r, 'number')
		if g ~= nil or b ~= nil then
			expect(3, g, 'number')
			expect(4, b, 'number')
			r = colors.packRGB(r, g, b)
		end
		if r ~= fkTerm._palette[color] then
			_setPaletteColor(color, r)
			fkTerm._palette[color] = r
		end
	end
	fkTerm.setPaletteColour = fkTerm.setPaletteColor

	function fkTerm.getPaletteColor(color)
		expect(1, color, 'number')
		local c = fkTerm._palette[color]
		if c == nil then
			error('Unknown color ' .. color, 2)
		end
		return colors.unpackRGB(c)
	end
	fkTerm.getPaletteColour = fkTerm.getPaletteColor

	return fkTerm
end

---- END utils functions ----

---- BEGIN programs ----

local programs = {}

local function create_program(tid, path, args, width, height)
	expect(1, tid, 'number')
	expect(2, path, 'string')
	expect(3, args, 'table')
	expect(4, width, 'number')
	expect(5, height, 'number')
	local prog = {}
	programs[tid] = prog
	local progTerm = newFakeTerm(tid, width, height)
	local env = { shell = shell, multishell = multishell, wsd = wsdPkg }
	prog.term = progTerm
	prog.window = window.create(progTerm, 1, 1, width, height, false)
	prog.window.isFake = true
	prog.window.isRunning = function() return prog.term.isRunning() end
	prog.activeTerm = prog.window
	prog.promise = co_run(function()
		sleep(0)
		if path == SHELL_PATH then
			return os.run(env, path, table.unpack(args))
		else
			return os.run(env, SHELL_PATH, path, table.unpack(args))
		end
	end)
	local lastOldTerm = nil
	prog.promise._beforeResumeHook = function()
		-- global: oldTerm
		lastOldTerm = oldTerm
		oldTerm = term.redirect(prog.activeTerm)
	end
	prog.promise._afterResumeHook = function()
		-- global: oldTerm
		prog.activeTerm = term.redirect(oldTerm)
		oldTerm = lastOldTerm
	end
	return prog
end

local function kill_program(prog)
	local stopped = false
	stopped = prog.promise:stop()
	return stopped
end

local function programRunner()
	while true do
		sleep(0)
		for i, prog in pairs(programs) do
			local updatedLines = prog.window._updatedLines
			if next(updatedLines) ~= nil then
				prog.window._updatedLines = {}
				ws.send(textutils.serialiseJSON({
					type = 'term_update',
					data = {
						term = id,
						lines = updatedLines,
					},
				}))
			end
			if prog.status ~= Promise.PENDING then
				prog.term.close()
				programs[i] = nil
				local ok = prog.status == Promise.FULFILLED
				if ok then
					ok = result[1]
				end
				reply(i, ok)
			end
		end
	end
end

---- AFTER programs ----

---- BEGIN service ----

local services = {}

local function preload_service(sid, path)
	expect(1, sid, 'string')
	expect(2, path, 'string')

	print(string.format('Loading service: [%s]', sid))
	if services[sid] then
		error(string.format('Service [%s] is already exists', sid), 2)
	end

	local serviceRegistrablePkg = setmetatable({}, { __index = servicePkg })
	local serviceBuilder = nil

	function serviceRegistrablePkg.register(func)
		if serviceBuilder ~= nil then
			error('service.register called twice', 2)
		end
		expect(1, func, 'function')
		serviceBuilder = {
			_func = func,
			_requires = {},
			_suggests = {},
		}

		function serviceBuilder.require(name, version, soft)
			version = version or '*'
			expect(1, name, 'string')
			expect(2, version, 'string')
			expect(3, soft, 'boolean', 'nil')
			if serviceBuilder._requires[name] or serviceBuilder._suggests[name] then
				error('Dependence ' .. name .. ' is already exists', 2)
			end
			if soft then
				serviceBuilder._suggests[name] = version
			else
				serviceBuilder._requires[name] = version
			end
		end

		function serviceBuilder.suggest(name, version)
			expect(1, name, 'string')
			expect(2, version, 'string')
			serviceBuilder.require(name, version, true)
		end

		return serviceBuilder
	end

	local env = { shell = shell, multishell = multishell, wsd = wsdPkg, service = serviceRegistrablePkg }
	local ok = os.run(env, path)
	if not ok then
		print(string.format('Service register [%s] exited unexpectedly', sid))
		return
	end

	if serviceBuilder == nil then
		print(string.format('Service register [%s] did not invoke service.register', sid))
		return
	end

	local cterm = term.current()
	local width, height = cterm.getSize()
	local svsTerm = window.create(cterm, 1, 2, width, height, false)
	local svs = {}
	services[sid] = svs
	svs.term = svsTerm
	svs.activeTerm = svs.term
	svs.entry = serviceBuilder._func
	svs.requires = serviceBuilder._requires
	svs.suggests = serviceBuilder._suggests
	svs.promise = co_run(svs.entry)
	local lastOldTerm = nil
	svs.promise._beforeResumeHook = function()
		-- global: oldTerm
		lastOldTerm = oldTerm
		oldTerm = term.redirect(svs.activeTerm)
	end
	svs.promise._afterResumeHook = function()
		-- global: oldTerm
		svs.activeTerm = term.redirect(oldTerm)
		oldTerm = lastOldTerm
	end
	return svs
end

local function serviceRunner()
	-- global: services
	while true do
		sleep(1)
		for i, svs in pairs(services) do
			if svs.status ~= Promise.PENDING then
				services[i] = nil
				if svs.status ~= Promise.FULFILLED then
					print(string.format('Service [%s] exited unexpectedly', sid))
				end
			end
		end
	end
end

local function loadServices()
	-- global: services
	if fs.isDir('/services') then
		local list = fs.list('/services')
		for _, name in ipairs(list) do
			local path = fs.combine('/services', name)
			if fs.isDir(path) then
				path = fs.combine(path, 'init.lua')
				if fs.exists(path) and not fs.isDir(path) then
					preload_service(name, path)
				end
			else
				local isLua, sid = removeSuffix(name, '.lua')
				if isLua then
					preload_service(sid, path)
				end
			end
		end
	end
end

---- AFTER service ----

local function newFileHandlers(files)
	local fileList = nil

	fileListHandler.getFiles = function()
		if fileList == nil then
			fileList = false
			fileList = downloadAndOpenFiles(files)
		elseif fileList == false then
			error('Do not call getFiles synchronously', 1)
		end
		return fileList
	end

	return fileListHandler
end

local function _keyProcessor(code, ...)
	return keys[code], ...
end

local eventPreProcessors = {
	key = _keyProcessor,
	key_up = _keyProcessor,
	file_transfer = function(files)
		return newFileHandlers(files)
	end,
}

local function listenWs()
	local handlers = {
		terminate = function(msg)
			error('Remotely Terminated', 0)
		end,
		shutdown = function(msg)
			os.shutdown()
		end,
		reboot = function(msg)
			os.reboot()
		end,

		reply = function(msg)
			local pm = asking[id]
			if pm then
				asking[id] = nil
				pm:queueEvent('wsd_reply', msg.id, msg.data)
			end
		end,
		ping = function(msg)
			-- maybe will use later
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
			local fnenv = {}
			setmetatable(fnenv, { __index = _G })
			local fn, err = load(msg.data, nil, 't', fnenv)
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
			-- print('Creating program:', msg.data.prog)
			local path = shell.resolveProgram(msg.data.prog)
			local args = msg.data.args or {}
			local width, height = msg.data.width, msg.data.height
			if not path then
				reply(id, 'Program not found')
				return
			end
			create_program(id, path, args, width, height)
		end,
		term_event = function(msg)
			local tid = msg.term
			local event = msg.event
			local args = msg.args or {}
			local prog = programs[tid]
			if prog then
				local processor = eventPreProcessors[event]
				if processor then
					prog:queueEvent(event, processor(table.unpack(args)))
				else
					prog:queueEvent(event, table.unpack(args))
				end
			end
		end,
		service_event = function(msg)
			local sid = msg.service
			local event = msg.event
			local args = msg.args or {}
			local serv = services[sid]
			if serv then
				serv:queueEvent(event, table.unpack(args))
			end
		end,
	}

	local binaryHandlers = {
		file_content = function(data)
			local fid = string.byte(data, 1, 1) * 0x100 + string.byte(data, 2, 2)
			local pm = fetchingFiles[fid]
			if pm then
				local content = data:sub(3)
				pm:queueEvent('wsd_file_content', fid, content)
			end
		end
	}

	while true do
		local data, bin = ws.receive()
		if not data then
			printError('Websocket closed')
			break
		end

		if bin then
			local len = string.byte(data, 1, 1)
			local msgType = data:sub(2, 1 + len)
			local h = binaryHandlers[msgType]
			if h then
				h(data:sub(2 + len))
			else
				printError(string.format('WARN: Unexpect binary msg type [%s]', msg.type))
			end
		else
			local msg = textutils.unserialiseJSON(data)
			local h = handlers[msg.type]
			if h then
				h(msg)
			else
				printError(string.format('WARN: Unexpect msg type [%s]', msg.type))
			end
		end
	end
end

local function sendEvent(event)
	local eventTyp = event[1]
	if ignoreEvents[eventTyp] then
		return
	end
	if eventTyp == 'websocket_message' and event[2] == HOST then
		return
	end
	local eventArgs = {table.unpack(event, 2)}
	pcall(ws.send, textutils.serialiseJSON({
		type = 'event',
		event = eventTyp,
		args = eventArgs,
	}))
end

local function listenEvent()
	while true do
		sendEvent({ os.pullEvent() })
	end
end

local function tryConnect()
	while true do
		print('Connecting to ['..HOST..'] ...')
		local ws, err = http.websocket(
			HOST,
			{
				['User-Agent'] = string.format('cc-websocket-daemon/%s (%s)', VERSION, _HOST),
				['X-CC-Auth'] = AUTH_TOKEN,
				['X-CC-Host'] = SERVER,
				['X-CC-ID'] = tostring(os.getComputerID()),
				['X-CC-Device'] = getDeviceType(),
				['X-CC-Label'] = os.getComputerLabel(),
			}
		)
		if ws then
			print('Remote connected')
			return ws
		end
		if not settings.get('wsd.reconnect', true) then
			error(string.format('Cannot connect to [%s]: %s', HOST, err), 3)
		end
		printError("Couldn't connect:", err)
		sleep(3)
	end
end

local function main()
	-- global: ws
	fs.delete('/tmp')

	local reconnect
	loadServices()
	repeat
		ws = nil
		ws = tryConnect()
		await(listenWs, listenEvent, serviceRunner, programRunner)
	until not settings.get('wsd.reconnect')
end

co_main(main, {
	event = 'terminate',
	callback = function()
		local shouldTerminate = settings.get('wsd.terminate', true)
		if ws == nil then
			return shouldTerminate
		end
		if shouldTerminate then
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
