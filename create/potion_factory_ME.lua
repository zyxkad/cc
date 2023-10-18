-- Create mod potion factory for me system
-- by zyxkad@gmail.com

local RedstoneInterface = require('redstone_interface')

local basinId = 'basin'

local inputInventory = nil
local outputValve = nil
local secondValve = nil
local extentValve = nil -- Unused now
local extentBasin = nil
local doneTrigger = nil
local mixTime = 3

do
	local fd = io.open('potion_factory.cfg', 'r')
	if not fd then
		local fd = io.open('potion_factory.cfg', 'w')
		fd:write(textutils.serialise({
			inputInventory = 'minecraft:barrel_N',
			outputValve = '#N:front',
			workBasin = 'basin_N',
			secondValve = '#N:front',
			extentValve = '#N:front',
			extentBasin = 'basin_N',
			doneTrigger = '#N:front',
			mixTime = 3,
		}))
		fd:close()
		error('potion_factory.cfg is not exists, creating...', 0)
	end
	local t = textutils.unserialise(fd:read('*all'))
	fd:close()
	inputInventory = peripheral.wrap(t['inputInventory'])
	assert(inputInventory, string.format('inputInventory(%s) is not exists', t['inputInventory']))
	assert(inputInventory.list and inputInventory.pushItems,
		string.format('inputInventory(%s) is not a normal inventory', t['inputInventory']))
	outputValve = RedstoneInterface:createFromStr(nil, t['outputValve'])
	workBasin = peripheral.wrap(t['workBasin'])
	assert(workBasin, string.format('workBasin(%s) is not exists', t['workBasin']))
	assert(peripheral.getType(workBasin) == 'basin', string.format('workBasin(%s) is not a basin', t['workBasin']))
	secondValve = RedstoneInterface:createFromStr(nil, t['secondValve'])
	-- extentValve = RedstoneInterface:createFromStr(nil, t['extentValve'])
	-- extentBasin = peripheral.wrap(t['extentBasin'])
	doneTrigger = RedstoneInterface:createFromStr(nil, t['doneTrigger'])
	mixTime = t['mixTime']
end

function importItem(name, item)
	for i, d in pairs(inputInventory.list()) do
		if d.name == item and d.count >= 1 then
			local amount = inputInventory.pushItems(name, i, 1)
			if amount >= 1 then
				return amount
			end
		end
	end
	return nil
end

---- BEGIN Potion ----

local longerSalt = 'minecraft:redstone'
local strongerSalt = 'minecraft:glowstone_dust'
local splashSalt = 'minecraft:gunpowder'
local lingerSalt = 'minecraft:dragon_breath'

local Potion = {
	base = nil, -- Potion, string or nil
	item = nil, -- string: item id
	extra = nil, -- Potion or nil
	nolonger = false,
	nostronger = false,
}

function Potion:new(obj)
	obj = obj or {}
	setmetatable(obj, { __index = self })
	return obj
end

