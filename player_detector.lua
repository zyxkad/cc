
local pdor = peripheral.find("playerDetector")
if not pdor then
	error('No player detector was found')
end

local function showMonitor(mName)
	local monitor
	if mName then
		monitor = peripheral.wrap(mName)
		if not monitor then
			printError('Cannot wrap monitor ' .. mName)
			return
		end
	else
		monitor = peripheral.find("monitor")
	end
	if monitor then
		print('Showing players on monitor', peripheral.getName(monitor))
	else
		print('Cannot find monitor, showing on current term')
		monitor = term
	end

	monitor.clear()
	while true do
		local players = pdor.getOnlinePlayers()
		for i, p in ipairs(players) do
			local d = pdor.getPlayerPos(p)
			monitor.setCursorPos(1, i)
			monitor.clearLine()
			if d and d.x then
				monitor.write(string.format('%16s | %5d %3d %5d', p, d.x, d.y, d.z))
			end
		end
		monitor.setCursorPos(1, #players + 1)
		monitor.clearLine()
		sleep(0.1)
	end
end

local function showPocket()
	term.clear()
	while true do
		local players = pdor.getOnlinePlayers()
		local datas = {}
		for _, p in ipairs(players) do
			local d = pdor.getPlayerPos(p)
			if d then
				d.name = p
				datas[#datas + 1] = d
			end
		end
		term.clear()
		for i, d in ipairs(datas) do
			term.setCursorPos(1, i * 3 - 2)
			term.write(string.format('---| %16s |---', d.name))
			term.setCursorPos(1, i * 3 - 1)
			term.write(string.format('  %5d %3d %5d', d.x, d.y, d.z))
			term.setCursorPos(1, i * 3)
			term.write('')
		end
		sleep(0.1)
	end
end

---- CLI ----

local subCommands = {
	monitor = function(arg, i)
		local name = arg[i + 1]
		return showMonitor(name)
	end,
	pocket = function(arg, i)
		return showPocket()
	end,
}

subCommands.help = function(arg, i)
	local sc = arg[i + 1]
	print('All subcommands:')
	for c, _ in pairs(subCommands) do
		print('-', c)
	end
end

local function main(arg)
	if #arg == 0 then
		print('All subcommands:')
		for c, _ in pairs(subCommands) do
			print('-', c)
		end
		return
	end
	local subcmd = arg[1]
	local fn = subCommands[subcmd]
	if fn then
		fn(arg, 1)
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

main({...})

---- END CLI ----
