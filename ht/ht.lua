-- Hyper Text for ComputerCraft CLI
-- by zyxkad@gmail.com

local htcc = require('htcc')
local crx = require('coroutinex')

local htFileNameGuesses = {
	function(name) return name end,
	function(name) return name .. '.ht' end,
	function(name) return name .. '/ht' end
}

local function openFile(name)
	local errs = {}
	for i, g in ipairs(htFileNameGuesses) do
		local n = g(name)
		local fd, err = io.open(n, 'r')
		if fd then
			return fd
		end
		errs[i] = { n, err }
	end
	local err = 'ht file "' .. name .. '" not found:'
	for _, e in ipairs(errs) do
		err = err .. '\n  ' .. e[2]
	end
	error(err, 1)
end

local function render(outputName, files)
	local output
	if outputName == 'term' then
		output = term.current()
	else
		output = peripheral.wrap(outputName)
		if not output then
			error(string.format('Peripheral %s is not found', outputName), 1)
		end
	end

	local file = files[1]
	local fd = openFile(file)

	local root = htcc.parse(fd)

	local onload = root.scripts:symbol('.onload', 'function')
	crx.main(function()
		onload(htcc.OnloadEvent:new(nil, root))
		while true do
			local event = {os.pullEvent()}
			local ename = event[1]
			local eargs = { table.unpack(event, 2) }
			output.setCursorPos(1, 1)
			root:onOsEvent(ename, eargs)
			root:ondraw(output)
		end
	end)
end

local subCommands = {
	render = function(args)
		return render(args[1], { table.unpack(args, 2) })
	end,
}

subCommands.help = function(args)
	local sc = args[1]
	print('All subcommands:')
	for c, _ in pairs(subCommands) do
		print('-', c)
	end
end

function main(args)
	if #args == 0 then
		return subCommands.help({})
	end
	local subcmd = args[1]
	local fn = subCommands[subcmd]
	if fn then
		fn({ table.unpack(args, 2) })
	else
		error(string.format("Unknown subcommand '%s'", subcmd))
	end
end

main({...})
