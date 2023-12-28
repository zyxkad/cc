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

local REDNET_PROTOCOL = 'storage'
local HOSTNAME = string.format('depot-%d', os.getComputerID())

local crx = require('coroutinex')
local co_run = crx.run
local asleep = crx.asleep
local await = crx.await
local co_main = crx.main


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

local function pollInvLists()
	local pool = crx.newThreadPool(100)
	while true do
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
							local details = p.getItemDetail(slot)
							if not details then
								error(string.format('slot: %s/%d does not exists', invName, slot))
							end
							item.displayName = details.displayName
							item.maxCount = details.maxCount
							usedSt = usedSt + item.count / item.maxCount
							actualSt = actualSt + 1
							local c = countedLc[ind]
							c.displayName = item.displayName
							c.maxCount = item.maxCount
						end, item, inv.p, slot)
					end
				end
				await(table.unpack(ths))
				inv.size = size
				inv.list = list
			end, inv, invName)
		end

		pool.waitForAll()
		print('poll done', os.clock())
		invLock.rUnlock()

		for item, details in pairs(defers) do
			item.displayName = details.displayName
			item.maxCount = details.maxCount
			usedSt = usedSt + item.count / item.maxCount
			actualSt = actualSt + 1
		end

		counted = countedLc
		invData = {
			counted = counted,
			totalSlot = totalSt,
			usedSlot = usedSt,
			actualSlot = actualSt,
		}
		rednet.broadcast({
			cmd = 'update-storage',
			name = HOSTNAME,
			data = invData,
		}, REDNET_PROTOCOL)

		sleep(3)
	end
end

local function cmdTake(id, name, nbt, count, target)
	count = count or 1

	print('taking', count, name, os.clock())
	invLock.lock()

	-- search item in the storage
	local res = searchAndTakeItemFromCounted(name, nbt, count)
	if not res then
		invLock.unlock()

		rednet.send(id, {
			cmd = 'take-reply',
			name = HOSTNAME,
			pushed = 0,
		}, REDNET_PROTOCOL)
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

	rednet.send(id, {
		cmd = 'take-reply',
		name = HOSTNAME,
		pushed = pushed,
	}, REDNET_PROTOCOL)

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

local function cmdPut(id, source, slots)
	local received = 0
	local thrs = {}
	-- pull item from remote to local cache
	for slot, count in pairs(slots) do
		thrs[#thrs + 1] = co_run(function(source, slot, count)
			received = received + cacheInvOutside.pullItems(source, slot, count)
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
	rednet.send(id, {
		cmd = 'put-reply',
		name = HOSTNAME,
		received = received,
		deposited = deposited,
	}, REDNET_PROTOCOL)
end

local function pollCommands()
	while true do
		local id, message = rednet.receive(REDNET_PROTOCOL)
		if type(message) == 'table' then
			if message.cmd == 'ping' then
				-- rednet.send does not block
				rednet.send(id, {
					cmd = 'pong',
					name = HOSTNAME,
					type = 'depot',
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'query-storage' then
				if invData then
					rednet.send(id, {
						cmd = 'query-storage-reply',
						name = HOSTNAME,
						data = invData,
					}, REDNET_PROTOCOL)
				end
			elseif message.cmd == 'take' then
				co_run(cmdTake, id, message.name, message.nbt, message.count, message.target)
			elseif message.cmd == 'put' then
				co_run(cmdPut, id, message.source, message.slots)
			end
		end
	end
end

function main(args)
	rednet.open(outsideModemSide)
	rednet.host(REDNET_PROTOCOL, HOSTNAME)

	co_main(pollInvs, pollInvLists, pollCommands)
end

main({...})
