-- CC Storage - Logistic Controller
-- by zyxkad@gmail.com

local dataDiskId = 0
local dataDiskDrive = assert(peripheral.find('drive', function(_, drive) return drive.getDiskID() == dataDiskId end))
local dataPath = dataDiskDrive.getMountPath()

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local asleep = crx.asleep
local co_main = crx.main

local operPool -- = crx.newThreadPool(160)

local network = require('network')

local function endswith(s, suffix)
	local _, i = string.find(s, suffix, 1, true)
	return i == #s
end

local function itemIndexName(item)
	local name = item.name
	if type(item.nbt) == 'string' then
		name = name .. ';' .. item.nbt
	end
	return name
end

local function countItemList(inv)
	local invName = peripheral.getName(inv)
	local listFn = inv.list or inv.getInventory
	local ok, list = pcall(listFn)
	if not ok or not list then
		return nil
	end
	local counted = {}
	for slot, item in pairs(list) do
		if item.name then
			local ind = itemIndexName(item)
			local poses = counted[ind]
			if poses then
				poses.n = poses.n + 1
				poses.l[#poses.l + 1] = {
					invName = name,
					slot = slot,
					count = item.count,
				}
			else
				counted[ind] = {
					n = 1,
					l = {
						{
							invName = name,
							slot = slot,
							count = item.count,
						},
					},
				}
			end
		end
	end
	return counted
end

local function countFluidList(inv)
	local invName = peripheral.getName(inv)
	local tanksFn = inv.tanks or inv.getOutputFluids
	if not tanksFn then
		local ok, info = pcall(inv.getInfo)
		if not ok or not info then
			return nil
		end
		local fluidName = info.fluid
		if fluidName and fluidName ~= 'minecraft:air' and fluidName ~= 'minecraft:empty' then
			return {
				[fluidName] = {
					invName = invName,
					amount = info.amount,
				}
			}
		end
		return nil
	end
	local ok, tanks = pcall(tanksFn)
	if not ok or not tanks then
		return nil
	end
	local counted = {}
	for _, tank in pairs(tanks) do
		local fluidName = tank.name or tank.fluid
		if fluidName and fluidName ~= 'minecraft:air' and fluidName ~= 'minecraft:empty' then
			counted[fluidName] = {
				invName = invName,
				amount = tank.amount,
			}
		end
	end
	return counted
end

