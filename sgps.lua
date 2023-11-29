-- Security Global Position System
-- when hosting, sgps will encrypt the position with the aes key
-- when locating, sgps will only accept encrypted messages
-- improved by zyxkad@gmail.com, original codes are from computer craft team's gps program
--
-- Dependencies:
--   aes.lua

local moduleName = ...
local isProgram = not moduleName or moduleName ~= 'sgps'

local expect = dofile("rom/modules/main/cc/expect.lua").expect

local aes = aes
if not aes then
	aes = require('aes')
	if not aes then
		error('aes API not found')
	end
end

local global_aes_key, err = aes.loadKey()
if not global_aes_key then
	error('Cannot load global aes key: ' .. err .. '\nPlease generate 16/24/32 random bytes to id.aes')
end

--- The channel which GPS requests and responses are broadcast on.
local CHANNEL_GPS = 65504

local function trilaterate(A, B, C)
	local a2b = B.vPosition - A.vPosition
	local a2c = C.vPosition - A.vPosition

	if math.abs(a2b:normalize():dot(a2c:normalize())) > 0.999 then
		return nil
	end

	local d = a2b:length()
	local ex = a2b:normalize()
	local i = ex:dot(a2c)
	local ey = (a2c - ex * i):normalize()
	local j = ey:dot(a2c)
	local ez = ex:cross(ey)

	local r1 = A.nDistance
	local r2 = B.nDistance
	local r3 = C.nDistance

	local x = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
	local y = (r1 * r1 - r3 * r3 - x * x + (x - i) * (x - i) + j * j) / (2 * j)

	local result = A.vPosition + ex * x + ey * y

	local zSquared = r1 * r1 - x * x - y * y
	if zSquared > 0 then
		local z = math.sqrt(zSquared)
		local result1 = result + ez * z
		local result2 = result - ez * z

		local rounded1, rounded2 = result1:round(0.01), result2:round(0.01)
		if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return result:round(0.01)
end

local function narrow(p1, p2, fix)
	local dist1 = math.abs((p1 - fix.vPosition):length() - fix.nDistance)
	local dist2 = math.abs((p2 - fix.vPosition):length() - fix.nDistance)

	if math.abs(dist1 - dist2) < 0.01 then
		return p1, p2
	elseif dist1 < dist2 then
		return p1:round(0.01)
	else
		return p2:round(0.01)
	end
end

local function getSecond()
	return math.floor(os.epoch() / 1000) / 100
end

