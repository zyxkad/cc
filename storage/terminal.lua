-- CC Storage - Terminal
-- by zyxkad@gmail.com

---- BEGIN CONFIG ----

local modemSide = 'left'

local function split(s, sep)
	local i, j = string.find(s, sep, 1, true)
	if not i then
		return s, ''
	end
	return s:sub(1, i - 1), s:sub(j + 1)
end

local invManagers = {}
local CONFIG_FILENAME = 'chat_terminal.cfg'
do
	local fd = fs.open(CONFIG_FILENAME, 'r')
	if fd then
		while true do
			local line = fd.readLine()
			if not line or #line == 0 then
				break
			end
			local invManagerName, line = split(line, '=')
			local invManager = peripheral.wrap(invManagerName)
			if not peripheral.hasType(invManagerName, 'inventoryManager') then
				error(string.format('Inventory manager %s not found', invManagerName))
			end
			local cacheInvName, cacheInvSide = split(line, '/')
			local cacheInv = peripheral.wrap(cacheInvName)
			if not peripheral.hasType(cacheInvName, 'inventory') then
				error(string.format('Cache inventory chest %s not found', cacheInvName))
			end
			invManagers[invManagerName] = {
				manager = invManager,
				cacheName = cacheInvName,
				cache = cacheInv,
				cacheSide = cacheInvSide,
			}
		end
		fd.close()
	else
		local fd = fs.open(CONFIG_FILENAME, 'w')
		fd.write('inventoryManager_N=minecraft:chest_N/front\n')
		fd.close()
		error(string.format('Config file %s was not exsits, created a new one.', CONFIG_FILENAME), 1)
	end
end

---- END CONFIG ----

local REDNET_PROTOCOL = 'storage'

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function equals(o1, o2, cmpMeta)
	if o1 == o2 then
		return true
	end
	local o1Type = type(o1)
	local o2Type = type(o2)
	if o1Type ~= o2Type or o1Type ~= 'table' then
		return false
	end

	if cmpMeta then
		local mt1 = getmetatable(o1)
		if mt1 and mt1.__eq then
			-- compare using built in method
			return o1 == o2
		end
	end

	local keySet = {}

	for key, value1 in pairs(o1) do
		local value2 = o2[key]
		if value2 == nil or not equals(value1, value2, cmpMeta) then
			return false
		end
		keySet[key] = true
	end

	for key, _ in pairs(o2) do
		if not keySet[key] then
			return false
		end
	end
	return true
end

local function itemIndexName(item)
	local name = item.name
	if item.nbt then
		name = name .. ';' .. item.nbt
	end
	return name
end

local function pollChatbox()
	while true do
		local box = peripheral.find('chatBox', function(_, chatbox) return chatbox.getOperationCooldown('chatMessage') == 0 end)
		if box then
			return box
		end
		sleep(0.1)
	end
end

local function query()
	local data = {}
	rednet.broadcast({ cmd='query-storage' }, REDNET_PROTOCOL)
	local endTime = os.clock() + 10
	repeat
		local id, reply = rednet.receive(REDNET_PROTOCOL, 0.5)
		if not id then
			break
		elseif type(reply) == 'table' and reply.cmd == 'query-storage-reply' then
			data[id] = reply.data
		end
	until os.clock() > endTime
	return data
end

local function countedToSorted(counted, sortFn)
	local sorted = {}
	for name, data in pairs(counted) do
		local i = name:find(';')
		local nbt = nil
		if i then
			nbt = name:sub(i + 1)
			name = name:sub(1, i - 1)
		end
		sorted[#sorted + 1] = {
			name = name,
			displayName = data.displayName,
			count = data.count,
			nbt = nbt,
		}
	end
	table.sort(sorted, sortFn)
	return sorted
end

local totalSlots = 0
local usedSlots = 0
local actualSlots = 0
local queriedData = {}
local sortedByNum = {}
local sortedByName = {}

