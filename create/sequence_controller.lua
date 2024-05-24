-- Create Sequence Recipe Controller
-- by zyxkad@gmail.com

local crx = require('coroutinex')
crx.startDebug()
local co_main = crx.main
local co_run = crx.run
local await = crx.await
local awaitAny = crx.awaitAny
--[[
wget run https://basalt.madefor.cc/install.lua packed
]]
local basalt = require('basalt')

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
		if name:match('[a-zA-Z0-9._-]+.json$') then
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
				local res = await(d.pending)
				list = res[1]
			elseif d.ttl > os.clock() then
				list = d.list
			end
		end
	end
	if not list then
		pending = co_run(function() return peripheral.call(inv, 'list') end)
		listCaches[inv] = {
			pending = pending,
		}
		list = await(pending)
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
	if count == 0 then
		return
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
			info = info,
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
		return
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
end

local function onMaterialMissing(item)
	basalt.log('Missing ' .. item.name)
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
			return nil, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		transferItems(last, name, item.slot, 1)
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
			return nil, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		local _, res = await(function()
			transferItems(last, name, item.slot, 1, 1)
		end, function()
			local deployerItemSlot = findItemInInventory(source, stage.operators.deployer)
			if not deployerItemSlot then
				return false
			end
			transferItems(source, data.deployer, deployerItemSlot, 1, 1)
			return true
		end)
		if not res[1] then
			-- push back the base material
			transferItems(name, last, 1, 1)
			return nil, 'ITEM_MISSING', stage.operators.deployer
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
			return nil, 'ERR_NO_CPU'
		end
		data.processing = {
			stage = stage,
			item = item,
		}
		local spoutFluid = stage.operators.spout
		local _, res = await(function()
			transferItems(last, name, item.slot, 1, 1)
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
		if not res[1] then
			-- push back the base material
			transferItems(name, last, 1, 1)
			return nil, 'ITEM_MISSING', stage.operators.deployer
		end
		return true, name, data.processing
	else
		error('Unexpected crafter type ' .. stage.crafter)
	end
end

local function releaseCPU(name)
	local data = mechanicalPresses[name] or deployers[name]
	if data then
		data.processing = nil
	end
end

local function craftRecipe(source, targetInv, target)
	local recipe = recipes[target]
	if not recipe then
		return nil, 'recipe not found'
	end
	local lastStage, lastCrafter, processing
	do
		local itemSlot, item = findItemInInventory(source, recipe.initItem)
		item.slot = itemSlot
		processing = {
			item = item,
		}
		basalt.debug('found', item.name, 'at', itemSlot)
	end
	local repeats = recipe.repeats or 1
	for t = 1, repeats do
		for i, stage in ipairs(recipe.stages) do
			if lastCrafter and processing then
				basalt.debug('waiting change', t, i)
				local current
				repeat
					current = peripheral.call(lastCrafter, 'getItemDetail', 1)
				until processing.item.name ~= current.name or processing.item.nbt ~= current.nbt
				processing.item = current
			end
			if lastStage and lastStage.crafter == stage.crafter then
				if stage.crafter == deployerCrafterId then
					local data = assert(deployers[lastCrafter])
					if lastStage.operators.deployer.reusable then
						transferItems(data.deployer, source, 1)
					else
						transferItems(data.deployer, targetInv, 1)
					end
					local deployerItem = stage.operators.deployer
					basalt.debug('finding', deployerItem.name)
					local deployerItemSlot = findItemInInventory(source, deployerItem)
					if not deployerItemSlot then
						onMaterialMissing(deployerItem)
						repeat
							deployerItemSlot = findItemInInventory(source, deployerItem)
						until deployerItemSlot
					end
					transferItems(source, data.deployer, deployerItemSlot, 1, 1)
				elseif stage.crafter == spoutCrafterId then
					local data = assert(spouts[lastCrafter])
					local spoutFluid = stage.operators.spout
					basalt.debug('finding', spoutFluid.fluid)
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
				local ok, name, item = allocCPU(stage, source, lastCrafter, processing.item)
				if not ok then
					if name == 'ITEM_MISSING' then
						onMaterialMissing(item)
					end
					repeat
						ok, name, item = allocCPU(stage, source, lastCrafter, processing.item)
					until ok
				end
				releaseCPU(lastCrafter)
				lastCrafter = name
				processing = item
			end
			lastStage = stage
		end
	end
	if lastCrafter and processing then
		local current
		repeat
			current = peripheral.call(lastCrafter, 'getItemDetail', 1)
		until processing.item.name ~= current.name or processing.item.nbt ~= current.nbt
		processing.item = current
	end
	if lastCrafter then
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

local recipeList = mainFrame:addList()
	:setScrollable(true)
	:setSize(35, "parent.h - 9")
	:setPosition(3, 8)
	:setBackground(colors.gray)
	:setForeground(colors.white)
local craftButton = mainFrame:addButton()
	:setText("[Craft]")
	:setPosition(39, 12)

local function isPeripheralRegistered(name)
	if mechanicalPresses[name] or deployers[name] then
		return true
	end
	for _, data in pairs(deployers) do
		if data.deployer == name then
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
				local count = 0
				if count <= 0 then
					count = btn == 2 and 16 or 1
				end
				basalt.debug('crafting', target, count)
				co_run(function()
					inProgress[target] = (inProgress[target] or 0) + count
					for t = 1, count do
						local ok, err = craftRecipe(sourceInv, targetInv, target, count)
						if not ok then
							basalt.debug('craft failed', err)
						end
						inProgress[target] = inProgress[target] - 1
					end
				end)
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
	end)
end

main({...})
