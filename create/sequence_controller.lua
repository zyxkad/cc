-- Create Sequence Recipe Controller
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

local DEBUG = true
local printDebug
if DEBUG then
	local debugLogFd = assert(fs.open('seq.debug.log', 'w'))
	printDebug = function(...)
		if not debugLogFd then
			return
		end
		local line = string.format('%.02f', os.clock())
		local vals = table.pack(...)
		for i = 1, vals.n do
			local v = vals[i]
			if type(v) == 'table' then
				local ok, w = pcall(textutils.serialize, v, { compact = true, allow_repetitions = true })
				if ok then
					v = w
				end
			end
			line = line .. ' ' .. tostring(v)
		end
		debugLogFd.write(line)
		debugLogFd.write('\n')
		debugLogFd.flush()
	end
else
	printDebug = function(...) end
end

-- crafters

local mechanicalPressDepotType = 'create:depot'
local deployerType = 'create:deployer'
local deployerDepotType = 'create:depot'
local spoutType = 'create:spout'
local spoutDepotType = 'create:depot'

local pressCrafterId = 'create:press'
local spoutCrafterId = 'create:spout'
local deployerCrafterId = 'create:deployer'

local mechanicalPresses = {} -- { [depot: string]: { processing: table } }
local deployers = {} -- { [depot: string]: { deployer: string, processing: table } }
local spouts = {} -- { [depot: string]: { spout: string, processing: table } }

local recipes = {} --[[
{
	[output: string] = {
		type = 'sequence',
		initItem: {
			name: string,
			nbt: string | false | nil,
		} | {
			tags: [tag: string ...],
		},
		repeats: number | nil,
		stages: [{
			crafter: string = <crafter type>,
			operators: {
				[operator: string]: {
					name: string,
					nbt: string | false | nil,
					reusable: boolean | nil,
				} | {
					tags: [tag: string ...],
				} | {
					fluid: string,
					amount: number,
				},
			}
		}...],
		output: string,
	}
}
]]
local inProgress = {}

local function tableCount(t)
	local count = 0
	for _, _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function loadCrafter(crafter)
	if crafter.type == pressCrafterId then
		if peripheral.hasType(crafter.name, mechanicalPressDepotType) then
			mechanicalPresses[crafter.name] = {}
			return true
		end
	elseif crafter.type == deployerCrafterId then
		if peripheral.hasType(crafter.name, deployerDepotType) and peripheral.hasType(crafter.deployer, deployerType) then
			deployers[crafter.name] = {
				deployer = crafter.deployer,
			}
			return true
		end
	elseif crafter.type == spoutCrafterId then
		if peripheral.hasType(crafter.name, spoutDepotType) and peripheral.hasType(crafter.spout, spoutType) then
			spouts[crafter.name] = {
				spout = crafter.spout,
			}
			return true
		end
	end
	return false
end

local function loadCrafterDir(dir)
	for _, name in ipairs(fs.list(dir)) do
		if name:match('^[a-zA-Z0-9._-]+.json$') then
			local fd, err = fs.open(fs.combine(dir, name), 'r')
			if fd then
				local data = fd.readAll()
				fd.close()
				local crafter = textutils.unserialiseJSON(data)
				loadCrafter(crafter)
			else
				printError(string.format('Cannot open %s: %s', name, err))
			end
		end
	end
end

local function addCrafter(dir, crafter)
	if not loadCrafter(crafter) then
		error('Unexpected crafter type ' .. crafter.type .. ' or imcomplete data')
	end
	local name = crafter.name:gsub(':', '.') .. '.json'
	local fd = assert(fs.open(fs.combine(dir, name), 'w'))
	fd.write(textutils.serialiseJSON(crafter))
	fd.close()
end

local function loadRecipe(recipe)
	if recipe.type == 'sequence' then
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
local tankCaches = {}

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
					for _, t in ipairs(target.tags) do
						if tags[t] then
							result = slot
							return
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