local function searchItem(name, nbt, count)
	local notFound = true
	local storages = {}
	local ind = itemIndexName({ name=name, nbt=nbt })
	for id, data in pairs(queriedData) do
		local item = data.counted[ind]
		if item and item.count > 0 then
			local takingCount = math.min(count, item.count)
			storages[id] = takingCount
			count = count - takingCount
			notFound = false
		end
		if count == 0 then
			break
		end
	end
	if notFound then
		return nil
	end
	return storages, count
end

local function takeFromStorage(cfgData, name, nbt, count)
	local storages = searchItem(name, nbt, count)
	if not storages then
		return false
	end
	local waiting = 0
	for id, ct in pairs(storages) do
		rednet.send(id, {
			cmd = 'take',
			name = name,
			nbt = nbt,
			count = ct,
			target = cfgData.cacheName,
		}, REDNET_PROTOCOL)
		waiting = waiting + 1
	end
	local received = 0
	local endTime = os.clock() + 10
	while waiting > 0 and os.clock() <= endTime do
		local id, message = rednet.receive(REDNET_PROTOCOL, 5)
		if not id then
			break
		elseif type(message) == 'table' and message.cmd == 'take-reply' and storages[id] then
			received = received + message.pushed
			waiting = waiting - 1
		end
	end
	return true, received
end

local function putToStorage(cfgData)
	local slots = {}
	for slot, item in pairs(cfgData.cache.list()) do
		slots[slot] = item.count
	end
	rednet.broadcast({
		cmd = 'put',
		source = cfgData.cacheName,
		slots = slots,
	}, REDNET_PROTOCOL)
end


local function pollData()
	local function addupCounts(counts)
		local counted = {}
		local totalSlots = 0
		local usedSlots = 0
		local actualSlots = 0
		for _, ct in pairs(counts) do
			totalSlots = totalSlots + ct.totalSlot
			usedSlots = usedSlots + ct.usedSlot
			actualSlots = actualSlots + ct.actualSlot
			for name, data in pairs(ct.counted) do
				local c = counted[name]
				if c then
					c.count = c.count + data.count
					c.usedSlot = c.usedSlot + data.usedSlot
				else
					counted[name] = {
						displayName = data.displayName,
						count = data.count,
						usedSlot = data.usedSlot,
						maxCount = data.maxCount,
					}
				end
			end
		end
		return counted, totalSlots, usedSlots, actualSlots
	end

	queriedData = query()
	counted, totalSlots, usedSlots, actualSlots = addupCounts(queriedData)
	sortedByNum = countedToSorted(counted, function(a, b)
		return a.count > b.count or (a.count == b.count and a.name < b.name)
	end)
	sortedByName = countedToSorted(counted, function(a, b)
		return a.name < b.name or (a.name == b.name and a.count > b.count)
	end)
	while true do
		local id, message = rednet.receive(REDNET_PROTOCOL)
		if type(message) == 'table' and message.cmd == 'update-storage' then
			queriedData[id] = message.data
			local endTime = os.clock() + 10
			repeat
				local id, message = rednet.receive(REDNET_PROTOCOL, 0)
				if not id then
					break
				elseif type(message) == 'table' and message.cmd == 'update-storage' then
					queriedData[id] = message.data
				end
			until os.clock() > endTime
			counted, totalSlots, usedSlots, actualSlots = addupCounts(queriedData)
			sortedByNum = countedToSorted(counted, function(a, b)
				return a.count > b.count or (a.count == b.count and a.name < b.name)
			end)
			sortedByName = countedToSorted(counted, function(a, b)
				return a.name < b.name or (a.name == b.name and a.count > b.count)
			end)
		end
	end
end

local offset = 0

