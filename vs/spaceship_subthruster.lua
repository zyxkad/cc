-- Starlance ship sub controller
-- by zyxkad@gmail.com

local THRUSTER_TYPE = 'starlance_thruster'

local thrusters = {}
local updateMode = false

function main(shipName)
	assert(type(shipName) == 'string', 'need provide a ship name')
	local protocol = 'spaceship-sub_thruster-' .. shipName

	print('Parsing thrusters')

	local fd = assert(fs.open('thrusters.dat', 'r'))
	local thrusterNames = textutils.unserialize(fd.readAll())
	fd.close()
	for axis, names in pairs(thrusterNames) do
		local list = {}
		for i, n in ipairs(names) do
			local t = peripheral.wrap(n)
			assert(peripheral.hasType(t, THRUSTER_TYPE), n .. ' is not a thruster')
			t.setPeripheralMode(true)
			t.setPower(0)
			list[i] = t
			if updateMode then
				t.setMode('global')
				if i % 50 == 0 then
					sleep(0)
				end
			end
		end
		thrusters[axis] = list
	end

	print('Thrusters parsed')
	print('ID', os.getComputerID())

	rednet.host(protocol, protocol .. '#' .. os.getComputerID())
	peripheral.find('modem', function(name, modem)
		if modem.isWireless() then
			rednet.open(name)
		end
	end)

	while true do
		local sender, message = rednet.receive(protocol)
		if message[1] == 'power' then
			local axis, power = message[2], message[3]
			local list = thrusters[axis] or {}
			local start = os.epoch('utc')
			for _, t in ipairs(list) do
				t.setPower(power)
				if os.epoch('utc') - start > 40 then
					sleep(0)
					start = os.epoch('utc')
				end
			end
		elseif message[1] == 'off' then
			local start = os.epoch('utc')
			for _, list in pairs(thrusters) do
				for _, t in ipairs(list) do
					t.setPower(0)
					if os.epoch('utc') - start > 40 then
						sleep(0)
						start = os.epoch('utc')
					end
				end
			end
		end
	end
end

main(...)