local function getTankInfo(tank)
	local name = peripheral.getName(tank)
	local info
	do
		local d = tankCaches[name]
		if d then
			if d.pending then
				local res = await(d.pending)
				info = res[1]
			elseif d.ttl > os.clock() then
				info = d.info
			end
		end
	end
	if not info then
		pending = co_run(tank.getInfo)
		tankCaches[name] = {
			pending = pending,
		}
		info = await(pending)
		tankCaches[name] = {
			ttl = os.clock() + 1,
			info = info[1],
		}
	end
	return info
end

local function findFluidInTanks(fluid, amount)
	local result = nil
	local thrs = {}
	for i, tank in ipairs({peripheral.find('fluidTank')}) do
		thrs[i] = co_run(function()
			if result then
				return
			end
			local info = getTankInfo(tank)
			if info.amount > amount and info.fluid == fluid then
				result = peripheral.getName(tank)
			end
		end)
	end
	await(table.unpack(thrs))
	return result
end

local function transferFluid(source, target, limit, fluid)
	local amount
	if peripheral.hasType(source, 'fluidTank') then
		amount = peripheral.call(target, 'pullFluid', source, limit, fluid)
	else
		amount = peripheral.call(source, 'pushFluid', target, limit, fluid)
	end
	if amount == 0 then
		return 0
	end
	do
		local d = tankCaches[source]
		if d and d.info then
			local i = d.info
			if i then
				i.amount = i.amount - amount
				if i.amount <= 0 then
					d.info[fromSlot] = nil
				end
			end
		end
	end
	if toSlot then
		local d = tankCaches[target]
		if d and d.info then
			local i = d.info
			if i then
				i.amount = i.amount + amount
			else
				d.ttl = 0
			end
		end
	end
	return amount
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

--- allocCPU will alloc a craft processing unit and start to process the stage
local function allocCPU(stage, source, last, item)
	last = last or source
	if stage.crafter == pressCrafterId then
		local name, data = nil, nil
		for n, d in pairs(mechanicalPresses) do
			if not d.processing then
				name, data = n, d
				break
			end
		end
		if not name then
			return false, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		if transferItems(last, name, item.slot, 1, 1) == 0 then
			data.processing = nil
			return false, 'ERR_LAST_EMPTY'
		end
		return true, name, data.processing
	elseif stage.crafter == deployerCrafterId then
		local name, data = nil, nil
		for n, d in pairs(deployers) do
			if not d.processing then
				name, data = n, d
				break
			end
		end
		if not name then
			return false, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		local err = nil
		local _, res = await(function()
			if transferItems(last, name, item.slot, 1, 1) == 0 then
				err = 'ERR_LAST_EMPTY'
			end
		end, function()
			while not err do
				local deployerItemSlot = findItemInInventory(source, stage.operators.deployer)
				if not deployerItemSlot then
					return false
				end
				if err then
					break
				end
				if transferItems(source, data.deployer, deployerItemSlot, 1, 1) > 0 then
					return true
				end
			end
		end)
		if err then
			data.processing = nil
			return false, err
		end
		if not res[1] then
			-- push back the materials
			await(
				co_run(transferItems, name, last, 1),
				co_run(transferItems, data.deployer, source, 1)
			)
			data.processing = nil
			return false, 'ITEM_MISSING', stage.operators.deployer
		end
		return true, name, data.processing
	elseif stage.crafter == spoutCrafterId then
		local name, data = nil, nil
		for n, d in pairs(spouts) do
			if not d.processing then
				name, data = n, d
				break
			end
		end
		if not name then
			return false, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		local spoutFluid = stage.operators.spout
		local err = nil
		local _, res = await(function()
			if transferItems(last, name, item.slot, 1, 1) == 0 then
				err = 'ERR_LAST_EMPTY'
			end
		end, function()
			local sourceTank = findFluidInTanks(spoutFluid.fluid, spoutFluid.amount)
			if not sourceTank then
				return false
			end
			local needAmount = spoutFluid.amount
			repeat
				needAmount = needAmount - transferFluid(sourceTank, data.spout, needAmount, spoutFluid.fluid)
			until needAmount <= 0
			return true
		end)
		if err then
			data.processing = nil
			return false, err
		end
		if not res[1] then
			-- push back the base material
			await(
				co_run(transferItems, name, last, 1, 1),
				co_run(transferFluid, data.spout, sourceTank)
			)
			data.processing = nil
			return false, 'ITEM_MISSING', stage.operators.deployer
		end
		return true, name, data.processing
	else
		error('Unexpected crafter type ' .. stage.crafter)
	end
