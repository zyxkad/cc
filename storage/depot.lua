-- CC Storage - Depot
-- by zyxkad@gmail.com

---- BEGIN CONFIG ----

local insideModemSide = 'bottom'
local outsideModemSide = 'right'
-- cache inventory name on the inside
local cacheInvInsideName = 'minecraft:barrel_5'
-- cache inventory name on the outside
local cacheInvOutsideName = 'minecraft:barrel_4'

local storageTypes = {
	['minecraft:chest'] = true,
	['minecraft:barrel'] = true,
	['quark:variant_chest'] = true,
}

---- END CONFIG ----

local REDNET_PROTOCOL = 'storage'
local HOSTNAME = string.format('depot-%d', os.getComputerID())

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_exit = crx.exit
local co_main = crx.main

assert(peripheral.getType(insideModemSide) == 'modem')
assert(peripheral.getType(outsideModemSide) == 'modem')
local insideModem = assert(peripheral.wrap(insideModemSide))
local outsideModem = assert(peripheral.wrap(outsideModemSide))
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
			for slot, data in pairs(inv.d) do
				if data.name == name and data.nbt == nbt then
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
		if name ~= cacheInvInsideName and storageTypes[peripheral.getType(name)] then
			addStorage(name)
		end
	end
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			if insideModem.isPresentRemote(name) and name ~= cacheInvInsideName and storageTypes[peripheral.getType(name)] then
				addStorage(name)
			end
		elseif event == 'peripheral_detach' then
			inventories[name] = nil
		end
	end
end

local function pollInvLists()
	while true do
		local thrs = {}
		local c = 0
		for _, inv in pairs(inventories) do
			c = c + 1
			thrs[#thrs + 1] = co_run(function(inv)
				local thrs = {}
				local list = {}
				for slot, _ in pairs(inv.p.list()) do
					thrs[#thrs + 1] = co_run(function(list, p, slot)
						list[slot] = p.getItemDetail(slot)
					end, list, inv.p, slot)
				end
				await(table.unpack(thrs))
				inv.d = list
			end, inv)
		end
		await(table.unpack(thrs), function() sleep(1) end)
	end
end

local function pollCommands()
	while true do
		local id, message = rednet.receive(REDNET_PROTOCOL)
		if type(message) == 'table' then
			if message.cmd == 'query' then
				local data = {}
				for name, inv in pairs(inventories) do
					if inv.d ~= nil then
						data[name] = inv.d
					end
				end
				-- rednet.send does not block
				rednet.send(id, {
					cmd = 'query-reply',
					name = HOSTNAME,
					data = data,
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'take' then
				local name, nbt, count, target = message.name, message.nbt, message.count, message.target
				count = count or 1
				local res = searchItem(name, nbt, count)
				local thrs = {}
				for _, data in pairs(res) do
					thrs[#thrs + 1] = co_run(cacheInvInside.pullItems, data.inv, data.slot, data.count)
				end
				await(table.unpack(thrs))
				local pushed = 0
				for slot, data in pairs(cacheInvOutside.list()) do
					pushed = pushed + cacheInvOutside.pushItems(target, slot, data.count)
				end
				rednet.send(id, {
					cmd = 'take-reply',
					name = HOSTNAME,
					pushed = pushed,
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'put' then
				local source, slots = message.source, message.slots
				local received = 0
				local thrs = {}
				for slot, count in pairs(slots) do
					thrs[#thrs + 1] = co_run(cacheInvOutside.pullItems, source, slot, count)
				end
				await(table.unpack(thrs))
				local deposited = 0
				for slot, item in pairs(cacheInvInside.list()) do
					local icount = item.count
					for invName, _ in pairs(inventories) do
						local pushed = cacheInvInside.pushItems(invName, slot, icount)
						if pushed == 0 then
							break
						end
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
				rednet.send(id, {
					cmd = 'put-reply',
					name = HOSTNAME,
					received = received,
					deposited = deposited,
				}, REDNET_PROTOCOL)
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
