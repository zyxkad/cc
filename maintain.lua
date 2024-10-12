--- Program Auto Rebooter
--- by zyxkad@gmail.com
--- Usage:
---  maintain [<delay seconds>] <program> [<args>...]

function main(args)
	local delay = tonumber(args[1])
	local program, pargs
	if delay then
		program = args[2]
		pargs = table.pack(table.unpack(args, 3, args.n))
	else
		delay = 3
		program = args[1]
		pargs = table.pack(table.unpack(args, 2, args.n))
	end

	local count = 0
	while true do
		print('Running', program)
		shell.run(program, table.unpack(pargs, 1, pargs.n))
		count = count + 1
		print('Restart delay', delay, 'count', count)
		local timer = os.startTimer(delay)
		repeat
			local event, id = os.pullEventRaw()
			if event == 'terminate' then
				return
			end
		until event == 'timer' and id == timer
	end
end

main(table.pack(...))