local function locate(_nTimeout, _bDebug)
	expect(1, _nTimeout, "number", "nil")
	expect(2, _bDebug, "boolean", "nil")
	-- Let command computers use their magic fourth-wall-breaking special abilities
	if commands then
		return commands.getBlockPosition()
	end

	-- Find a modem
	local sModemSide = nil
	for _, sSide in ipairs(rs.getSides()) do
		if peripheral.getType(sSide) == "modem" and peripheral.call(sSide, "isWireless") then
			sModemSide = sSide
			break
		end
	end

	if sModemSide == nil then
		if _bDebug then
			print("No wireless modem attached")
		end
		return nil
	end

	if _bDebug then
		print("Finding position...")
	end

	-- Open GPS channel to listen for ping responses
	local modem = peripheral.wrap(sModemSide)
	local bCloseChannel = false
	if not modem.isOpen(CHANNEL_GPS) then
		modem.open(CHANNEL_GPS)
		bCloseChannel = true
	end

	-- Send a ping to listening GPS hosts
	local rn = math.floor(math.random() * 0xffffffff) -- random id
	modem.transmit(CHANNEL_GPS, CHANNEL_GPS, aes.encrypt(global_aes_key, textutils.serialiseJSON({
		op = "PING",
		rn = rn,
	})))

	-- Wait for the responses
	local tFixes = {}
	local pos1, pos2 = nil, nil
	local timeout = os.startTimer(_nTimeout or 2)
	while true do
		local e, p1, p2, p3, p4, p5 = os.pullEvent()
		if e == "modem_message" then
			-- We received a reply from a modem
			local sSide, sChannel, sReplyChannel, sCyMessage, nDistance = p1, p2, p3, p4, p5
			-- Received the correct message from the correct modem: use it to determine position
			if sSide == sModemSide and sChannel == CHANNEL_GPS and sReplyChannel == CHANNEL_GPS and nDistance then
				local sMessage, err = aes.decrypt(global_aes_key, sCyMessage)
				if not sMessage then
					if _bDebug then
						print('Could not decrypt gps result:', err)
					end
				else
					local tMessage = textutils.unserialiseJSON(sMessage)
					if type(tMessage) == "table" and tMessage.op == "REPLY" and tMessage.rn == rn and tMessage.exp > getSecond() then
						local tFix = { vPosition = vector.new(tMessage.x, tMessage.y, tMessage.z), nDistance = nDistance }
						if _bDebug then
							print(tFix.nDistance .. " metres from " .. tostring(tFix.vPosition))
						end
						if tFix.nDistance == 0 then
							pos1, pos2 = tFix.vPosition, nil
						else
							table.insert(tFixes, tFix)
							if #tFixes >= 3 then
								if not pos1 then
									pos1, pos2 = trilaterate(tFixes[1], tFixes[2], tFixes[#tFixes])
								else
									pos1, pos2 = narrow(pos1, pos2, tFixes[#tFixes])
								end
							end
						end
						if pos1 and not pos2 then
							break
						end
					end
				end
			end
		elseif e == "timer" then
			-- We received a timeout
			local timer = p1
			if timer == timeout then
				break
			end
		end
	end

	-- Close the channel, if we opened one
	if bCloseChannel then
		modem.close(CHANNEL_GPS)
	end

	-- Return the response
	if pos1 then
		if pos2 then
			if _bDebug then
				print("Ambiguous position")
				print("Could be " .. pos1.x .. "," .. pos1.y .. "," .. pos1.z .. " or " .. pos2.x .. "," .. pos2.y .. "," .. pos2.z)
			end
			return nil
		end
		if _bDebug then
			print("Position is " .. pos1.x .. "," .. pos1.y .. "," .. pos1.z)
		end
		return pos1.x, pos1.y, pos1.z
	end
	if _bDebug then
		print("Could not determine position")
	end
	return nil
end

local function host(x, y, z, modemSide)
	print(string.format("Position is %d, %d, %d", x, y, z))

	if not modemSide then
		for _, v in ipairs(peripheral.getNames()) do
			if peripheral.getType(v) == 'modem' then
				modemSide = v
				break
			end
		end
		if not modemSide then
			error("No modem found on the computer, require 1")
		end
	elseif peripheral.getType(modemSide) ~= 'modem' then
		error("Peripheral " .. modemSide .. " is not a modem")
	end
	local modem = peripheral.wrap(modemSide)
	print("Opening channel on modem", modemSide)
	modem.open(CHANNEL_GPS)

	local nServed = 0
	local _, print_y = term.getCursorPos()
	while true do
		local _, side, schan, rechan, enmsg, distance = os.pullEvent('modem_message')
		if side == modemSide and schan == CHANNEL_GPS and distance then
			local smsg, err = aes.decrypt(global_aes_key, enmsg)
			if smsg then
				local msg = textutils.unserialiseJSON(smsg)
				if type(msg) == 'table' and msg.op == 'PING' then
					local rn = msg.rn
					local exp = getSecond() + 3
					modem.transmit(rechan, CHANNEL_GPS, aes.encrypt(global_aes_key, textutils.serialiseJSON({
						op='REPLY',
						x=x, y=y, z=z,
						exp=exp, rn=rn
					})))

					nServed = nServed + 1
					term.setCursorPos(1, print_y)
					print(nServed .. ' GPS requests served')
				end
			end
		end
	end
end

---- CLI ----

local subCommands = {
	locate = function(arg, i)
		locate(nil, true)
		return true
	end,
	host = function(arg, i)
		local x, y, z = tonumber(arg[i + 1]), tonumber(arg[i + 2]), tonumber(arg[i + 3])
		host(x, y, z, arg[i + 4])
		return true
	end
}

subCommands.help = function(arg, i)
	local sc = arg[i + 1]
	print('All subcommands:')
	for c, _ in pairs(subCommands) do
		print('-', c)
	end
	print('sgps host <x> <y> <z> [<modem>]')
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

if isProgram then
	return main(arg)
end

---- END CLI ----

return {
	locate = locate,
	host = host,
}
