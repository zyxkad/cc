-- Miner Systerm Scanner
-- by zyxkad@gmail.com

local dictionary = {
	['#minecraft:block/forge:ores/coal'] = {
		value = 1,
	},
	['#minecraft:block/forge:ores/copper'] = {
		value = 1,
	},
	['#minecraft:block/forge:ores/lapis'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/zinc'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/tin'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/sulfur'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/nickel'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/lead'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/iron'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/silver'] = {
		value = 2,
	},
	['#minecraft:block/forge:ores/gold'] = {
		value = 3,
	},
	['#minecraft:block/forge:ores/redstone'] = {
		value = 3,
	},
	['#minecraft:block/forge:ores/emerald'] = {
		value = 3,
	},
	['#minecraft:block/forge:ores/osmium'] = {
		value = 3,
	},
	['#minecraft:block/forge:ores/diamond'] = {
		value = 4,
	},
	['#minecraft:block/forge:ores/netherite_scrap'] = {
		value = 8,
	},
	['#minecraft:block/forge:ores/quartz'] = {
		value = 2,
	},
	['minecraft:glowstone'] = {
		value = 1,
	},
	['minecraft:sponge'] = {
		value = 8,
	},
	['minecraft:wet_sponge'] = {
		value = 8,
	},

	['minecraft:ancient_debris'] = '#minecraft:block/forge:ores/netherite_scrap',
}

local function parseBlock(blk)
	if blk.name == 'minecraft:air' then
		return NIL_TABLE
	end
	local b = dictionary[blk.name]
	if type(b) == 'string' then
		b = dictionary[b]
	end
	if b then
		return b
	end
	if blk.name:match('_log$') then
		b = dictionary['#minecraft:block/minecraft:logs']
	elseif blk.name:match('coal_ore$') then
		b = dictionary['#minecraft:block/forge:ores/coal']
	elseif blk.name:match('copper_ore$') then
		b = dictionary['#minecraft:block/forge:ores/copper']
	elseif blk.name:match('iron_ore$') then
		b = dictionary['#minecraft:block/forge:ores/iron']
	elseif blk.name:match('gold_ore$') then
		b = dictionary['#minecraft:block/forge:ores/gold']
	elseif blk.name:match('redstone_ore$') then
		b = dictionary['#minecraft:block/forge:ores/redstone']
	elseif blk.name:match('emerald_ore$') then
		b = dictionary['#minecraft:block/forge:ores/emerald']
	elseif blk.name:match('lapis_ore$') then
		b = dictionary['#minecraft:block/forge:ores/lapis']
	elseif blk.name:match('diamond_ore$') then
		b = dictionary['#minecraft:block/forge:ores/diamond']
	elseif blk.name:match('quartz_ore$') then
		b = dictionary['#minecraft:block/forge:ores/quartz']
	elseif blk.tags then
		for _, t in ipairs(blk.tags) do
			b = dictionary['#'..t]
			if b then
				return b
			end
		end
		for _, t in ipairs(blk.tags) do
			b = fallbackDict['#'..t]
			if b then
				return b
			end
		end
	end
	return b or NIL_TABLE
end

local function digToTop()
	print('Returning to top')
	while true do
		while not turtle.up() do
			local ok, blk = turtle.inspectUp()
			if not ok then
				assert(turtle.up())
				break
			end
			if blk.name == 'computercraft:turtle' then
				print('Returned')
				return
			end
			assert(turtle.digUp())
		end
	end
end

local function digDown()
	while not turtle.down() do
		if not turtle.detectDown() then
			assert(turtle.down())
			break
		end
		assert(turtle.digDown())
	end
end

local SCAN_RADIUS = 8

local function scan()
	local scanner = assert(peripheral.wrap('left'), 'No scanner found on the left side')
	assert(scanner.scan, 'No scanner found on the left side')

	print('Scanning ...')
	local y = 0
	local ores = {}
	while true do
		local data = scanner.scan()
		for _, block in ipaifs(data) do
			local d = parseBlock(block.name)
			if d then
				ores[#ores + 1] = {
					name = block.name,
					x = block.x,
					y = block.y - y,
					z = block.z,
				}
			end
		end
		for i = 1, SCAN_RADIUS * 2 do
			y = y + 1
			digDown()
		end
	end
	return ores
end

function main()
	while true do
		repeat sleep(0) until redstone.getInput('top')
		local ores = scan()
		digToTop()
		local oreStr = textutils.seralizeJSON(ores)
		print('ores:', oreStr)
		print(#ores)
	end
end

main(...)
