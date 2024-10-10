-- Reverse tracking Position System
-- by zyxkad@gmail.com

local x = 0
local y = 0
local z = 0

local modems = {
	['modem_6'] = vector.new(x, y, z),
	['modem_7'] = vector.new(x, y + 5, z),
	['modem_8'] = vector.new(x + 5, y + 5, z),
	['modem_9'] = vector.new(x, y + 5, z + 5),
}

---- BEGIN from CC gps API ----

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

---- END from CC gps API ----

local function closeAll()
	for modem, _ in pairs(modems) do
		peripheral.call(modem, 'closeAll')
	end
end

local function openChannel(ch)
	print('Listening', ch)
	for modem, _ in pairs(modems) do
		peripheral.call(modem, 'open', ch)
	end
end

local pending = {}

local function onMessage(modem, ch, msg, dist)
	local pos = modems[modem]
	local msgId = string.format('%d:%s', ch, textutils.serialise(msg, {compact=true}))
	local p = pending[msgId]
	if not p then
		p = {
			tFixes = {},
			pos1 = nil,
			pos2 = nil,
		}
		pending[msgId] = p
	end
	local tFix = { vPosition = pos, nDistance = dist }
	if tFix.nDistance == 0 then
		p.pos1, p.pos2 = tFix.vPosition, nil
	else
		-- Insert our new position in our table, with a maximum of three items. If this is close to a
		-- previous position, replace that instead of inserting.
		local insIndex = math.min(3, #p.tFixes + 1)
		for i, older in pairs(p.tFixes) do
			if (older.vPosition - tFix.vPosition):length() < 1 then
				insIndex = i
				break
			end
		end
		p.tFixes[insIndex] = tFix

		if #p.tFixes >= 3 then
			if not p.pos1 then
				p.pos1, p.pos2 = trilaterate(p.tFixes[1], p.tFixes[2], p.tFixes[3])
			else
				p.pos1, p.pos2 = narrow(p.pos1, p.pos2, p.tFixes[3])
			end
		end
	end
	if p.pos1 and not p.pos2 then
		 print("Position of " .. ch .. " is " .. p.pos1.x .. "," .. p.pos1.y .. "," .. p.pos1.z)
		 pending[msgId] = nil
	end
end

function main(args)
	closeAll()
	openChannel(gps.CHANNEL_GPS)
	openChannel(rednet.CHANNEL_BROADCAST)
	openChannel(rednet.CHANNEL_REPEAT)
	for i, ch in ipairs(args) do
		openChannel(tonumber(ch))
	end

	while true do
		local _, modem, ch, _, msg, dist = os.pullEvent('modem_message')
		if dist and modems[modem] then
			onMessage(modem, ch, msg, dist)
		end
	end
end

main({...})
