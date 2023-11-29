-- Modem logger
-- by zyxkad@gmail.com

function main(args)
	local modems = {}
	for _, v in ipairs(peripheral.getNames()) do
		if peripheral.getType(v) == 'modem' then
			local m = peripheral.wrap(v)
			if m.isWireless() then
				m.closeAll()
				modems[#modems + 1] = m
			end
		end
	end
	if #modems == 0 then
		error('No modem was found')
	end
	sleep(1)
	local starts = 50000
	local ends = 65535
	do
		local j = 1
		local m = modems[j]
		local i = starts
		while i <= ends do
			if pcall(m.open, i) then
				i = i + 1
			else
				j = j + 1
				m = modems[j]
				if m == nil then
					ends = i
					break
				end
			end
		end
		print(string.format('Used %d / %d modems', j, #modems))
	end
	print(string.format('Opened port from %d - %d', starts, ends))
	while true do
		local _, side, schan, rechan, enmsg, distance = os.pullEvent('modem_message')
		if string.len(enmsg) > 8 then
			enmsg = enmsg:sub(1, 8)
		end
		print(string.format('%d: [%s]: %d -> %d (%.2f): %s', os.epoch('utc'), side, rechan, schan, distance, enmsg))
	end
end

main({...})