local function copyListSkipIndex(tb, ind)
	local newt = {}
	for i, item in ipairs(tb) do
		if i ~= ind then
			newt[#newt + 1] = item
		end
	end
	return newt
end

local function tryRemoveItem(items, name)
	for i, item in ipairs(items) do
		if item.name == name then
			return copyListSkipIndex(items, i)
		end
	end
	return nil
end

function Potion:tryRecipe(items)
	local nlist = tryRemoveItem(items, self.item)
	if nlist then
		if self.base == 'awkward' then
			if #nlist == 0 then
				return true
			end
		else
			if self.base:tryRecipe(nlist) then
				return true
			end
		end
	end
	if self.extra then
		return self.extra:tryRecipe(items)
	end
	return false
end

local function mixWithItem(name)
	importItem(peripheral.getName(workBasin), name)
	sleep(mixTime)
end

function Potion:putItems()
	if self.base ~= 'awkward' then
		self.base:putItems()
	end
	mixWithItem(self.item)
end

local potionMap = {}

local function potionRecipe(base, item, info, extra)
	if type(base) == 'string' then
		if base ~= 'awkward' then
			local base0 = potionMap[base]
			if not base0 then
				error('Potion id ['..base..'] not found')
			end
			base = base0
		end
	end
	local potion = Potion:new({
		base = base,
		item = item,
		extra = extra,
	})
	if info then
		if info.nolonger then
			potion.nolonger = true
		end
		if info.nostronger then
			potion.nostronger = true
		end
	end
	return potion
end

potionMap['night_vision'] = potionRecipe('awkward', 'minecraft:golden_carrot', { nostronger=true })
potionMap['invisibility'] = potionRecipe('night_vision', 'minecraft:fermented_spider_eye', { nostronger=true })
potionMap['jump_boost'] = potionRecipe('awkward', 'minecraft:rabbit_foot')
potionMap['fire_resistance'] = potionRecipe('awkward', 'minecraft:magma_cream', { nostronger=true })
potionMap['speed'] = potionRecipe('awkward', 'minecraft:sugar')
potionMap['slowness'] = potionRecipe('speed', 'minecraft:fermented_spider_eye',
	potionRecipe('jump_boost', 'minecraft:fermented_spider_eye'))
potionMap['turtle_master'] = potionRecipe('awkward', 'minecraft:turtle_helmet')
potionMap['water_breathing'] = potionRecipe('awkward', 'minecraft:pufferfish', { nostronger=true })
potionMap['instance_health'] = potionRecipe('awkward', 'minecraft:glistering_melon_slice', { nolonger=true })
potionMap['poison'] = potionRecipe('awkward', 'minecraft:spider_eye')
potionMap['instance_damage'] = potionRecipe('poison', 'minecraft:fermented_spider_eye', { nolonger=true },
	potionRecipe('instance_health', 'minecraft:fermented_spider_eye'))
potionMap['regeneration'] = potionRecipe('awkward', 'minecraft:ghast_tear')
potionMap['strength'] = potionRecipe('awkward', 'minecraft:blaze_powder')
potionMap['slowfalling'] = potionRecipe('awkward', 'minecraft:phantom_membrane', { nostronger=true })

---- END Potion ----

local function tryPotions(items)
	for id, potion in pairs(potionMap) do
		if potion:tryRecipe(items) then
			return potion, id
		end
	end
	return nil
end

local function reset()
	outputValve:setOutput(false)
	secondValve:setOutput(false)
	-- extentValve:setOutput(false)
end

function main(args)
	while true do
		reset()

		local items
		repeat items = inputInventory.list() until #items > 0
		local nlist
		local longer = false
		nlist = tryRemoveItem(items, longerSalt)
		if nlist then longer = true; items = nlist end
		local stronger = false
		nlist = tryRemoveItem(items, strongerSalt)
		if nlist then stronger = true; items = nlist end
		local splash = false
		nlist = tryRemoveItem(items, splashSalt)
		if nlist then splash = true; items = nlist end
		local linger = false
		nlist = tryRemoveItem(items, lingerSalt)
		if nlist then linger = true; items = nlist end

		local potion, potionid = tryPotions(items)
		if not potion then
			error('[ERR] no match potions', 0)
		end

		if longer and potion.nolonger then
			error(string.format('Potion [%s] do not have a longer version', potionid), 0)
		end

		if stronger and potion.nostronger then
			error(string.format('Potion [%s] do not have a stronger version', potionid), 0)
		end

		print('Making ['..potionid..']')
		potion:putItems()
		if longer then
			mixWithItem(longerSalt)
		end
		if stronger then
			mixWithItem(strongerSalt)
		end
		if splash then
			mixWithItem(splashSalt)
		end
		if linger then
			mixWithItem(lingerSalt)
		end
		outputValve:setOutput(true)
		secondValve:setOutput(true)
		repeat sleep(0) until doneTrigger:getInput()
		repeat sleep(0) until not doneTrigger:getInput()
		print('Done for make ['..potionid..']')
	end
end

local ok, res = pcall(main({...}))
if not ok then
	printError(res)
	print('Press any key to exit')
	os.pullEvent('char')
	return false
end
return res
