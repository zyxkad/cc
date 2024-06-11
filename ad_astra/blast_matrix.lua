-- Ad Astra steel martix
-- by zyxkad@gmail.com

local furnaceType = 'ad_astra:etreonic_blast_furnace'
local ironId = 'minecraft:iron_ingot'
local coalId = 'minecraft:charcoal'
local steelId = 'ad_astra:steel_ingot'

local furnaces = {}

local function pullEvents()
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			if peripheral.hasType(name, furnaceType) then
				print('new furnace', name)
				furnaces[name] = true
			end
		elseif event == 'peripheral_detach' then
			furnaces[name] = false
		end
	end
end

local function pullMaterialsFrom(chest)
	local items = chest.list()
	for slot, item in pairs(items) do
		local pushTo = nil
		if item.name == ironId then
			pushTo = 2
		elseif item.name == coalId then
			pushTo = 3
		end
		if pushTo then
			for name, _ in pairs(furnaces) do
				item.count = item.count - chest.pushItems(name, slot, 1, pushTo)
				if item.count <= 0 then
					break
				end
			end
		end
	end
end

local function pushProductsTo(chest)
	local fn = {}
	for name, _ in pairs(furnaces) do
		fn[#fn + 1] = function()
			chest.pullItems(name, 6)
		end
	end
	parallel.waitForAll(table.unpack(fn))
end

function main(args)
	local chestName = assert(args[1])
	local chest = assert(peripheral.wrap(chestName))
	peripheral.find(furnaceType, function(name)
		print('find furnace', name)
		furnaces[name] = true
	end)

	parallel.waitForAny(pullEvents, function()
		while true do
			if not pcall(pullMaterialsFrom, chest) then
				sleep(1)
			end
		end
	end, function()
		while true do
			if not pcall(pushProductsTo, chest) then
				sleep(1)
			end
		end
	end)
end

main({...})
