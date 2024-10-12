-- Kinetic Controller
-- by zyxkad@gmail.com

local kinetic = peripheral.wrap('back')

local getMetaOwner = kinetic.getMetaOwner
if not getMetaOwner then
	local ownerId = nil
	getMetaOwner = function()
		if not ownerId then
			for _, e in ipairs(kinetic.sense()) do
				if e.x == 0 and e.y == 0 and e.z == 0 then
					ownerId = e.id
				end
			end
		end
		local ok, res
		for i = 1, 8 do
			ok, res = pcall(kinetic.getMetaByID, ownerId)
			if ok then
				return res
			end
		end
		error(res)
	end
end

local function newPID(kP, kI, kD, bias)
	bias = bias or 0
	local errorPrior = 0
	local integralPrior = 0

	local pid = {}
	pid.calc = function(target, actual)
		target = target or 0
		local err = target - actual
		local integral = integralPrior + err
		local derivative = err - errorPrior
		local out = kP * err + kI * integral + kD * derivative + bias
		errorPrior, integralPrior = err, integral
		return out
	end
	return pid
end

function main()
	local canvas = kinetic.canvas()
	local debugText = canvas.addText({ x = 10, y = 110 }, '', 0xffffffff, 0.5)
	local debugTextes = {}
	local function addDebugLine(format)
		format = format or ''

		local index = #debugTextes + 1
		debugTextes[index] = format

		local line = {}
		line.setText = function(text)
			debugTextes[index] = text or ''
		end
		line.setFormat = function(f)
			format = f or ''
		end
		line.format = function(...)
			debugTextes[index] = string.format(format, ...)
		end
		line.update = line.format
		return line
	end

	local player = getMetaOwner()
	local playerChangeSerialId = 0
	local hover = false

	local function waitForPlayerChange(serial)
		serial = serial or playerChangeSerialId
		while serial == playerChangeSerialId do
			os.pullEvent()
		end
	end

	local function pollPlayer()
		local motionLine = addDebugLine('MX: %+.5f\nMY: %+.5f\nMZ: %+.5f')
		while true do
			player = getMetaOwner()
			playerChangeSerialId = playerChangeSerialId % 20 + 1
			motionLine.update(player.motionX, player.motionY, player.motionZ)
		end
	end

	local function launchUpdater(yaw, pitch, power)
		local lastLaunch = 0
		while true do
			local now = os.clock()
			if now ~= lastLaunch and power > 0 then
				lastLaunch = now
				coroutine.resume(coroutine.create(kinetic.launch), yaw, pitch, math.min(4, power))
			end
			yaw, pitch, power = coroutine.yield()
		end
	end
	local updateLaunch = coroutine.wrap(launchUpdater)
	local tgX, tgY, tgZ = 0, 0, 0
	local superPower = false

	local function pullKeys()
		local hoveringLine = addDebugLine('Hovering: %s')
		while true do
			hoveringLine.update(hover)

			local event, key, rep = os.pullEvent()
			if event == 'key' and not rep then
				if key == keys.w then
					tgZ = tgZ + 1
				elseif key == keys.s then
					tgZ = tgZ - 1
				elseif key == keys.a then
					tgX = tgX + 1
				elseif key == keys.d then
					tgX = tgX - 1
				elseif key == keys.f then
					superPower = true
				elseif key == keys.space then
					tgY = tgY + 1
				elseif key == keys.leftShift then
					tgY = tgY - 1
				elseif key == keys.i then
					updateLaunch(player.yaw, 0, 4)
				elseif key == keys.l then
					updateLaunch(player.yaw + 90, 0, 4)
				elseif key == keys.k then
					updateLaunch(player.yaw + 180, 0, 4)
				elseif key == keys.j then
					updateLaunch(player.yaw + 270, 0, 4)
				elseif key == keys.comma then
					updateLaunch(0, -90, 4)
				elseif key == keys.grave then
					hover = not hover
				end
			elseif event == 'key_up' then
				if key == keys.w then
					tgZ = tgZ - 1
				elseif key == keys.s then
					tgZ = tgZ + 1
				elseif key == keys.a then
					tgX = tgX - 1
				elseif key == keys.d then
					tgX = tgX + 1
				elseif key == keys.f then
					superPower = false
				elseif key == keys.space then
					tgY = tgY - 1
				elseif key == keys.leftShift then
					tgY = tgY + 1
				end
			end
		end
	end

	local function attitudeBalance()
		local pidX = newPID(0.5, 0.05, 0.05)
		local pidY = newPID(0.5625, 0.016, 0, 0.0784)
		local pidZ = newPID(0.5, 0.05, 0.05)

		local chartMaxPoints = 100
		local debugChartPos = { x = 110, y = 60 }
		canvas.addRectangle(debugChartPos.x, debugChartPos.y, chartMaxPoints, 0.5, 0xffffffff)
		local debugChartLines = canvas.addLines(debugChartPos, 0xff00ffff, 3)
		local debugChart = {}
		local pyHistory = {}
		for i = 1, chartMaxPoints do
			local pos = { x = debugChartPos.x + i, y = debugChartPos.y }
			debugChartLines.insertPoint(i, pos.x, pos.y)
			debugChart[i] = canvas.addDot(pos, 0xff00ffff, 0.8)
			pyHistory[i] = 0
		end
		debugChartLines.removePoint(chartMaxPoints + 1)

		local powerLine = addDebugLine('Power: %.5f\npx: %+.5f\npy: %+.5f\npz: %+.5f')
		local meanLine = addDebugLine('meanY: %.5f')

		while true do
			if hover then
				local tX, tZ = 0, 0
				if tgX ~= 0 or tgZ ~= 0 then
					local tYaw = math.rad((player.yaw + math.deg(math.atan2(tgZ, tgX)) + 360) % 360)
					tZ, tX = math.sin(tYaw), math.cos(tYaw)
					if superPower then
						tZ, tX = tZ * 3, tX * 3
					end
				end
				local x, y, z = pidX.calc(tX, player.motionX), pidY.calc(tgY, player.motionY), pidZ.calc(tZ, player.motionZ)
				local power = x * x + z * z
				local yaw = math.deg(math.atan2(-x, z))
				local pitch = math.deg(math.atan2(-y, math.sqrt(power)))
				power = math.sqrt(power + y * y)
				powerLine.update(power, x, y, z)
				updateLaunch(yaw, pitch, power)

				table.remove(pyHistory, 1)
				pyHistory[chartMaxPoints] = y
				local meanY = 0
				for i, v in ipairs(pyHistory) do
					meanY = meanY + v
					local dot = debugChart[i]
					local pos = { x = debugChartPos.x + i, y = debugChartPos.y + v / 0.5 * 30 }
					debugChartLines.setPoint(i, pos.x, pos.y)
					dot.setPosition(pos.x - 0.5, pos.y)
				end
				meanY = meanY / chartMaxPoints
				meanLine.update(meanY)
			else
				powerLine.update(0, 0, 0, 0)
				meanLine.update(0)
			end
			lastX, lastY, lastZ = player.motionX, player.motionY, player.motionZ
			waitForPlayerChange()
		end
	end

	local function updateDebugText()
		while true do
			local text = ''
			for _, s in ipairs(debugTextes) do
				text = text .. s .. '\n'
			end
			debugText.setText(text)
			waitForPlayerChange()
		end
	end

	parallel.waitForAny(pollPlayer, pullKeys, attitudeBalance, updateDebugText)
end

main()
