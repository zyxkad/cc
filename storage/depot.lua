-- CC Storage - Depot
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

local function addStorage(name)
	if inventories[name] then
		return
	end
	print('Add storage:', name)
	local inv = peripheral.wrap(name)
	inventories[name] = {
		p = inv, -- peripheral
		d = nil, -- data / content
	}
end

local function searchItem(name, nbt, count)
	local res = {}
	for invName, inv in pairs(inventories) do
		if inv.d then
			for slot, data in pairs(inv.d.list) do
				if type(slot) == 'number' and data.name == name and data.nbt == nbt then
					if data.count >= count then
						res[#res + 1] = {
							inv = invName,
							slot = slot,
							count = count,
						}
						count = 0
						break
					end
					count = count - data.count
					res[#res + 1] = {
						inv = invName,
						slot = slot,
						count = data.count,
					}
				end
			end
			if count == 0 then
				break
			end
		end
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

local function itemIndexName(item)
	local name = item.name
	if item.nbt then
		name = name .. ';' .. item.nbt
	end
	return name
end

local function pollInvLists()
	local pool = crx.newThreadPool(200)
	while true do
		local data = {}
		for invName, inv in pairs(inventories) do
			pool.queue(function(data, inv, invName)
				local ths = {}
				local list = {}
				local resCache = {}
				local defers = {}
				local size, items
				await(pool.queue(function()
					size = inv.p.size()
				end), pool.queue(function()
					items = inv.p.list()
				end))
				for slot, item in pairs(items) do
					local ind = itemIndexName(item)
					local cacheSlot = resCache[ind]
					if cacheSlot then
						defers[slot] = cacheSlot
						list[slot] = item
					else
						resCache[ind] = slot
						ths[#ths + 1] = pool.queue(function(list, p, slot)
							list[slot] = p.getItemDetail(slot)
						end, list, inv.p, slot)
					end
				end
				await(table.unpack(ths))
				for slot, slot2 in pairs(defers) do
					local item = list[slot]
					local details = list[slot2]
					item.displayName = details.displayName
					item.maxCount = details.maxCount
				end
				local d = {
					size = size,
					list = list,
				}
				inv.d = d
				data[invName] = d
			end, data, inv, invName)
		end
		await(asleep(1), function()
			pool.waitForAll()
			rednet.broadcast({
				cmd = 'update-storage',
				name = HOSTNAME,
				data = textutils.serialiseJSON(data),
			}, REDNET_PROTOCOL)
		end)
	end
end

local function cmdTake(id, name, nbt, count, target)
	count = count or 1
	-- search item in the storage
	local res = searchItem(name, nbt, count)
	local thrs = {}
	-- push item to local cache
	for _, data in pairs(res) do
		thrs[#thrs + 1] = co_run(cacheInvInside.pullItems, data.inv, data.slot, data.count)
	end
	await(table.unpack(thrs))
	-- push item from local cache to remote
	local pushed = 0
	for slot, data in pairs(cacheInvOutside.list()) do
		pushed = pushed + cacheInvOutside.pushItems(target, slot, data.count)
	end
	rednet.send(id, {
		cmd = 'take-reply',
		name = HOSTNAME,
		pushed = pushed,
	}, REDNET_PROTOCOL)
	if pushed < count then
		-- clear cache
		local thrs = {}
		for slot, data in pairs(cacheInvInside.list()) do
			for invName, _ in pairs(inventories) do
				thrs[#thrs + 1] = co_run(cacheInvInside.pushItems, invName, slot)
			end
		end
		await(table.unpack(thrs))
	end
end

local function cmdPut(id, source, slots)
	local received = 0
	local thrs = {}
	-- pull item from remote to local cache
	for slot, count in pairs(slots) do
		thrs[#thrs + 1] = co_run(cacheInvOutside.pullItems, source, slot, count)
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
			elseif message.cmd == 'query' then
				local data = {}
				for name, inv in pairs(inventories) do
					if inv.d ~= nil then
						data[name] = inv.d
					end
				end
				rednet.send(id, {
					cmd = 'query-reply',
					name = HOSTNAME,
					data = data,
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'take' then
				cmdTake(id, message.name, message.nbt, message.count, message.target)
			elseif message.cmd == 'put' then
				cmdPut(id, message.source, message.slots)
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
