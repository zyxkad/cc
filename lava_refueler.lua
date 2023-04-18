

local bucketId = 'minecraft:bucket'
local lavaBucketId = 'minecraft:lava_bucket'

local function selectItem(item)
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if (item == nil and detial == nil) or (item ~= nil and detial and detial.name == item) then
			turtle.select(i)
			return true
		end
	end
	return false
end

function main()
	if turtle.getFuelLevel() == 'unlimited' then
		print('Unlimited fuel')
		return
	end
	local fuelLimit = turtle.getFuelLimit()
	print('Fuel limit:', fuelLimit)
	print('Fuel left:', turtle.getFuelLevel())
	if not selectItem(bucketId) then
		if selectItem(lavaBucketId) then
			turtle.refuel()
		else
			printError('WARN: Bucket not found, try to suck from the tank')
			if not selectItem(nil) then
				printError('ERR: Cannot found an empty slot')
				return
			end
			if not turtle.suck() then
				printError('ERR: Nothing was in the tank')
				return
			end
			local detial = turtle.getItemDetail()
			print(string.format('Found %s in the tank', detial.name))
			if detial.name == lavaBucketId then
				turtle.refuel()
			elseif detial.name ~= bucketId then
				printError('Unexpected item, expect lava bucket or empty bucket')
				return
			end
		end
	end
	print('Fueling...')
	local ok = true
	while turtle.getFuelLevel() < fuelLimit do
		turtle.drop()
		if not turtle.suck() then
			ok = false
			printError('No fuel left in the tank')
			break
		end
		turtle.refuel()
		print('fuel level:', turtle.getFuelLevel(), '/', fuelLimit)
	end
	if ok then
		-- don't keep the bucket
		turtle.drop()
	end
	print('Fuel end:', turtle.getFuelLevel(), 'out of', fuelLimit)
end

main()
