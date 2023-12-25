-- CC Storage - Craft Process Unit (CPU)
-- by zyxkad@gmail.com

---- BEGIN CONFIG ----

local insideModemSide = 'bottom'
local outsideModemSide = 'back'
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
local HOSTNAME = string.format('cpu-%d', os.getComputerID())

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main


assert(peripheral.hasType(insideModemSide, 'modem'))
assert(peripheral.hasType(outsideModemSide, 'modem'))
local insideModem = assert(peripheral.wrap(insideModemSide))
local outsideModem = assert(peripheral.wrap(outsideModemSide))
assert(insideModem.hasTypeRemote(cacheInvInside, 'inventory'))
assert(outsideModem.hasTypeRemote(cacheInvOutside, 'inventory'))
local cacheInvInside = assert(peripheral.wrap(cacheInvInsideName), string.format('Cache inventory %s not found', cacheInvInsideName))
local cacheInvOutside = assert(peripheral.wrap(cacheInvOutsideName), string.format('Cache inventory %s not found', cacheInvOutside))


local function pollCommands()
	while true do
		local id, message = rednet.receive(REDNET_PROTOCOL)
		if type(message) == 'table' then
			if message.cmd == 'ping' then
				-- rednet.send does not block
				rednet.send(id, {
					cmd = 'pong',
					name = HOSTNAME,
					type = 'cpu',
					space = space,
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'craft' then
				local targetItem, count, recipes = message.item, message.count, message.recipes
				-- TODO
				rednet.send(id, {
					cmd = 'craft-reply',
					name = HOSTNAME,
					item = targetItem,
					count = count,
				}, REDNET_PROTOCOL)
			end
		end
	end
end

function main(args)
	rednet.open(outsideModemSide)
	rednet.host(REDNET_PROTOCOL, HOSTNAME)

	co_run(pollCommands)
end

main({...})
