-- CC Storage - Depot
-- Item storage
-- by zyxkad@gmail.com

---- BEGIN CONFIG ----

local insideModemSide = 'bottom'
local outsideModemSide = 'right'
-- cache inventory name on the inside
local cacheInvInsideName = 'minecraft:barrel_5'
-- cache inventory name on the outside
local cacheInvOutsideName = 'minecraft:barrel_4'

---- END CONFIG ----

local crx = require('coroutinex')
local co_run = crx.run
local asleep = crx.asleep
local await = crx.await
local co_main = crx.main

local network = require('network')


assert(peripheral.hasType(insideModemSide, 'modem'))
assert(peripheral.hasType(outsideModemSide, 'modem'))
local insideModem = assert(peripheral.wrap(insideModemSide))
local outsideModem = assert(peripheral.wrap(outsideModemSide))
assert(insideModem.hasTypeRemote(cacheInvInsideName, 'inventory'))
assert(outsideModem.hasTypeRemote(cacheInvOutsideName, 'inventory'))
local cacheInvInside = assert(peripheral.wrap(cacheInvInsideName), string.format('Cache inventory %s not found', cacheInvInsideName))
local cacheInvOutside = assert(peripheral.wrap(cacheInvOutsideName), string.format('Cache inventory %s not found', cacheInvOutside))


local inventories = {}
local counted = {}

local function itemIndexName(item)
	local name = item.name
	if item.nbt then
		name = name .. ';' .. item.nbt
	end
	return name
end

local function addStorage(name)
	if inventories[name] then
		return
	end
	print('Add storage:', name)
	local inv = peripheral.wrap(name)
	inventories[name] = {
		p = inv, -- peripheral
		list = nil, -- data / content
		size = nil,
	}
end

local function searchAndTakeItemFromCounted(name, nbt, count)
	local res = {}
	local ind = itemIndexName({ name=name, nbt=nbt })
	local data = counted[ind]
	if not data then
		return nil
	end
	for i, pos in pairs(data.positions) do
		if pos.count >= count then
			pos.count = pos.count - count
			res[#res + 1] = {
				inv = pos.inv,
				slot = pos.slot,
				count = count,
			}
			count = 0
			break
		end
		data.positions[i] = nil
		count = count - pos.count
		res[#res + 1] = {
			inv = pos.inv,
			slot = pos.slot,
			count = pos.count,
		}
	end
	return res
end

local function pollInvs()
	for _, name in pairs(insideModem.getNamesRemote()) do
		if name ~= cacheInvInsideName and insideModem.hasTypeRemote(name, 'inventory') then
			addStorage(name)
		end
	end
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			if name ~= cacheInvInsideName and insideModem.hasTypeRemote(name, 'inventory') then
				addStorage(name)
			end
		elseif event == 'peripheral_detach' then
			inventories[name] = nil
		end
	end
end

local invLock = crx.newLock()
local invData = nil
local itemDetailCache = {}

local function pollInvLists()
	local pool = crx.newThreadPool(100)
	while true do
		local start = os.epoch('utc')

		invLock.rLock()
		local countedLc = {}
		local totalSt = 0
		local usedSt = 0
		local actualSt = 0
		local resCache = {}
		local defers = {}
		for invName, inv in pairs(inventories) do
			pool.queue(function(inv, invName)
				local ths = {}
				local size, list
				await(pool.queue(function()
					size = inv.p.size()
				end), pool.queue(function()
					list = inv.p.list()
				end))
				totalSt = totalSt + size

				for slot, item in pairs(list) do
					local ind = itemIndexName(item)
					local detail = itemDetailCache[ind]
					if detail then
						item.displayName = detail.displayName
						item.maxCount = detail.maxCount
						usedSt = usedSt + item.count / detail.maxCount
						actualSt = actualSt + 1
						local c = countedLc[ind]
						if c then
							c.count = c.count + item.count
							c.usedSlot = c.usedSlot + 1
							c.positions[#c.positions + 1] = {
								inv = invName,
								slot = slot,
								count = item.count,
							}
						else
							countedLc[ind] = {
								count = item.count,
								usedSlot = 1,
								displayName = detail.displayName,
								maxCount = detail.maxCount,
								positions = {
									{
										inv = invName,
										slot = slot,
										count = item.count,
									},
								},
							}
						end
					else
						local cacheSlot = resCache[ind]
						if cacheSlot then
							defers[item] = cacheSlot
							local c = countedLc[ind]
							c.count = c.count + item.count
							c.usedSlot = c.usedSlot + 1
							c.positions[#c.positions + 1] = {
								inv = invName,
								slot = slot,
								count = item.count,
							}
						else
							resCache[ind] = item
							countedLc[ind] = {
								count = item.count,
								usedSlot = 1,
								positions = {
									{
										inv = invName,
										slot = slot,
										count = item.count,
									},
								},
							}
							ths[#ths + 1] = pool.queue(function(item, p, slot)
								local detail = p.getItemDetail(slot)
								if not detail then
									error(string.format('slot: %s/%d does not exists', invName, slot))
								end
								itemDetailCache[ind] = detail
								item.displayName = detail.displayName
								item.maxCount = detail.maxCount
								usedSt = usedSt + item.count / item.maxCount
								actualSt = actualSt + 1
								local c = countedLc[ind]
								c.displayName = item.displayName
								c.maxCount = item.maxCount
							end, item, inv.p, slot)
						end
					end
				end
				await(table.unpack(ths))
				inv.size = size
				inv.list = list
			end, inv, invName)
		end

		pool.waitForAll()
		invLock.rUnlock()

		for item, details in pairs(defers) do
			item.displayName = details.displayName
			item.maxCount = details.maxCount
			usedSt = usedSt + item.count / item.maxCount
			actualSt = actualSt + 1
		end

		local now = os.epoch('utc')
		print('poll done', os.clock(), 'used', (now - start) / 1000)

		counted = countedLc
		invData = {
			counted = counted,
			totalSlot = totalSt,
			usedSlot = usedSt,
			actualSlot = actualSt,
		}
		network.broadcast('update-storage', invData)

		sleep(3)
	end