end

local function releaseCPU(name)
	local data = mechanicalPresses[name] or deployers[name] or spouts[name]
	if data then
		data.processing = nil
	end
end

local function craftRecipe(source, targetInv, target)
	local recipe = recipes[target]
	if not recipe then
		return 0, 'recipe not found'
	end
	local lastStage, lastCrafter, processing
	local repeats = recipe.repeats or 1
	for t = 1, repeats do
		for i, stage in ipairs(recipe.stages) do
			if lastCrafter and processing then
				printDebug('waiting change', t, i)
				local current
				repeat
					current = peripheral.call(lastCrafter, 'getItemDetail', 1)
				until processing.name ~= current.name or processing.nbt ~= current.nbt
				printDebug('found change, from', processing, 'to', current)
				processing = current
			end
			if lastStage and lastStage.crafter == deployerCrafterId then
				local data = assert(deployers[lastCrafter])
				if lastStage.operators.deployer.reusable then
					printDebug('returning reusable tool')
					transferItems(data.deployer, source, 1)
				else
					transferItems(data.deployer, targetInv, 1)
				end
			end
			if lastStage and lastStage.crafter == stage.crafter then
				printDebug('same crafter for', stage)
				if stage.crafter == deployerCrafterId then
					local data = deployers[lastCrafter]
					local deployerItem = stage.operators.deployer
					printDebug('finding deployer item', deployerItem)
					repeat
						local deployerItemSlot = repeatFindItemInInventory(source, deployerItem)
					until transferItems(source, data.deployer, deployerItemSlot, 1, 1) > 0
				elseif stage.crafter == spoutCrafterId then
					local data = assert(spouts[lastCrafter])
					local spoutFluid = stage.operators.spout
					printDebug('finding', spoutFluid)
					local sourceTank
					repeat
						sourceTank = findFluidInTanks(spoutFluid.fluid, spoutFluid.amount)
					until sourceTank
					local needAmount = spoutFluid.amount
					repeat
						needAmount = needAmount - transferFluid(sourceTank, data.spout, needAmount, spoutFluid.fluid)
					until needAmount <= 0
				end
			else
				local firstIter = t == 1 and i == 1
				if firstIter then
					local slot, item2 = repeatFindItemInInventory(source, recipe.initItem)
					item2.slot = slot
					processing = item2
					printDebug('found', item2, 'at', slot)
				end
				local ok, name, item = allocCPU(stage, source, lastCrafter, processing)
				if not ok then
					if name == 'ITEM_MISSING' then
						onMaterialMissing(item)
					end
					repeat
						crx.nextTick()
						if firstIter and name == 'ERR_LAST_EMPTY' then
							local slot, item2 = repeatFindItemInInventory(source, recipe.initItem)
							item2.slot = slot
							processing = item2
							printDebug('found', item2, 'at', slot, os.clock())
						end
						printDebug('allocing CPU')
						ok, name, item = allocCPU(stage, source, lastCrafter, processing)
						printDebug('alloced', ok, name, item, os.clock())
					until ok
				end
				if lastCrafter then
					releaseCPU(lastCrafter)
				end
				lastCrafter = name
				processing = item.item
			end
			lastStage = stage
		end
	end
	if lastCrafter then
		if processing then
			local current
			repeat
				current = peripheral.call(lastCrafter, 'getItemDetail', 1)
			until processing.name ~= current.name or processing.nbt ~= current.nbt
			processing = current
		end
		if lastStage and lastStage.crafter == deployerCrafterId then
			local data = assert(deployers[lastCrafter])
			if lastStage.operators.deployer.reusable then
				printDebug('returning reusable tool')
				transferItems(data.deployer, source, 1)
			else
				transferItems(data.deployer, targetInv, 1)
			end
		end
		peripheral.call(targetInv, 'pullItems', lastCrafter, 1)
		releaseCPU(lastCrafter)
	end
	return 1