local function render()
	while true do
		local sorted = sortedByNum
		if offset >= #sorted and #sorted ~= 0 then
			offset = #sorted - 1
		elseif offset < 0 then
			offset = 0
		end
		local width, height = term.getSize()
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.black)
		term.clear()
		term.setCursorPos(1, 1)
		term.setTextColor(colors.black)
		term.setBackgroundColor(colors.lightGray)
		term.clearLine()
		term.write('  CC Storage - Terminal  Line[' .. (offset + 1) .. '/' .. #sorted .. ']')

		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.black)
		for i, data in ipairs(sorted) do
			local y = i - offset
			if 1 <= y and y < height then
				term.setCursorPos(1, 1 + y)
				term.write(string.format('%d * [%s] %s', data.count, data.name, data.displayName))
			end
		end
		term.setCursorPos(1, height)
		term.setTextColor(colors.black)
		term.setBackgroundColor(colors.lightGray)
		term.clearLine()
		term.write(string.format(' %.1f%% %.1f / %d / %d', actualSlots / totalSlots * 100, usedSlots, actualSlots, totalSlots))
		sleep(0.1)
	end
end

local CHAT_NAME = '§eCC Storage Terminal§r'
local CHAT_HEAD = '§a============== §e§lCC Storage Terminal§r§a ==============='
local CHAT_WIDTH = 53

