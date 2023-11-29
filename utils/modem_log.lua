-- Modem logger
-- by zyxkad@gmail.com

function main(args)
	local modem = nil
	for _, v in ipairs(peripheral.getNames()) do
		if peripheral.getType(v) == 'modem' then
			modem = peripheral.wrap(v)
			break
		end
	end
	if not modem then
		error('No modem was found')
	end
	for i = 65500, 65535 do
		modem.open(i)
	end
	while true do
		local _, side, schan, rechan, enmsg, distance = os.pullEvent('modem_message')
		if string.len(enmsg) > 8 then
			enmsg = enmsg:sub(1, 8)
		end
		print(string.format('%d: %d -> %d [%.2f]: %s', os.epoch('utc'), rechan, schan, distance, enmsg))
	end
end

main({...})