end

---- BEGIN TUI ----

local mainFrame = basalt.createFrame()

local statsFrame = mainFrame:addFrame()
	:setPosition(3, 3)
	:setBackground(false)
	:setForeground(false)

local pressCountLabel = statsFrame:addLabel()
	:setText("Presses   %d")
	:setPosition(1, 1)
local deployerCountLabel = statsFrame:addLabel()
	:setText("Deployers %d")
	:setPosition(1, 2)
local spoutCountLabel = statsFrame:addLabel()
	:setText("Spouts    %d")
	:setPosition(1, 3)
local recipeCountLabel = statsFrame:addLabel()
	:setText("Total %d recipes")
	:setPosition(1, 4)

local addBtnsFrame = mainFrame:addFrame()
	:setSize(21, 5)
	:setPosition("parent.w - 22", 2)
	:setBackground(colors.gray)
	:setForeground(colors.white)
local addCreatePressBtn = addBtnsFrame:addButton()
	:setText("Add create:press   ")
	:setSize(21, 1)
	:setPosition(1, 2)
	:setBackground(false)
	:setForeground(false)
local addCreateDeployerBtn = addBtnsFrame:addButton()
	:setText("Add create:deployer")
	:setSize(21, 1)
	:setPosition(1, 3)
	:setBackground(false)
	:setForeground(false)
local addCreateSpoutBtn = addBtnsFrame:addButton()
	:setText("Add create:spout   ")
	:setSize(21, 1)
	:setPosition(1, 4)
	:setBackground(false)
	:setForeground(false)

local addCreatePressFrame = mainFrame:addFrame()
	:setSize("parent.w - 6", "parent.h - 3")
	:setPosition(4, 2)
	:setVisible(false)
	:setZIndex(999)
addCreatePressFrame:addLabel()
	:setText("Select press depot")
	:setSize(25, 1)
	:setPosition(3, 3)
local addCreatePressDepotList = addCreatePressFrame:addList()
	:setScrollable(true)
	:setSize(25, "parent.h - 6")
	:setPosition(3, 4)
	:setBackground(colors.lightGray)
	:setForeground(colors.white)