local function parseLogisticFile()
	-- folder structure
	--  $dataPath/
	--  	<source name/group>/
	--  		<target1 name/group>.json
	--  		<target2 name/group>.json
	-- Note: The name starts with '#' means a group

	-- structure of the json
	--  {
	--  	"type": "order", // order / round / random / inverse
	--  	"list": [
	--  		{
	--  			"fluid": false,
	--  			"name": "<item name>",
	--  			"nbt": "<item nbt>",
	--  			"count": 12,
	--  			"tags": [ // when tags exists, name can be ignored
	--  				"<tag1>",
	--  				"<tag2>",
	--  			],
	--  		},
	--  		{
	--  			"fluid": true,
	--  			"name": "<fluid name>",
	--  			"amount": 1000, // mB
	--  			"tags": [ // when tags exists, name can be ignored
	--  				"<tag1>",
	--  				"<tag2>",
	--  			],
	--  		},
	--  	],
	--  }
	-- TODO: impl tag

	local sources = {}
	for _, sourceName in ipairs(fs.list(dataPath)) do
		local dir1 = fs.combine(dataPath, sourceName)
		local targets = {}
		for _, targetName in ipairs(fs.list(dir1)) do
			if endswith(targetName, '.json') then
				local fd = fs.open(fs.combine(dir1, targetName), 'r')
				local data = textutils.unserialiseJSON(fd.readAll())
				targetName = targetName:sub(1, -(#'.json' + 1)):gsub('-', ':', 1, true)
				targets[targetName] = data
			end
		end
		sourceName = sourceName:gsub('-', ':', 1, true)
		sources[sourceName] = targets
	end
	return sources
end

local sources -- = parseLogisticFile()

local function timedParseLogisticFile()
	local timerId = os.startTimer(60)
	while true do
		local event, p1 = os.pullEvent()
		if event == 'timer' and p1 == timerId or event == '_parse_logistic' then
			local s = parseLogisticFile()
			sources = s
			timerId = os.startTimer(60)
		end
	end
end

local function pushItemFromItemList(source, target, itemList, itemIndex, limit)
	local srcInv = peripheral.wrap(source)
	local transferItems
	if srcInv.pushItems then
		transferItems = function(slot, limit)
			return srcInv.pushItems(target, slot, limit)
		end
	else
		local targetInv = peripheral.wrap(target)
		transferItems = function(slot, limit)
			return targetInv.pullItems(source, slot, limit)
		end
	end
	local poses = itemList[itemIndex]
	local pushed = 0
	local remain = limit
	local thrs = {}
	for j, pos in pairs(poses.l) do
		if limit and pos.count > remain then
			pos.count = pos.count - remain
			local ct = transferItems(pos.slot, remain)
			local ok = ct == remain
			pushed = pushed + ct
			if limit then
				remain = remain - ct
			end
			if not ok then
				break
			end
		else
			poses.n = poses.n - 1
			poses.l[j] = nil
			local ct = transferItems(pos.slot, pos.count)
			local ok = ct == pos.count
			pushed = pushed + ct
			if limit then
				remain = remain - ct
			end
			if not ok then
				break
			end
			if poses.n <= 0 then
				itemList[itemIndex] = nil
				break
			end
		end
		if limit and remain == 0 then
			break
		end
	end
	return pushed
end

local function pushFluidFromTankList(source, target, tankList, fluidName, amount)
	local tank = tankList[fluidName]
	local pushed
	local srcInv = peripheral.wrap(source)
	if srcInv.pushFluid then
		pushed = srcInv.pushFluid(target, amount, fluidName)
	else
		local targetInv = peripheral.wrap(target)
		pushed = targetInv.pullFluid(source, amount, fluidName)
	end
	if pushed >= tank.amount then
		tankList[fluidName] = nil
	else
		tank.amount = tank.amount - pushed
	end
	return pushed
end

local function pollInvs()
	while true do
		local thrs = {}
		local sourceInvs = {}
		local sourceTanks = {}
		for source, _ in pairs(sources) do
			local srcInv = peripheral.wrap(source)
			if srcInv then
				thrs[#thrs + 1] = operPool.queue(function(source)
					local itemList = countItemList(srcInv)
					if itemList then
						sourceInvs[source] = {
							inv = srcInv,
							list = itemList,
						}
					end
				end, source)
				thrs[#thrs + 1] = operPool.queue(function(source)
					local fluidList = countFluidList(srcInv)
					if fluidList then
						sourceTanks[source] = {
							inv = srcInv,
							list = fluidList,
						}
					end
				end, source)
			end
		end
		await(table.unpack(thrs))
		thrs = { asleep(0.1) }
		for source, targets in pairs(sources) do
			local items, tanks = sourceInvs[source], sourceTanks[source]
			local itemList, tankList = items and items.list or {}, tanks and tanks.list or {}
			for target, data in pairs(targets) do
				if peripheral.isPresent(target) then
					if data.type == "inverse" then
						local blocked = {}
						for i, item in ipairs(data.list) do
							blocked[itemIndexName(item)] = true
						end
						local flag = true
						for ind, _ in pairs(itemList) do
							if not blocked[ind] then
								thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind)
								flag = false
								break
							end
						end
						if flag then
							for fluidName, _ in pairs(tankList) do
								if not blocked[fluidName] then
									thrs[#thrs + 1] = operPool.queue(pushFluidFromTankList, source, target, tankList, fluidName)
									break
								end
							end
						end
					elseif data.type == "order" then
						thrs[#thrs + 1] = operPool.queue(function(data)
							for i, item in ipairs(data.list) do
								if item.fluid then
									local fluidName = item.name
									if tankList[fluidName] then
										local pushed = pushFluidFromTankList(source, target, tankList, fluidName, item.amount)
										if pushed > 0 then
											break
										end
									end
								else
									local ind = itemIndexName(item)
									if itemList[ind] then
										local pushed = pushItemFromItemList(source, target, itemList, ind, item.count)
										if pushed > 0 then
											break
										end
									end
								end
							end
						end, data)
					elseif data.type == "round" then
						local i = 1
						if data._last then
							i = data._last % #data.list + 1
						end
						local item = data.list[i]
						if item.fluid then
							local fluidName = item.name
							if tankList[fluidName] then
								thrs[#thrs + 1] = operPool.queue(pushFluidFromTankList, source, target, tankList, fluidName, item.amount)
								data._last = i
							end
						else
							local ind = itemIndexName(item)
							if itemList[ind] then
								thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind, item.count)
								data._last = i
							end
						end
						-- TODO: save last round index
					else -- if data.type == "random" then
						local i = math.random(1, #data.list)
						local item = data.list[i]
						if item.fluid then
							local fluidName = item.name
							if tankList[fluidName] then
								thrs[#thrs + 1] = operPool.queue(pushFluidFromTankList, source, target, tankList, fluidName, item.amount)
							end
						else
							local ind = itemIndexName(item)
							if itemList[ind] then
								thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind, item.count)
							end
						end
					end
				end
			end
		end
		await(table.unpack(thrs))
	end
end

function main()
	network.setType('logistic-controller')
	peripheral.find('modem', function(modemSide)
		if peripheral.hasType(modemSide, 'peripheral_hub') then
			network.open(modemSide)
		end
	end)

	network.registerCommand('trigger-parse-logistic', function()
		os.queueEvent('_parse_logistic')
	end)

	print('parsing:', dataPath)

	sources = parseLogisticFile()

	co_main(function()
		operPool = crx.newThreadPool(160)
	end, network.run, timedParseLogisticFile, pollInvs)
end

main()
