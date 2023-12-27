-- CC Storage - Turtle Crafter
-- by zyxkad@gmail.com

local REDNET_PROTOCOL = 'storage'
local HOSTNAME = string.format('turtle-crafter-%d', os.getComputerID())

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local modem = peripheral.find('modem', function(_, modem) return not modem.isWireless() end)
local localName = modem.getNameLocal()

-- recipe example
-- {
-- 	grid = {
-- 		{ 'a  ' },
-- 		{ 'a  ' },
-- 		{ 'b  ' },
-- 	},
-- 	slots = {
-- 		a = {
-- 			name = 'minecraft:diamond'
-- 			nbt = false,
-- 		},
-- 		b = {
-- 			name = 'minecraft:stick'
-- 			nbt = false,
-- 		},
-- 	},
-- }

local function takeItemFrom(source, list, item, count, toSlot)
	for slot, data in pairs(list) do
		if data.count > 0 and data.name == item.name and (item.nbt == false or data.nbt == item.nbt) then
			local c = peripheral.call(source, 'pushItems', localName, slot, count, toSlot)
			data.count = data.count - c
			count = count - c
			if count == 0 then
				break
			end
		end
	end
	return count
end

local crafting = false
local preparing = nil
local prepareTimeout = nil

local function cmdCraft(id, source, recipe, count)
	if crafting then
		rednet.send(id, {
			cmd = 'craft-reply',
			name = HOSTNAME,
			crafted = false,
			err = 'Craft in process',
		}, REDNET_PROTOCOL)
		return
	end
	crafting = true
	preparing = nil
	prepareTimeout = nil

	print('Crafting for', id, '...')

	local sourceInv = peripheral.wrap(source)
	local list = sourceInv.list()

	-- take item to local storage
	for i = 0, 2 do
		local line = recipe.grid[i]
		for j = 1, 3 do
			local slot = line:sub(j, j)
			if #slot ~= 0 then
				local item = recipe.slots[slot]
				if item then
					takeItemFrom(source, list, item, count, j + i * 4)
				end
			end
		end
	end

	local ok, err = turtle.craft(count)

	local thrs = {}
	for slot = 1, 16 do
		thrs[slot] = co_run(function(slot)
			local count = turtle.getItemCount(slot)
			if count > 0 then
				sourceInv.pullItem(localName, slot, count)
			end
		end, slot)
	end
	await(table.unpack(thrs))

	crafting = false

	print('Craft done:', ok, err)

	if ok then
		rednet.send(id, {
			cmd = 'craft-reply',
			name = HOSTNAME,
			crafted = true,
			count = count,
		}, REDNET_PROTOCOL)
	else
		rednet.send(id, {
			cmd = 'craft-reply',
			name = HOSTNAME,
			crafted = false,
			err = err,
		}, REDNET_PROTOCOL)
	end
end

local function pollCommands()
	while true do
		local id, message = rednet.receive()
		if type(message) == 'table' then
			if message.cmd == 'ping' then
				-- rednet.send does not block
				rednet.send(id, {
					cmd = 'pong',
					name = HOSTNAME,
					type = 'turtle-crafter',
				}, REDNET_PROTOCOL)
			elseif message.cmd == 'prepare-craft' then
				if not crafting and (not preparing or os.clock() > prepareTimeout) then
					print('Preparing for', id, '...')
					preparing = id
					prepareTimeout = os.clock() + 5
					rednet.send(id, {
						cmd = 'prepare-craft-reply',
						name = HOSTNAME,
					}, REDNET_PROTOCOL)
				end
			elseif message.cmd == 'craft' then
				cmdCraft(id, message.source, message.recipe, message.count)
			end
		end
	end
end

function main(args)
	rednet.open(peripheral.getName(modem))
	rednet.host(REDNET_PROTOCOL, HOSTNAME)

	co_main(pollCommands)
end

main({...})
