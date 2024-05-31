-- Farmer's Delight Organic Compost Crafter
-- by zyxkad@gmail.com

local peripheralHub = peripheral.find('peripheral_hub')
local localName = peripheralHub.getNameLocal()
local inventories = {peripheral.find('inventory', peripheralHub.isPresentRemote)}

local compostRecipe = {
	grid = {
		'abb',
		'ccd',
		'ddd',
	},
	slots = {
		a = {
			name = 'minecraft:dirt',
		},
		b = {
			name = 'farmersdelight:straw',
		},
		c = {
			name = 'minecraft:bone_meal',
		},
		d = {
			name = 'farmersdelight:tree_bark',
		},
	},
}

local function takeItemFrom(sourceInv, list, item, count, toSlot)
	for slot, data in pairs(list) do
		if data.count > 0 and data.name == item.name and (item.nbt == false or data.nbt == item.nbt) then
			local c = sourceInv.pushItems(localName, slot, count, toSlot)
			data.count = data.count - c
			count = count - c
			if count == 0 then
				break
			end
		end
	end
	return count
end

function precraft(sourceInv, recipe, count)
	local list = sourceInv.list()

	local tookItem = false
	local missing = 0

	-- take item to local storage
	for i = 1, 3 do
		local line = recipe.grid[i]
		for j = 1, 3 do
			local slot = line:sub(j, j)
			if #slot ~= 0 then
				local item = recipe.slots[slot]
				if item then
					local targetSlot = j + (i - 1) * 4
					local pre = turtle.getItemCount(targetSlot)
					if pre < 64 then
						local miss = takeItemFrom(sourceInv, list, item, count, targetSlot)
						if miss < count then
							tookItem = true
						end
					end
				end
			end
		end
	end

	return tookItem
end

function main()
	while true do
		turtle.select(4)
		local num = 0
		for _, inv in pairs(inventories) do
			local tookItem
			repeat
				tookItem = precraft(inv, compostRecipe, 1)
			until not tookItem
			num = 64
			for i = 1, 3 do
				for j = 1, 3 do
					local s = (i - 1) * 4 + j
					num = math.min(num, turtle.getItemCount(s))
				end
			end
			if num == 64 then
				break
			end
		end
		if num > 0 then
			print('crafting:', num, turtle.craft(num))
			turtle.dropUp()
		end
		sleep(0)
	end
end

main({...})
