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
					slot = slot,
					count = item.count,
				}
			else
				counted[ind] = {
					n = 1,
					l = {
						{
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
	local listFn = inv.list
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
					slot = slot,
					count = item.count,
				}
			else
				counted[ind] = {
					n = 1,
					l = {
						{
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
	--  			"name": "<item name>",
	--  			"nbt": "<item nbt>",
	--  			"count": 12,
	--  			"tags": [ // when tags exists, name can be ignored
	--  				"<tag1>",
	--  				"<tag2>",
	--  			],
	--  		},
	--  		{
	--  			"name": "<item name>",
	--  			"nbt": "<item nbt>",
	--  			"count": 12,
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
		if pos.count > remain then
			pos.count = pos.count - remain
			local ct = transferItems(pos.slot, remain)
			local ok = ct == remain
			pushed = pushed + ct
			remain = remain - ct
			if not ok then
				break
			end
		else
			poses.n = poses.n - 1
			poses.l[j] = nil
			local ct = transferItems(pos.slot, pos.count)
			local ok = ct == pos.count
			pushed = pushed + ct
			remain = remain - ct
			if not ok then
				break
			end
			if poses.n <= 0 then
				itemList[itemIndex] = nil
				break
			end
		end
		if remain == 0 then
			break
		end
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
		for source, tb in pairs(sourceInvs) do
			local itemList = tb.list
			for target, data in pairs(sources[source]) do
				if peripheral.isPresent(target) then
					if data.type == "inverse" then
						local blocked = {}
						for i, item in ipairs(data.list) do
							blocked[itemIndexName(item)] = true
						end
						for ind, _ in pairs(itemList) do
							if not blocked[ind] then
								thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind, 1)
							end
						end
					elseif data.type == "order" then
						thrs[#thrs + 1] = operPool.queue(function(data)
							for i, item in ipairs(data.list) do
								local ind = itemIndexName(item)
								if itemList[ind] then
									local pushed = pushItemFromItemList(source, target, itemList, ind, item.count or 1)
									if pushed > 0 then
										break
									end
								end
							end
						end, data)
					elseif data.type == "round" then
						local i = 1
						if data._last then
							i = data._last + 1
						end
						local item = data.list[i]
						local ind = itemIndexName(item)
						if itemList[ind] then
							thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind, item.count or 1)
							data._last = i
							-- TODO: save last round index
						end
					else -- if data.type == "random" then
						local i = math.random(1, #data.list)
						local item = data.list[i]
						local ind = itemIndexName(item)
						if itemList[ind] then
							thrs[#thrs + 1] = operPool.queue(pushItemFromItemList, source, target, itemList, ind, item.count or 1)
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
