-- Create mod potion factory
-- by zyxkad@gmail.com

if not parallel then
	error('Cannot found parallel API')
end

local RedstoneInterface = require('redstone_interface')

local basinId = 'basin'

local potionOut = nil
local cacheOut = nil
local cacheUsing = false
local loopUntilItemExists = true
local inventories = {}

do
	local fd = io.open('potion_factory.cfg', 'r')
	if not fd then
		local fd = io.open('potion_factory.cfg', 'w')
		fd:write(textutils.serialise({
			potionOut = '#N:front',
			cacheOut = '#N:front',
			loopUntilItemExists = true,
			inventories = {},
		}))
		fd:close()
		error('potion_factory.cfg is not exists')
	end
	local t = textutils.unserialise(fd:read('*all'))
	fd:close()
	potionOut = RedstoneInterface:createFromStr(nil, t['potionOut'])
	cacheOut = RedstoneInterface:createFromStr(nil, t['cacheOut'])
	loopUntilItemExists = t['loopUntilItemExists'] and true or false
	for _, v in ipairs(t['inventories']) do
		local p = peripheral.wrap(v)
		if p then
			inventories[#inventories + 1] = p
		else
			printError('WARN: cannot wrap '..v)
		end
	end
	if #inventories == 0 then
		error('No any inventories are useable')
	end
end

function importItem(name, item)
	while true do
		for _, inv in ipairs(inventories) do
			for i, d in pairs(inv.list()) do
				if d.name == item and d.count >= 1 then
					local amount = inv.pushItems(name, i, 1)
					if amount >= 1 then
						return amount
					end
				end
			end
		end
		if not loopUntilItemExists then
			return nil
		end
		sleep(0.1)
	end
	return nil
end

---- BEGIN Station ----

local Station = {
	int = nil, -- peripheral
	outTrigger = nil, -- RedstoneInterface
	inTrigger = nil, -- RedstoneInterface
	working = false, -- boolean
}

function Station:new(obj, int, outTrigger, inTrigger)
	if type(int) == 'string' then
		int = peripheral.wrap(int)
		if not int then
			error(string.format('Peripheral %s is not found', int))
		end
	end
	if peripheral.getType(int) ~= basinId then
		error(string.format('Unexpected type %s for %s, expect %s',
			peripheral.getType(int),
			peripheral.getName(int),
			basinId))
	end
	outTrigger:setOutput(true)
	if inTrigger then
		inTrigger:setOutput(true)
	end
	obj = obj or {}
	setmetatable(obj, { __index = self })
	obj.int = int
	obj.outTrigger = outTrigger
	obj.inTrigger = inTrigger
	obj.working = self.working
	return obj
end

function Station:createFromStr(obj, data)
	local args = {}
	for v in string.gmatch(data, "([^;]+)") do
		args[#args + 1] = v
	end
	local int, outTname, inTname = table.unpack(args)
	local outTrigger = RedstoneInterface:createFromStr(nil, outTname)
	local inTrigger = (inTname and #inTname ~= 0) and RedstoneInterface:createFromStr(nil, inTname) or nil
	return self:new(obj, int, outTrigger, inTrigger)
end

function Station:lock(wait)
	repeat
		if not self.working then
			self.working = true
			return true
		end
		if not wait then
			return false
		end
		sleep(0.1)
	until false
end

function Station:release()
	if not self.working then
		printError("WARN: station isn't working")
		return
	end
	self.working = false
end

function Station:mixWith(item)
	if not importItem(peripheral.getName(self.int), item) then
		return false, 'Cannot import item ['..item..']'
	end
	sleep(2)
	return true
end

function Station:exportLiquid()
	while cacheUsing do
		sleep(0.1)
	end
	cacheUsing = true
	self.outTrigger:setOutput(false)
	sleep(1.5)
	self.outTrigger:setOutput(true)
end

function Station:importLiquid()
	if not self.inTrigger then
		error('Station '..peripheral.getName(self.int)..' do not support import liquid')
	end
	if not cacheUsing then
		error('Cache is empty')
	end
	cacheOut:setOutput(true)
	self.inTrigger:setOutput(false)
	sleep(1)
	cacheOut:setOutput(false)
	self.inTrigger:setOutput(true)
	cacheUsing = false
end

---- END Station ----

local stations = {}
do
	local fd = io.open('potion_stations.cfg', 'r')
	if not fd then
		local fd = io.open('potion_stations.cfg', 'w')
		fd:write(textutils.serialise({
			water = 'basin_N;#P:bottom',
			awkward = 'basin_N;#P:bottom',
			'basin_N;#P:bottom;#Q:left'
		}))
		fd:close()
		error('potion_stations.cfg is not exists')
	end
	local t = textutils.unserialise(fd:read('*all'))
	fd:close()
	for k, v in pairs(t) do
		stations[k] = Station:createFromStr(nil, v)
	end
end

local waterStation = stations['water'] or nil
local awkwardStation = stations['awkward'] or nil

local function allocStation()
	while true do
		for _, station in ipairs(stations) do
			if station:lock() then
				return station
			end
		end
		sleep(0.1)
	end
end

---- BEGIN Potion ----

local longerItem = 'minecraft:redstone'
local strongerItem = 'minecraft:glowstone_dust'
local splashItem = 'minecraft:gunpowder'
local lingerItem = 'minecraft:dragon_breath'

local Potion = {
	prepared = false, -- boolean
	extra = nil, -- Potion
}

function Potion:new(obj)
	obj = obj or {}
	setmetatable(obj, { __index = self })
	return obj
end

function Potion:make(retStation)
	prerelease = prerelease or Station.exportLiquid
	if self.base.prepared then
		self.base.station:lock()
		self.base.station:mixWith(self.item)
		local station
		if retStation then
			station = allocStation()
		end
		self.base.station:exportLiquid()
		self.base.station:release()
		if retStation then
			return station
		end
	else
		local station = self.base:make(true)
		station:mixWith(self.item)
		station:exportLiquid()
		if retStation then
			return station
		end
		station:release()
	end
end

local potionMap = {}

local function potionRecipe(base, item, extra, info)
	if type(base) == 'string' then
		local base0 = potionMap[base]
		if not base0 then
			error('Potion id ['..base..'] not found')
		end
		base = base0
	end
	local potion = Potion:new({
		prepared = false,
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

local waterPotion = nil
if waterStation then
	waterPotion = Potion:new({
		prepared = true,
		station = waterStation,
	})
	potionMap['water'] = waterPotion
	printError('WARN: no water station is defined')
end

local awkwardPotion = nil
if awkwardStation then
	awkwardPotion = Potion:new({
		prepared = true,
		station = awkwardStation,
		extra = awkwardPotion,
	})
else
	if not waterPotion then
		error('You must give either awkwardStation or waterStation')
	end
	potionRecipe(waterPotion, 'minecraft:nether_wart')
end
potionMap['awkward'] = awkwardPotion

potionMap['night_vision'] = potionRecipe(awkwardPotion, 'minecraft:golden_carrot',
	nil, { nostronger=true })
potionMap['invisibility'] = potionRecipe('night_vision', 'minecraft:fermented_spider_eye',
	nil, { nostronger=true })
potionMap['jump_boost'] = potionRecipe(awkwardPotion, 'minecraft:rabbit_foot')
potionMap['fire_resistance'] = potionRecipe(awkwardPotion, 'minecraft:magma_cream',
	nil, { nostronger=true })
potionMap['speed'] = potionRecipe(awkwardPotion, 'minecraft:sugar')
potionMap['slowness'] = potionRecipe('speed', 'minecraft:fermented_spider_eye',
	potionRecipe('jump_boost', 'minecraft:fermented_spider_eye'))
potionMap['turtle_master'] = potionRecipe(awkwardPotion, 'minecraft:turtle_helmet')
potionMap['water_breathing'] = potionRecipe(awkwardPotion, 'minecraft:pufferfish',
	nil, { nostronger=true })
potionMap['instance_health'] = potionRecipe(awkwardPotion, 'minecraft:glistering_melon_slice',
	nil, { nolonger=true })
potionMap['poison'] = potionRecipe(awkwardPotion, 'minecraft:spider_eye')
potionMap['instance_damage'] = potionRecipe('poison', 'minecraft:fermented_spider_eye',
	potionRecipe('instance_health', 'minecraft:fermented_spider_eye'),
	{ nolonger=true })
potionMap['regeneration'] = potionRecipe(awkwardPotion, 'minecraft:ghast_tear')
potionMap['strength'] = potionRecipe(awkwardPotion, 'minecraft:blaze_powder')
if waterPotion then
	potionMap['weakness'] = potionRecipe(waterPotion, 'minecraft:fermented_spider_eye')
else
	printError('WARN: weakness potion must craft with water')
end
potionMap['slowfalling'] = potionRecipe(awkwardPotion, 'minecraft:phantom_membrane',
	nil, { nostronger=true })

---- END Potion ----

function makePotion(id, info)
	-- info = {
	-- 	longer = boolean,
	-- 	stronger = boolean,
	-- 	splash = boolean,
	-- 	linger = boolean,
	-- }
	local potion = potionMap[id]
	if not potion then
		error('Cannot found the recipe of potion ['..id..']')
	end
	info = info or {}
	if info.longer and info.stronger then
		error('Cannot make potion with both longer and stronger')
	end
	if info.longer and potion.nolonger then
		error("Potion don't have longer version")
	end
	if info.stronger and potion.nostronger then
		error("Potion don't have stronger version")
	end
	local needStation = info.longer or info.stronger or info.splash or info.linger
	local station = potion:make(needStation)
	if needStation then
		if info.longer then
			station:importLiquid()
			station:mixWith(longerItem)
			station:exportLiquid()
		end
		if info.stronger then
			station:importLiquid()
			station:mixWith(strongerItem)
			station:exportLiquid()
		end
		if info.splash or info.linger then
			station:importLiquid()
			station:mixWith(splashItem)
			station:exportLiquid()
		end
		if info.linger then
			station:importLiquid()
			station:mixWith(lingerItem)
			station:exportLiquid()
		end
		station:release()
	end

	-- output
	if not cacheUsing then
		error('Cache is empty')
	end
	potionOut:setOutput(true)
	sleep(1)
	potionOut:setOutput(false)
	cacheUsing = false
end


function main(args)
	makePotion('speed', { longer = true, splash = true })
	if true then return end
	function render()
		while true do
			sleep(0.2)
		end
	end
	function update()
		while true do
			sleep(0.1)
		end
	end
	parallel.waitForAny(
		render,
		update)
end

main({...})
