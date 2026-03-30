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

local MAX_POWER = 4

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
				coroutine.resume(coroutine.create(kinetic.launch), yaw, pitch, power)
			end
			yaw, pitch, power = coroutine.yield()
		end
	end
	local updateLaunch = coroutine.wrap(launchUpdater)
	local tgX, tgY, tgZ = 0, 0, 0
	local superPower = false

	local function pullKeys()
		local hoveringLine = addDebugLine('Hovering: %s')
		local pressedKeys = {}
		while true do
			hoveringLine.update(hover)

			local event, key, rep = os.pullEvent()
			if event == 'key' then
				pressedKeys[key] = true
				if not rep then
					if key == keys.grave then
						hover = not hover
					end
				end
			elseif event == 'key_up' then
				pressedKeys[key] = nil
			end

			superPower = pressedKeys[keys.f]
			tgX, tgY, tgZ = 0, 0, 0
			if pressedKeys[keys.w] then
				tgZ = tgZ + 1
			end
			if pressedKeys[keys.s] then
				tgZ = tgZ - 1
			end
			if pressedKeys[keys.a] then
				tgX = tgX + 1
			end
			if pressedKeys[keys.d] then
				tgX = tgX - 1
			end
			if pressedKeys[keys.space] then
				tgY = tgY + 1.2
			end
			if pressedKeys[keys.leftShift] then
				tgY = tgY - 1.2
			end
			if pressedKeys[keys.i] then
				updateLaunch(player.yaw, 0, MAX_POWER)
			elseif pressedKeys[keys.l] then
				updateLaunch(player.yaw + 90, 0, MAX_POWER)
			elseif pressedKeys[keys.k] then
				updateLaunch(player.yaw + 180, 0, MAX_POWER)
			elseif pressedKeys[keys.j] then
				updateLaunch(player.yaw + 270, 0, MAX_POWER)
			elseif pressedKeys[keys.comma] then
				updateLaunch(0, -90, MAX_POWER)
			end
		end
	end

	local function attitudeBalance()
		local pidX = newPID(0.5, 0, 0.05)
		local pidY = newPID(1, 0.1, 0, 0.0784)
		local pidZ = newPID(0.5, 0, 0.05)

		local chartMaxPoints = 100
		local debugChartPos = { x = 110, y = 60 }
		canvas.addRectangle(debugChartPos.x, debugChartPos.y, chartMaxPoints, 0.5, 0xffffffff)
		local debugChartDyLines = canvas.addLines(debugChartPos, 0x0000ffff, 3)
		local debugChartPyLines = canvas.addLines(debugChartPos, 0xff00ffff, 3)
		local debugChartMyLines = canvas.addLines(debugChartPos, 0xffff00ff, 3)
		local debugChartDyDots = {}
		local debugChartPyDots = {}
		local debugChartMyDots = {}
		local dyHistory = {}
		local pyHistory = {}
		local myHistory = {}
		for i = 1, chartMaxPoints do
			local pos = { x = debugChartPos.x + i, y = debugChartPos.y }
			debugChartDyLines.insertPoint(i, pos.x, pos.y)
			debugChartPyLines.insertPoint(i, pos.x, pos.y)
			debugChartMyLines.insertPoint(i, pos.x, pos.y)
			debugChartDyDots[i] = canvas.addDot(pos, 0x0000ffff, 0.8)
			debugChartPyDots[i] = canvas.addDot(pos, 0xff00ffff, 0.8)
			debugChartMyDots[i] = canvas.addDot(pos, 0xffff00ff, 0.8)
			dyHistory[i] = 0
			pyHistory[i] = 0
			myHistory[i] = 0
		end
		debugChartDyLines.removePoint(chartMaxPoints + 1)
		debugChartPyLines.removePoint(chartMaxPoints + 1)

		local powerLine = addDebugLine('Power: %.5f\npx: %+.5f\npy: %+.5f\npz: %+.5f')
		local meanLine = addDebugLine('meanY: %.5f')
		powerLine.update(0, 0, 0, 0)
		meanLine.update(0)

		while true do
			if hover or superPower then
				local tX, tZ = 0, 0
				if tgX ~= 0 or tgZ ~= 0 then
					local tYaw = math.rad((player.yaw + math.deg(math.atan2(tgZ, tgX)) + 360) % 360)
					tZ, tX = math.sin(tYaw), math.cos(tYaw)
					if superPower then
						tZ, tX = tZ * 3, tX * 3
					end
				end
				local x, z = pidX.calc(tX, player.motionX), pidZ.calc(tZ, player.motionZ)
				local y = 0
				local power = x * x + z * z
				local yaw = math.deg(math.atan2(-x, z))
				local pitch = 0
				if hover then
					y = pidY.calc(tgY, player.motionY)
					pitch = math.deg(math.atan2(-y, math.sqrt(power)))
					power = math.sqrt(power + y * y)
				else
					power = math.sqrt(power)
				end
				power = math.min(power, MAX_POWER)
				powerLine.update(power, x, y, z)
				updateLaunch(yaw, pitch, power)
				if hover then
					table.remove(pyHistory, 1)
					pyHistory[chartMaxPoints] = y
					table.remove(dyHistory, 1)
					dyHistory[chartMaxPoints] = player.deltaPosY
					table.remove(myHistory, 1)
					myHistory[chartMaxPoints] = player.motionY
					local meanY = 0
					for i, v in ipairs(pyHistory) do
						meanY = meanY + v
						local xx = debugChartPos.x + i
						local dyDot = debugChartDyDots[i]
						local pyDot = debugChartPyDots[i]
						local myDot = debugChartMyDots[i]
						local dyPos = debugChartPos.y + dyHistory[i] / 0.5 * 30
						local pyPos = debugChartPos.y + v / 0.5 * 30
						local myPos = debugChartPos.y + myHistory[i] / 0.5 * 30
						debugChartDyLines.setPoint(i, xx, dyPos)
						debugChartPyLines.setPoint(i, xx, pyPos)
						debugChartMyLines.setPoint(i, xx, myPos)
						dyDot.setPosition(xx - 0.5, dyPos)
						pyDot.setPosition(xx - 0.5, pyPos)
						myDot.setPosition(xx - 0.5, myPos)
					end
					meanY = meanY / chartMaxPoints
					meanLine.update(meanY)
				end
			end
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
