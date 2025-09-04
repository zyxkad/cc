-- Feed Forward Tuner
-- by zyxkad@gmail.com

local servos = {}

local PeripheralList = {}

function PeripheralList.__index(list, method)
	if type(method) ~= 'string' then
		return nil
	end
	if method == 'any' then
		return function (method)
			for i, p in ipairs(list) do
				local r = p[method]()
				if r then
					return r
				end
			end
			return nil
		end
	end
	if list[1] == nil or type(list[1][method]) ~= 'function' then
		return nil
	end

	local m = function(...)
		local args = table.pack(...)
		local fns = {}
		for i, p in ipairs(list) do
			local pm = p[method]
			fns[i] = function() pm(table.unpack(args)) end
		end
		parallel.waitForAll(table.unpack(fns))
	end
	list[method] = m
	return m
end

for _, servo in pairs({peripheral.find('servo')}) do
	local name = servo.getName()
	if name == nil then
		servo.setEnabled(false)
	else
		local list = servos[name]
		if not list then
			list = setmetatable({}, PeripheralList)
			servos[name] = list
		end
		servo.setEnabled(true)
		list[#list + 1] = servo
	end
end

print('Servos:')
for name, list in pairs(servos) do
	print(string.format(' %s -- %d', name, #list))
end

sleep(1)

local tservos = servos.leftBtmLeg

tservos.setPositionMode(true)
tservos.setPosPID(3, 0, 3)
tservos.setVelPID(3e7, 3e7, 0)
-- tservos.setTargetVelocity(0)
tservos.setTargetAngle(math.rad(45))

-- 10, 4938696
-- 20, 10363793
-- 30, 15066371
-- 45, 21032332
-- 60, 22000000
-- tservos.setFeedForwardForce(1e7)

local function logger()
	local lastt = os.epoch('utc')
	local lastd = tservos[1].getCurrentAngle()
	while true do
		os.queueEvent('_logger')
		os.pullEvent('_logger')
		local t = os.epoch('utc')
		local d = tservos[1].getCurrentAngle()
		local f = tservos[1].getLastTorque()
		local dt = (t - lastt) / 1000
		local v = (lastd - d) / dt

		local sinFeed = f / math.sin(d)
		local cosFeed = f / math.cos(d)

		print(string.format('%+9.5f %+8.5f %+8d %+8d %+8d', math.deg(d), math.deg(v), f, sinFeed, cosFeed))
	end
end

local function main()
	while true do
		sleep()
	end
end

parallel.waitForAny(logger, main)
