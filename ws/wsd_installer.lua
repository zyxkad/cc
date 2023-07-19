
local progPath = shell.resolveProgram(arg[0])

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

local function setSetmap(setmap, name)
	setmap[name] = settings.get(name)
end

local function mustOpen(file, mode)
	local fd = io.open(file, mode)
	if not fd then
		error('Cannot open file ['..file..']', 1)
	end
	return fd
end

local function installToDisk(disk)
	if type(disk) == 'string' then
		local disk0 = peripheral.wrap(disk)
		if not disk0 then
			error('disk ['..disk..'] was not found', 1)
		end
		disk = disk0
	end
	if peripheral.getType(disk) ~= 'drive' then
		error('peripheral ['..peripheral.getName(disk)..'] is not a drive, but '..peripheral.getType(disk), 1)
	end
	local setmap = {}
	setSetmap(setmap, 'wsd.shell')
	setSetmap(setmap, 'wsd.host')
	setSetmap(setmap, 'wsd.server')
	setSetmap(setmap, 'wsd.auth')
	setSetmap(setmap, 'wsd.reconnect')
	setSetmap(setmap, 'wsd.terminate')
	local path = disk.getMountPath()
	local fd = mustOpen(path..'/.settings', 'w')
	fd:write(textutils.serialise(setmap))
	fd:close()
	fs.copy(progPath, path..'/startup.lua')
end

local function endswith(str, ends)
	return ends == "" or (#str >= #ends and str:sub(-#ends) == ends)
end

local function install()
	local dir = progPath:sub(1, -#'startup.lua' - 1)
	print('Disk dir:', dir)
	local setFile = dir..'.settings'
	do
		local fd = mustOpen(setFile, 'r')
		local settext = fd:read('*all')
		local setmap = textutils.unserialise(settext)
		fd:close()
		for name, value in pairs(setmap) do
			settings.set(name, value)
		end
	end
	local coxUrl = 'https://raw.githubusercontent.com/zyxkad/cc/master/coroutinex.lua'
	local wsdUrl = 'https://raw.githubusercontent.com/zyxkad/cc/master/ws/wsd.lua'
	if fs.exists('coroutinex.lua') then
		fs.delete('coroutinex.lua')
	end
	shell.run('wget '..coxUrl)
	if fs.exists('wsd.lua') then
		fs.delete('wsd.lua')
	end
	shell.run('wget '..wsdUrl)
	shell.run('wsd install')
	settings.set('shell.allow_disk_startup', false)
	os.reboot()
end

if endswith(progPath, '/startup.lua') then
	install()
elseif arg[1] then
	installToDisk(arg[1])
else
	return {
		installToDisk
	}
end