local function onCommand(cfgData, player, msg)
	if msg == '.ping' then
		pollChatbox().sendMessageToPlayer('Usage:\n' ..
			'  $.ping : Show this message\n' ..
			'  $.query [<pattern>] : List item in storage (matchs pattern)\n' ..
			'  $.put [<slot>] : Put the item on hand (or at slot) into storage\n' ..
			'  $.take <item> [<count>] : Take item from storage',
		player, CHAT_NAME, '##', '§a')
	elseif msg == '.share' then
		local item = cfgData.manager.getItemInHand()
		if not item then
			return
		end
		pollChatbox().sendFormattedMessage(textutils.serialiseJSON({
			text = item.displayName,
			color = 'aqua',
			hoverEvent = {
				action = 'show_item',
				contents = {
					id = item.name,
					count = item.count,
					nbt = item.nbt,
				},
			},
		}), player, '<>')
	elseif msg == '.query' or startswith(msg, '.query ') then
		local param = msg:sub(#'.query ' + 1):lower()
		local reply = {}
		local sorted = sortedByNum
		local ct = 0
		for i, data in ipairs(sorted) do
			if #param == 0 or data.name:lower():find(param) or data.displayName:lower():find(param) then
				ct = ct + 1
				if ct >= 95 then
					break
				end
				local takeId = data.name
				if data.nbt then
					takeId = takeId .. ';' .. data.nbt
				end
				reply[#reply + 1] = {
					text = '\n',
				}
				reply[#reply + 1] = {
					text = '[-]',
					color = 'red',
					underlined = true,
					clickEvent = {
						action = 'suggest_command',
						value = '$.take ' .. takeId .. ' ',
					},
					hoverEvent = {
						action = 'show_text',
						value = 'Click to take item',
					}
				}
				reply[#reply + 1] = {
					text = ' ',
				}
				reply[#reply + 1] = {
					text = string.format('%d * ', data.count),
					clickEvent = {
						action = 'copy_to_clipboard',
						value = takeId,
					},
					extra = {
						{
							-- Three space will show the item icon
							text = string.format('   [%s]', data.displayName:sub(1, 32)),
							color = 'aqua',
							hoverEvent = {
								action = 'show_item',
								contents = {
									id = data.name,
									count = data.count,
								},
							},
						},
					}
				}
			end
		end
		reply[#reply + 1] = {
			text = '\n' .. string.format('Found %d results', ct),
		}
		reply[#reply + 1] = {
			text = '\n' .. string.format('Usage: %.1f%% %.1f / %d / %d', actualSlots / totalSlots * 100, usedSlots, actualSlots, totalSlots),
		}
		reply[#reply + 1] = {
			text = '\n' .. string.rep('=', CHAT_WIDTH),
			color = 'green',
		}
		pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
			text = '',
			extra = reply,
		}), player, CHAT_HEAD, '==', '§a')
	elseif startswith(msg, '.take ') then
		local param = msg:sub(#'.take ' + 1)
		local name, nbt, count
		local i = param:find(' ')
		if i then 
			name = param:sub(1, i - 1)
			count = tonumber(param:sub(i + 1))
		else
			name = param
		end
		name, nbt = split(name, ';')
		if #nbt == 0 then
			nbt = nil
		end
		count = count or 1
		pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
			text = '',
			extra = {
				{
					text = 'Taking ',
				},
				{
					text = string.format('[%s] * %d', name, count),
					color = 'aqua',
					clickEvent = {
						action = 'copy_to_clipboard',
						value = name,
					},
					hoverEvent = {
						action = 'show_item',
						contents = {
							id = name,
							count = count,
						},
					},
				}
			},
		}), player, CHAT_NAME, '##', '§a')
		local ok, received = takeFromStorage(cfgData, name, nbt, count)
		if not ok then
			pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
				text = 'Error: Cannot found item ' .. name,
				color = 'red',
				bold = true,
			}), player, CHAT_NAME, '##', '§a')
			return
		end
		local thrs = {}
		local count = 0
		for slot, item in pairs(cfgData.cache.list()) do
			if item.name == name and item.nbt == nbt then
				local icount = item.count
				count = count + icount
				if count > received then
					icount = icount + received - count
					count = received
				end
				thrs[#thrs + 1] = co_run(function()
					return cfgData.manager.addItemToPlayerNBT(cfgData.cacheSide, icount, nil, { fromSlot = slot - 1 })
				end)
				if count == received then
					break
				end
			end
		end
		await(table.unpack(thrs))
		pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
			text = '',
			extra = {
				{
					text = 'Received ',
					color = 'blue',
				},
				{
					text = string.format('   [%s]', name),
					color = 'aqua',
					clickEvent = {
						action = 'copy_to_clipboard',
						value = name,
					},
					hoverEvent = {
						action = 'show_item',
						contents = {
							id = name,
							count = received,
						},
					},
				},
				{
					text = string.format(' * %d', received)
				}
			},
		}), player, CHAT_NAME, '##', '§a')
	elseif msg == '.put' or startswith(msg, '.put ') then
		local param = msg:sub(#'.put ' + 1)
		local slot = tonumber(param)
		local count = 64
		if not slot then
			local list, item
			await(function()
				list = cfgData.manager.list()
			end, function()
				item = cfgData.manager.getItemInHand()
			end)
			if not item or not next(item) then
				pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = 'Error: Please hand an item or give a slot number',
					color = 'red',
					bold = true,
				}), player, CHAT_NAME, '##', '§a')
				return
			end
			count = item.count
			for _, data in pairs(list) do
				if data and data.name == item.name and data.count == item.count and equals(data.nbt, item.nbt) then
					slot = data.slot
					break
				end
			end
			if not slot then
				pollChatbox().sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = 'Error: Cannot find same item',
					color = 'red',
					bold = true,
				}), player, CHAT_NAME, '##', '§a')
				return
			end
		end
		pollChatbox().sendMessageToPlayer(string.format('Sending slot %d', slot), player, CHAT_NAME, '##', '§a')
		cfgData.manager.removeItemFromPlayerNBT(cfgData.cacheSide, count, nil, { fromSlot=slot })
		putToStorage(cfgData)
	end
end

local function pollEvent()
	local lastMsgTick = 0
	local lastMsgs = {}
	while true do
		local event, p1, p2 = os.pullEvent()
		if event == 'mouse_scroll' then
			local dir = p1
			offset = offset + dir
		elseif event == 'key' then
			local key = p1
			if key == keys.up then
				offset = offset - 1
			elseif key == keys.down then
				offset = offset + 1
			end
		elseif event == 'chat' then
			local now = os.clock()
			if lastMsgTick ~= now then
				lastMsgTick = now
				lastMsgs = {}
			end
			local player, msg = p1, p2
			local fullMsg = player .. '/' .. msg
			if not lastMsgs[fullMsg] then
				lastMsgs[fullMsg] = true
				for _, cfgData in pairs(invManagers) do
					local owner = cfgData.manager.getOwner()
					if owner and player == owner then
						co_run(onCommand, cfgData, player, msg)
						break
					end
				end
			end
		end
	end
end

function main(args)
	rednet.open(modemSide)

	co_main(pollData, render, pollEvent)
end

main({...})