local addCreatePressConfirmBtn = addCreatePressFrame:addButton()
	:setText("[Confirm]")
	:setSize(9, 1)
	:setPosition(7, "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.green)
local addCreatePressCancelBtn = addCreatePressFrame:addButton()
	:setText("[Cancel]")
	:setSize(8, 1)
	:setPosition("parent.w - 8 - 7", "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.red)

local addCreateDeployerFrame = mainFrame:addFrame()
	:setSize("parent.w - 6", "parent.h - 3")
	:setPosition(4, 2)
	:setVisible(false)
	:setZIndex(999)
addCreateDeployerFrame:addLabel()
	:setText("Select depot")
	:setSize(18, 1)
	:setPosition(3, 3)
local addCreateDeployerDepotList = addCreateDeployerFrame:addList()
	:setScrollable(true)
	:setSize(18, "parent.h - 6")
	:setPosition(3, 4)
	:setBackground(colors.lightGray)
	:setForeground(colors.white)
addCreateDeployerFrame:addLabel()
	:setText("Select deployer")
	:setSize(22, 1)
	:setPosition(22, 3)
local addCreateDeployerList = addCreateDeployerFrame:addList()
	:setScrollable(true)
	:setSize(22, "parent.h - 6")
	:setPosition(22, 4)
	:setBackground(colors.lightGray)
	:setForeground(colors.white)
local addCreateDeployerConfirmBtn = addCreateDeployerFrame:addButton()
	:setText("[Confirm]")
	:setSize(9, 1)
	:setPosition(7, "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.green)
local addCreateDeployerCancelBtn = addCreateDeployerFrame:addButton()
	:setText("[Cancel]")
	:setSize(8, 1)
	:setPosition("parent.w - 8 - 7", "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.red)

local addCreateSpoutFrame = mainFrame:addFrame()
	:setSize("parent.w - 6", "parent.h - 3")
	:setPosition(4, 2)
	:setVisible(false)
	:setZIndex(999)
addCreateSpoutFrame:addLabel()
	:setText("Select depot")
	:setSize(18, 1)
	:setPosition(3, 3)
local addCreateSpoutDepotList = addCreateSpoutFrame:addList()
	:setScrollable(true)
	:setSize(18, "parent.h - 6")
	:setPosition(3, 4)
	:setBackground(colors.lightGray)
	:setForeground(colors.white)
addCreateSpoutFrame:addLabel()
	:setText("Select spout")
	:setSize(22, 1)
	:setPosition(22, 3)
local addCreateSpoutList = addCreateSpoutFrame:addList()
	:setScrollable(true)
	:setSize(22, "parent.h - 6")
	:setPosition(22, 4)
	:setBackground(colors.lightGray)
	:setForeground(colors.white)
local addCreateSpoutConfirmBtn = addCreateSpoutFrame:addButton()
	:setText("[Confirm]")
	:setSize(9, 1)
	:setPosition(7, "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.green)
local addCreateSpoutCancelBtn = addCreateSpoutFrame:addButton()
	:setText("[Cancel]")
	:setSize(8, 1)
	:setPosition("parent.w - 8 - 7", "parent.h - 1")
	:setBackground(false)
	:setForeground(colors.red)

local recipeList = mainFrame:addList()
	:setScrollable(true)
	:setSize(35, "parent.h - 9")
	:setPosition(3, 8)
	:setBackground(colors.gray)
	:setForeground(colors.white)
local craftCountInput = mainFrame:addInput()
	:setInputType("number")
	:setDefaultText("count", colors.gray, colors.white)
	:setPosition(39, 10)
	:setBackground(colors.white)
	:setForeground(colors.gray)
local craftButton = mainFrame:addButton()
	:setText("[Craft]")
	:setPosition(39, 12)

local function isPeripheralRegistered(name)
	if mechanicalPresses[name] or deployers[name] or spouts[name] then
		return true
	end
	for _, data in pairs(deployers) do
		if data.deployer == name then
			return true
		end
	end
	for _, data in pairs(spouts) do
		if data.spout == name then
			return true
		end
	end
	return false
end

local function initTUI(crafterDir, recipeDir, sourceInv, targetInv)
	local function refreshCountLabels()
		recipeCountLabel:setText(string.format("%d recipes", tableCount(recipes)))
		pressCountLabel:setText(string.format("Presses   %d", tableCount(mechanicalPresses)))
		deployerCountLabel:setText(string.format("Deployers %d", tableCount(deployers)))
		spoutCountLabel:setText(string.format("Spouts    %d", tableCount(spouts)))
	end
	refreshCountLabels()

	addCreatePressBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreatePressDepotList:clear()
			peripheral.find(mechanicalPressDepotType, function(name)
				if not isPeripheralRegistered(name) then
					addCreatePressDepotList:addItem(name)
				end
			end)
			addCreatePressFrame:setVisible(true)
		end
	end)
	addCreatePressConfirmBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			local index = addCreatePressDepotList:getItemIndex()
			local item = addCreatePressDepotList:getItem(index)
			if item then
				addCrafter(crafterDir, {
					type = pressCrafterId,
					name = item.text,
				})
				refreshCountLabels()
			end
			addCreatePressFrame:setVisible(false)
		end
	end)
	addCreatePressCancelBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreatePressFrame:setVisible(false)
		end
	end)

	addCreateDeployerBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreateDeployerDepotList:clear()
			addCreateDeployerList:clear()
			peripheral.find(deployerDepotType, function(name)
				if not isPeripheralRegistered(name) then
					addCreateDeployerDepotList:addItem(name)
				end
			end)
			peripheral.find(deployerType, function(name)
				if not isPeripheralRegistered(name) then
					addCreateDeployerList:addItem(name)
				end
			end)
			addCreateDeployerFrame:setVisible(true)
		end
	end)
	addCreateDeployerConfirmBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			local deployer = addCreateDeployerList:getItem(addCreateDeployerList:getItemIndex())
			local deployerDepot = addCreateDeployerDepotList:getItem(addCreateDeployerDepotList:getItemIndex())
			if deployer and deployerDepot then
				addCrafter(crafterDir, {
					type = deployerCrafterId,
					name = deployerDepot.text,
					deployer = deployer.text,
				})
				refreshCountLabels()
			end
			addCreateDeployerFrame:setVisible(false)
		end
	end)
	addCreateDeployerCancelBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreateDeployerFrame:setVisible(false)
		end
	end)

	addCreateSpoutBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreateSpoutDepotList:clear()
			addCreateSpoutList:clear()
			peripheral.find(spoutDepotType, function(name)
				if not isPeripheralRegistered(name) then
					addCreateSpoutDepotList:addItem(name)
				end
			end)
			peripheral.find(spoutType, function(name)
				if not isPeripheralRegistered(name) then
					addCreateSpoutList:addItem(name)
				end
			end)
			addCreateSpoutFrame:setVisible(true)
		end
	end)
	addCreateSpoutConfirmBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			local spout = addCreateSpoutList:getItem(addCreateSpoutList:getItemIndex())
			local spoutDepot = addCreateSpoutDepotList:getItem(addCreateSpoutDepotList:getItemIndex())
			if spout and spoutDepot then
				addCrafter(crafterDir, {
					type = spoutCrafterId,
					name = spoutDepot.text,
					spout = spout.text,
				})
				refreshCountLabels()
			end
			addCreateSpoutFrame:setVisible(false)
		end
	end)
	addCreateSpoutCancelBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreateSpoutFrame:setVisible(false)
		end
	end)

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
						local ok, err = craftRecipe(sourceInv, targetInv, target, count)
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

