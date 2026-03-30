-- Fighter
-- by zyxkad@gmail.com

local targets = {
	['minecraft:player'] = {
		name = {
			['Hellscaped'] = 10,
		},
	},
	['minecraft:zombie'] = {
		value = 1,
	},
	['minecraft:skeleton'] = {
		value = 2,
	},
	['minecraft:spider'] = {
		value = 3,
	},
	['minecraft:creeper'] = {
		value = 5,
	},
	['minecraft:blaze'] = {
		value = 2,
	},
	['minecraft:wither_skeleton'] = {
		value = 5,
	},
}

local function getTargetValue(entity)
	if entity.x == 0 and entity.y == 0 and entity.z == 0 then
		return nil
	end
	local set = targets[entity.key]
	if not set then
		return nil
	end
	if set.name then
		local v = set.name[entity.name]
		if v then
			return v
		end
	end
	return set.value
end

local kinetic = peripheral.wrap('back')

local getMetaOwner = kinetic.getMetaOwner
if not getMetaOwner then
	local ownerId
	for _, e in ipairs(kinetic.sense()) do
		if e.x == 0 and e.y == 0 and e.z == 0 then
			ownerId = e.id
			break
		end
	end
	assert(ownerId)
	getMetaOwner = function()
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

local canvas = kinetic.canvas and kinetic.canvas()
local _canvas3d = kinetic.canvas3d and kinetic.canvas3d()
local canvas3d = _canvas3d and _canvas3d.create()

function main()
	local ownerData = nil
	local shouldFight = false
	local target, targetValue = nil, 0

	local shouldFightText = canvas.addText({  x = 200, y = 15 }, 'Fighting: ' .. tostring(shouldFight), 0xffffffff, 0.5)
	local targetInfoText = canvas.addText({ x = 200, y = 20}, 'No Target', 0xffffffff, 0.5)
	local targetBox = canvas3d.addBox(0, 0, 0, 0.2, 0.2, 0.2, 0xff800080)
	local targetMotionBox = canvas3d.addBox(0, 0, 0, 0.3, 0.3, 0.3, 0xffff0070)
	targetBox.setAlpha(0)
	targetBox.setDepthTested(false)
	targetMotionBox.setAlpha(0)
	targetMotionBox.setDepthTested(false)

	local function pollOwner()
		while true do
			ownerData = getMetaOwner()
			canvas3d.recenter()
		end
	end

	local function pullKeys()
		while true do
			local event, key, rep = os.pullEvent()
			if event == 'key' and not rep then
				if key == keys.c then
					shouldFight = not shouldFight
					shouldFightText.setText('Fighting: ' .. tostring(shouldFight))
				end
			end
		end
	end

	local function pollEntity()
		while true do
			local entities = kinetic.sense()
			target, targetValue = nil, 0
			for _, entity in ipairs(entities) do
				local v = getTargetValue(entity)
				if v then
					local hSqrt = entity.x * entity.x + entity.z * entity.z
					entity.dist = math.sqrt(hSqrt + entity.y * entity.y)
					entity.lookYaw = math.deg(math.atan2(-entity.x, entity.z))
					entity.lookPitch = math.deg(math.atan2(-entity.y, math.sqrt(hSqrt)))
					if target == nil or v > targetValue then
						target, targetValue = entity, v
					elseif v == targetValue then
						if entity.dist < target.dist then
							target = entity
						end
					end
				end
			end
			if target then
				targetInfoText.setText(string.format('Target: %s\nx: %.2f + %.2f\ny: %.2f + %.2f\nz: %.2f + %.2f',
					target.name, target.x, target.motionX, target.y, target.motionY, target.z, target.motionZ))
				targetBox.setPosition(target.x, target.y, target.z)
				targetBox.setAlpha(0x80)
				targetMotionBox.setPosition(target.x + target.motionX, target.y + target.motionY, target.z + target.motionY)
				targetMotionBox.setAlpha(0x70)
			end
		end
	end

	local function tryFight(target)
		if not shouldFight then
			sleep(0)
			return
		end
		kinetic.look(target.lookYaw, target.lookPitch)
		sleep(1)
	end

	local function pollFight()
		while true do
			if target then
				tryFight(target)
			else
				targetInfoText.setText('No Target')
				targetBox.setAlpha(0)
				targetMotionBox.setAlpha(0)
				sleep(0)
			end
		end
	end

	parallel.waitForAny(pollOwner, pullKeys, pollEntity, pollFight)
end

main(...)
