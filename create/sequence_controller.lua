-- Create Sequence Recipe Controller
-- by zyxkad@gmail.com

local crx = require('coroutinex')
local co_main = crx.main
local co_run = crx.run
local await = crx.await
local basalt = require('basalt')

-- crafters

local mechanicalPressDepotId = 'create:depot'
local deployerId = 'create:deployer'
local deployerDepotId = 'create:depot'

local mechanicalPresses = {} -- { [depot: string]: { processing: table } }
local deployers = {} -- { [depot: string]: { deployer: string, processing: table } }

local recipes = {} --[[
{
	[output: string] = {
		type = 'sequence',
		initItem: {
			name: string | nil,
			tags: [tag: string ...] | nil,
			nbt: string | false | nil,
		},
		stages: [{
			crafter: string = <crafter type>,
			extra: {
				-- the item in extra will be pushed to the `storage` that the crafter data refrences.
				[storage: string]: {
					name: string | nil,
					tags: [tag: string ...] | nil,
					nbt: string | false | nil,
				},
			}
		}...],
		output: string,
	}
}
]]

local function tableCount(t)
	local count = 0
	for _, _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function loadCrafter(crafter)
	if crafter.type == 'create:press' then
		if peripheral.hasType(crafter.name, mechanicalPressDepotId) then
			mechanicalPresses[crafter.name] = {}
			return true
		end
	elseif crafter.type == 'create:deployer' then
		if peripheral.hasType(crafter.name, deployerDepotId) and peripheral.hasType(crafter.deployer, deployerId) then
			deployers[crafter.name] = {
				deployer = crafter.deployer,
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
				local recipe = textutils.unserialiseJSON(data)
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
	local detail = inv.getItemDetail(slot)
	if not detail or detail.name ~= name then
		return nil
	end
	itemTags[name] = detail.tags
	return detail.tags
end

local function findItemInInventory(inv, target)
	local list = inv.list()
	if target.name then
		for slot, item in pairs(list) do
			if item.name == target.name and (target.nbt == nil or (target.nbt == false and item.nbt == nil) or item.nbt == target.nbt) then
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

local function onMaterialMissing(item)
	basalt.log('Missing ' .. item.name)
end

--- allocCPU will alloc a craft processing unit and start to process the stage
local function allocCPU(stage, source, last, item)
	last = last or source
	if stage.crafter == 'create:press' then
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
		peripheral.call(name, 'pullItems', last, item.slot, 1)
		return true, name, data.processing
	elseif stage.crafter == 'create:deployer' then
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
			peripheral.call(name, 'pullItems', last, item.slot, 1, 1)
		end, function()
			local deployerItemSlot = findItemInInventory(inv, stage.extra.deployer)
			if not deployerItemSlot then
				return false
			end
			peripheral.call(data.deployer, 'pullItems', source, deployerItemSlot, 1, 1)
			return true
		end)
		if not res[1] then
			-- push back the base material
			peripheral.call(name, 'pushItems', last, 1)
			return nil, 'ITEM_MISSING', stage.extra.deployer
		end
		return true, name, data.processing
	else
		error('Unexpected crafter type ' .. stage.crafter)
	end
end

local function craftRecipe(source, target, count)
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
	end
	for i, stage in ipairs(recipe.stages) do
		if lastCrafter and processing then
			local current
			repeat
				crx.nextTick()
				current = peripheral.call(lastCrafter, 'getItemDetail', 1)
			until processing.item.name ~= current.name or processing.item.nbt ~= current.nbt
			processing = current
		end
		if lastStage and lastStage.crafter == stage.crafter then
			if stage.crafter == 'create:deployer' then
				local deployerItem = stage.extra.deployer
				local deployerItemSlot = findItemInInventory(source, deployerItem)
				if not deployerItemSlot then
					onMaterialMissing(deployerItem)
					return nil, 'ITEM_MISSING', deployerItem
				end
				peripheral.call(data.deployer, 'pullItems', source, deployerItemSlot, 1, 1)
			end
		else
			local ok, name, item = allocCPU(stage, source, lastCrafter, processing.item)
			if not ok then
				if name == 'ITEM_MISSING' then
					onMaterialMissing(item)
				end
				return nil, 'ITEM_MISSING', item
			end
			lastCrafter = name
			processing = item
		end
		lastStage = stage
	end
	return 1
end

---- BEGIN TUI ----

local mainFrame = basalt.createFrame()

local statsFrame = mainFrame:addFrame()
	:setPosition(3, 3)
	:setBackground(false)
	:setForeground(false)

local recipeCountLabel = statsFrame:addLabel()
	:setText("%d recipes")
	:setPosition(1, 1)
local pressCountLabel = statsFrame:addLabel()
	:setText("Presses   %d")
	:setPosition(1, 2)
local deployerCountLabel = statsFrame:addLabel()
	:setText("Deployers %d")
	:setPosition(1, 3)

local addBtnsFrame = mainFrame:addFrame()
	:setSize(21, 7)
	:setPosition("parent.w - 23", 2)
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

local function initTUI(crafterDir, recipeDir)
	local function refreshCountLabels()
		recipeCountLabel:setText(string.format("%d recipes", tableCount(recipes)))
		pressCountLabel:setText(string.format("Presses   %d", tableCount(mechanicalPresses)))
		deployerCountLabel:setText(string.format("Deployers %d", tableCount(deployers)))
	end
	refreshCountLabels()

	addCreatePressBtn:onClick(function(self, event, btn)
		if event == 'mouse_click' and btn == 1 then
			addCreatePressDepotList:clear()
			peripheral.find(mechanicalPressDepotId, function(name)
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
					type = 'create:press',
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
			peripheral.find(deployerDepotId, function(name)
				if not isPeripheralRegistered(name) then
					addCreateDeployerDepotList:addItem(name)
				end
			end)
			peripheral.find(deployerId, function(name)
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
					type = 'create:deployer',
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
end

---- END TUI ----

--- renderTUI render the UI
local function renderTUI()
	basalt.autoUpdate()
end

--- pullEvents handle events
local function pullEvents()
	local event, p1, p2, p3 = os.pullEvent()
	if event == 'x' then
	end
end

--- update operate the crafters
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
		initTUI(crafterDir, recipeDir)
		sleep(0.1)
		renderTUI()
	end, function()
		while true do
			pullEvents()
		end
	end, function()
		while true do
			update()
			crx.nextTick()
		end
	end)
end

main({...})
