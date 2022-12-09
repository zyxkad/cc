-- Remote turtle client side
-- by zyxkad@gmail.com

if not rednet then
	error("rednet API wasn't found")
end


local function main()
	print("Starting turtle client with arguments:", table.concat(arg, ", "))

	local id = arg[1]
	if not id then
		error("You must give an ID for connect to turtle")
	end
	local _modem = arg[2] or "back"

	print("turtle id =", id)
	print("modem side =", _modem)
	print()

	local modem = nil
	for _, v in ipairs(peripheral.getNames()) do
		if peripheral.getType(v) == 'modem' then
			modem = v
			break
		end
	end
	if not modem then
		error("No modem found on the computer")
	end

	rednet.open(modem)
	local tid = rednet.lookup(id, string.format("turtle-%s", id))
	if not tid then
		error(string.format("Cannot find turtle with id '%s'", id))
	end

	print("Found turtle:", tid)
	while(true) do
		print("Reading command...")
		local cmd = read()
		rednet.send(tid, {
			c = cmd,
			a = nil,
		}, id)
		local _, reply = rednet.receive(string.format("reply-%s", id), 30)
		print('reply:', reply)
	end
end

main()