--- renderTUI render the UI
local function renderTUI()
	basalt.autoUpdate()
end

--- pullEvents handle events
local function pullEvents()
	local event, p1, p2, p3 = os.pullEvent()
	if event == 'peripheral' then
	elseif event == 'peripheral_detach' then
	end
end

local function update()

end

function main(args)
	local crafterDiskId = assert(args[1] and tonumber(args[1]), 'the #1 argument must be crafter disk id')
	local recipeDiskId = assert(args[2] and tonumber(args[2]), 'the #2 argument must be recipe disk id')
	local inputName = assert(peripheral.hasType(args[3], 'inventory') and args[3], 'the #3 argument must be name of the input inventory')
	local outputName = assert(peripheral.hasType(args[4], 'inventory') and args[4], 'the #4 argument must be name of the output inventory')
	local crafterDiskDrive = assert(peripheral.find('drive', function(_, drive) return drive.getDiskID() == crafterDiskId end))
	local recipeDiskDrive = assert(peripheral.find('drive', function(_, drive) return drive.getDiskID() == recipeDiskId end))
	local inputInv = assert(peripheral.wrap(inputName))
	local outputInv = assert(peripheral.wrap(outputName))

	local crafterDir = crafterDiskDrive.getMountPath()
	print('Loading crafters in ' .. crafterDir .. ' ...')
	loadCrafterDir(crafterDir)
	print('Loaded ' .. tableCount(mechanicalPresses) .. ' mechanical presses')
	print('Loaded ' .. tableCount(deployers) .. ' deployers')

	local recipeDir = recipeDiskDrive.getMountPath()
	print('Loading recipes in ' .. recipeDir .. ' ...')
	loadRecipeDir(recipeDir)
	print('Loaded ' .. tableCount(recipes) .. ' recipes')

	co_main(function()
		initTUI(crafterDir, recipeDir, inputName, outputName)
		sleep(0.1)
		renderTUI()
	end, function()
		while true do
			pullEvents()
		end
	end, function()
		for name, data in pairs(deployers) do
			co_run(transferItems, data.deployer, inputName, 1)
		end
		while true do
			update()
			sleep(0.1)
		end
	end)
end

main({...})