end

local function cmdTake(reply, name, nbt, count, target)
	count = count or 1

	print('taking', count, name, os.clock())
	invLock.lock()

	-- search item in the storage
	local res = searchAndTakeItemFromCounted(name, nbt, count)
	if not res then
		invLock.unlock()

		reply({
			pushed = 0,
		})
		return
	end
	local thrs = {}
	-- push item to local cache
	for _, data in pairs(res) do
		thrs[#thrs + 1] = co_run(cacheInvInside.pullItems, data.inv, data.slot, data.count)
	end
	await(table.unpack(thrs))

	invLock.unlock()

	-- push item from local cache to remote
	local remains = {}
	local pushed = 0
	thrs = {}
	for slot, data in pairs(cacheInvOutside.list()) do
		thrs[#thrs + 1] = co_run(function(slot, data)
			local ct = cacheInvOutside.pushItems(target, slot, data.count)
			local remain = data.count - ct
			if remain ~= 0 then
				remains[slot] = remain
			end
			pushed = pushed + ct
		end, slot, data)
	end
	print('waiting transfer to', target, os.clock())
	await(table.unpack(thrs))
	print('done to transfer to', target, os.clock())

	reply({
		pushed = pushed,
	})

	if pushed < count then
		-- clear cache
		local thrs = {}
		for slot, remain in pairs(remains) do
			for invName, _ in pairs(inventories) do
				local ct = cacheInvInside.pushItems(invName, slot, remain)
				remain = remain - ct
				if remain == 0 then
					break
				end
			end
		end
	end
end

local function cmdPut(reply, source, slots)
	local received = 0
	local thrs = {}
	-- pull item from remote to local cache
	for slot, count in pairs(slots) do
		thrs[#thrs + 1] = co_run(function(source, slot, count)
			local pulled = cacheInvOutside.pullItems(source, slot, count)
			received = received + pulled
		end, source, slot, count)
	end
	await(table.unpack(thrs))
	-- push item from cache to storage
	local deposited = 0
	for slot, item in pairs(cacheInvInside.list()) do
		local icount = item.count
		for invName, _ in pairs(inventories) do
			local pushed = cacheInvInside.pushItems(invName, slot, icount)
			icount = icount - pushed
			deposited = deposited + pushed
			if icount == 0 then
				break
			end
		end
		if deposited >= received then
			break
		end
	end
	if deposited < received then
		-- clear cache
		local thrs = {}
		for slot, data in pairs(cacheInvOutside.list()) do
			thrs[#thrs + 1] = co_run(cacheInvOutside.pushItems, source, slot, data.count)
		end
		await(table.unpack(thrs))
	end
	reply({
		received = received,
		deposited = deposited,
	})
end

function main(args)
	network.setType('depot')
	network.open(outsideModemSide)

	network.registerCommand('query-storage', function(_, _, payload, reply)
		reply(invData)
	end)

	network.registerCommand('take', function(_, _, payload, reply)
		co_run(cmdTake, reply, payload.name, payload.nbt, payload.count, payload.target)
	end)

	network.registerCommand('put', function(_, _, payload, reply)
		co_run(cmdPut, reply, payload.source, payload.slots)
	end)

	co_main(network.run, pollInvs, pollInvLists)
end

main({...})
