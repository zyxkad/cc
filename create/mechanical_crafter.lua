-- Mechanical Crafter System (MCS)
-- by zyxkad@gmail.com

local crx = require('coroutinex')
local co_main = crx.main
local co_run = crx.run
local await = crx.await
local awaitAny = crx.awaitAny
--[[
wget run https://basalt.madefor.cc/install.lua packed
]]
local basalt = require('basalt')

local mechnicalCrafterId = 'create:mechanical_crafter'
local crafterType = 'create:mechanical_crafter'
local redstoneIntegratorType = 'redstoneIntegrator'
local blockReaderType = 'blockReader'

local crafters = {}
local recipes = {}
local inProgress = {}

local function printDebug(...)
	basalt.debug(...)
end

local function loadCrafter(crafter)
	if crafter.type == mechnicalCrafterId then
		assert(type(crafter.matrix) == 'table', 'crafter.matrix is not a table')
		assert(type(crafter.matrix.width) == 'number', 'crafter.matrix.width is not a number')
		assert(type(crafter.matrix.height) == 'number', 'crafter.matrix.height is not a number')
		assert(type(crafter.matrix.units) == 'table', 'crafter.matrix.units is not a list')
		assert(crafter.matrix.width * crafter.matrix.height == #crafter.matrix.units, 'number of units is not same as the size')
		crafters[#crafters + 1] = crafter
	end
end

local function loadCrafterDir(dir)
	for _, name in ipairs(fs.list(dir)) do
		if name:match('^[a-zA-Z0-9._-]+.json$') then
			local fd, err = fs.open(fs.combine(dir, name), 'r')
			if fd then
				local data = fd.readAll()
				fd.close()
				local crafter, err = textutils.unserialiseJSON(data)
				if crafter then
					loadCrafter(crafter)
				else
					printError(string.format('Cannot load %s: %s', name, err))
				end
			else
				printError(string.format('Cannot open %s: %s', name, err))
			end
		end
	end
end

local function loadRecipe(recipe)
	if recipe.type == 'mechanical_crafter' then
		recipes[recipe.output] = recipe
	end
end

local function loadRecipeDir(dir)
	for _, name in ipairs(fs.list(dir)) do
		local modid, item = name:match('^([a-z0-9_]+)%.([a-z0-9_]+).json$')
		if modid then
			local itemName = modid .. ':' .. item
			local fd, err = fs.open(fs.combine(dir, name), 'r')
			if fd then
				local data = fd.readAll()
				fd.close()
				local recipe, err = textutils.unserialiseJSON(data)
				if not recipe then
					error(string.format('Cannot load %s: %s', name, err), 0)
				end
				loadRecipe(recipe)
			else
				printError(string.format('Cannot open %s: %s', name, err))
			end
		end
	end
end

local itemTags = {}

local function getItemTags(inv, slot, name)
	local tags = itemTags[name]
	if tags then
		return tags
	end
	local detail = peripheral.call(inv, 'getItemDetail', slot)
	if not detail or detail.name ~= name then
		return nil
	end
	itemTags[name] = detail.tags
	return detail.tags
end

local listCaches = {}

local function findItemInInventory(inv, target)
	local list
	do
		local d = listCaches[inv]
		if d then
			if d.pending then
				list = await(d.pending)[1]
			elseif d.ttl > os.clock() then
				list = d.list
			end
		end
	end
	if not list then
		pending = co_run(peripheral.call, inv, 'list')
		listCaches[inv] = {
			pending = pending,
		}
		list = await(pending)[1]
		listCaches[inv] = {
			ttl = os.clock() + 1,
			list = list,
		}
	end
	if target.name then
		for slot, item in pairs(list) do
			if item.name == target.name and (target.nbt == false or item.nbt == target.nbt) then
				return slot, item
			end
		end
	end
	if target.tags then
		local result = nil
		local pendingItem = {}
		for slot, item in pairs(list) do
			if not pendingItem[item.name] then
				pendingItem[item.name] = co_run(function()
					local tags = getItemTags(inv, slot, item.name)
					if result then
						return
					end
					if tags then
						for _, t in ipairs(target.tags) do
							if tags[t] then
								result = slot
								return
							end
						end
					end
				end)
			end
		end
		awaitAny(function()
			local thrs = {}
			for _, thr in pairs(pendingItem) do
				thrs[#thrs + 1] = thr
			end
			await(table.unpack(thrs))
		end, function()
			while result == nil do
				crx.nextTick()
			end
		end)
		if result then
			return result, list[result]
		end
		result = false
	end
	return nil
end

local function transferItems(source, target, fromSlot, toSlot, limit)
	local count = peripheral.call(source, 'pushItems', target, fromSlot, limit, toSlot)
	printDebug('transferItems', source, fromSlot, target, toSlot, count)
	if count == 0 then
		return 0
	end
	do
		local d = listCaches[source]
		if d and d.list then
			local i = d.list[fromSlot]
			if i then
				i.count = i.count - count
				if i.count <= 0 then
					d.list[fromSlot] = nil
				end
			end
		end
	end
	if toSlot then
		local d = listCaches[target]
		if d and d.list then
			local i = d.list[toSlot]
			if i then
				i.count = i.count + count
			else
				d.ttl = 0
			end
		end
	end
	return count
end

local function onMaterialMissing(item)
	basalt.log('Missing ' .. item.name)
end

local function repeatFindItemInInventory(source, target)
	local slot, item = findItemInInventory(source, target)
	if not slot then
		onMaterialMissing(target)
		repeat
			crx.nextTick()
			slot, item = findItemInInventory(source, target)
		until slot
	end
	return slot, item
end

local function craft(crafter, recipe, sourceInv)
	local ri = redstone
	if crafter.triggerRI then
		ri = assert(peripheral.hasType(crafter.triggerRI, redstoneIntegratorType) and peripheral.wrap(crafter.triggerRI))
	end
	local blockReader = assert(peripheral.hasType(crafter.blockReader, blockReaderType) and peripheral.wrap(crafter.blockReader))

	local recipeWidth = #recipe.pattern[1]
	local recipeHeight = #recipe.pattern
	if recipeHeight > crafter.matrix.height then
		return false, 'RECIPE_TOO_LARGE'
	end
	if recipeWidth > crafter.matrix.width then
		return false, 'RECIPE_TOO_LARGE'
	end

	local pool = crx.newThreadPool(100)
	for y = 1, recipeHeight do
		for x = 1, recipeWidth do
			local itemAlias = recipe.pattern[y]:sub(x, x)
			local item = recipe.items[itemAlias]
			if item then
				local index = (y - 1) * crafter.matrix.width + x
				local unit = crafter.matrix.units[index]
				pool.queue(function()
					local slot
					repeat
						slot = repeatFindItemInInventory(sourceInv, item)
					until transferItems(sourceInv, unit, slot, 1, 1) > 0
				end)
			end
		end
	end
	pool.waitForAll()

	printDebug('start crafting')
	ri.setOutput(crafter.triggerSide, true)
	sleep(0.1)
	ri.setOutput(crafter.triggerSide, false)
	local d
	repeat
		crx.nextTick()
		if blockReader.getBlockName() ~= crafterType then
			return false, string.format('Target block is not a %s', crafterType)
		end
		d = blockReader.getBlockData()
		if not d then
			return false, 'Cannot read block data'
		end
	until d.Phase:upper() == 'IDLE'
	return true
end

local function craftRecipe(sourceInv, target, count)
	local recipe = recipes[target]
	if not recipe then
		return false, 'ERR_NO_RECIPE'
	end
	local crafter = nil
	printDebug('finding avaliable crafter')
	while true do
		for i, c in pairs(crafters) do
			if not c.crafting then
				printDebug('find crafter', i)
				crafter = c
				break
			end
		end
		if crafter then
			break
		end
		crx.nextTick()
	end
	crafter.crafting = recipe
	printDebug('start to craft', target)
	local ok, err = craft(crafter, recipe, sourceInv)
	printDebug('crafted', recipe.output, ok, err)
	crafter.crafting = nil
	return ok, err
end

---- BEGIN TUI ----

local mainFrame = basalt.createFrame()

local recipeList = mainFrame:addList()
	:setScrollable(true)
	:setSize(35, "parent.h - 6")
	:setPosition(3, 3)
	:setBackground(colors.gray)
	:setForeground(colors.white)
local craftCountInput = mainFrame:addInput()
	:setInputType("number")
	:setDefaultText("count", colors.gray, colors.white)
	:setPosition(39, 4)
	:setBackground(colors.white)
	:setForeground(colors.gray)
local craftButton = mainFrame:addButton()
	:setText("[Craft]")
	:setPosition(39, 6)

local function initTUI(sourceInv)
	local craftables = {}
	for name, _ in pairs(recipes) do
		craftables[#craftables + 1] = name
	end
	table.sort(craftables)
	recipeList:clear()
	for _, name in ipairs(craftables) do
		recipeList:addItem(name)
	end

	craftButton:onClick(function(self, event, btn)
		if event == 'mouse_click' and (btn == 1 or btn == 2) then
			local selected = recipeList:getItem(recipeList:getItemIndex())
			if selected then
				local target = selected.text
				local count = craftCountInput:getValue()
				if type(count) ~= 'number' or count <= 0 then
					count = btn == 2 and 16 or 1
				end
				count = math.floor(count + 0.5)
				printDebug('crafting', target, count)
				inProgress[target] = (inProgress[target] or 0) + count
				for t = 1, count do
					co_run(function()
						local ok, err = craftRecipe(sourceInv, target, count)
						if not ok then
							printDebug('craft failed', err)
						end
						inProgress[target] = inProgress[target] - 1
					end)
				end
			end
		end
	end)
end

---- END TUI ----

function main(args)
	local sourceInv = assert(args[1], 'The #1 argument must be source inventory')
	loadCrafterDir('crafters')
	loadRecipeDir('recipes')

	co_main(function()
		initTUI(sourceInv)
		basalt.autoUpdate()
	end)
end

main({...})
