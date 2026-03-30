-- Key Forwarder
-- by zyxkad@gmail.com

local protocolName = 'key'

function server(...)
	print('ID:', os.getComputerID())

	local args = table.pack(...)

	peripheral.find('modem', rednet.open)
	rednet.host(protocolName, 'key-forwarder-' .. os.getComputerID())
	parallel.waitForAny(function()
		while true do
			local sender, msg = rednet.receive(protocolName)
			if msg[1] == 'key' or msg[1] == 'key_up' then
				os.queueEvent(table.unpack(msg))
			end
		end
	end, function()
		shell.run(table.unpack(args))
	end)
	rednet.unhost(protocolName)
end

function client(target)
	peripheral.find('modem', rednet.open)
	while true do
		local event = {os.pullEvent()}
		print('msg:', textutils.serialise(event, { compact=true }))
		if event[1] == 'key' or event[1] == 'key_up' then
			rednet.send(target, event, protocolName)
		end
	end
end

if arg[1] == '-client' then
	local target = tonumber(arg[2])
	client(target)
else
	server(...)
end
