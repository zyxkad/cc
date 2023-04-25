-- Hyper Text for ComputerCraft CLI
-- by zyxkad@gmail.com

local htcc = require('htcc')

local function onEvent(id, args)
	-- 
end

function main(args)
	local file = args[1]
	local fd, err = io.open(file, 'r')
	if not fd then
		error(err, 3)
	end

	local htData = htcc.parse(fd)

	if true then return end

	while true do
		local event = {os.pullEvent()}
		onEvent(event[1], {table.unpack(event, 2)})
	end
end

main({...})
