-- Inventory Manager
-- by zyxkad@gmail.com

local iv = peripheral.find("inventoryManager")
if not iv then
	error('No inventory manager was found')
end

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function pollChatbox()
	while true do
		local box = peripheral.find('chatBox', function(_, chatbox) return chatbox.getOperationCooldown('chatMessage') == 0 end)
		if box then
			return box
		end
		sleep(0)
	end
end

local function sendMessage(msg, target)
	if type(msg) == 'table' then
		if msg['text'] == nil then -- if it's an array
			msg = {
				text = '',
				extra = msg,
			}
		end
		msg = textutils.serialiseJSON(msg)
	elseif type(msg) ~= 'str' then
		error('Message must be a string or a table')
	end
	local chatbox = pollChatbox()
	if target then
		chatbox.sendFormattedMessageToPlayer(msg, target, msgPrompt)
	else
		chatbox.sendFormattedMessage(msg, msgPrompt)
	end
end

local function sendErrorMsg(msg, player)
	return sendMessage({
		text = 'ERROR: ',
		color = 'red',
		extra = {
			{
				text = msg,
				underlined = true,
			}
		}
	}, player)
end

local function playerCall(player, func, ...)
	local res = {pcall(func, ...)}
	if not res[1] then
		sendErrorMsg(res[2], player)
	end
	return table.unpack(res)
end

function main(args)
	local invSide = args[1]
	if not invSide then
		error('You must give a inventory side', 2)
	end
	local owner = iv.getOwner()
	if not owner then
		error('inventory manager must bind to a player', 2)
	end
	print('Program runs for '..owner)
	while true do
		local event, p, msg = os.pullEvent('chat')
		if p == owner then
			if msg == 'dump' then
				local start = os.clock()
				local total = 0
				for _, d in ipairs(iv.getItems()) do
					local ok, amount = playerCall(owner, iv.removeItemFromPlayer, invSide, {fromSlot=d.slot})
					if ok and amount then
						total = total + amount
					end
				end
				for _, d in ipairs(iv.getArmor()) do
					local ok, amount = playerCall(owner, iv.removeItemFromPlayer, invSide, {fromSlot=39 + d.slot})
					if ok and amount then
						total = total + amount
					end
				end
				local uset = os.clock() - start
				sendMessage({
					text = string.format('Dumped %d items, used ', total),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}, owner)
			elseif startswith(msg, 'dump ') then
				local slot = tonumber(msg:sub(7))
				local start = os.clock()
				local ok, total = playerCall(owner, iv.removeItemFromPlayer, invSide, {fromSlot=slot})
				local uset = os.clock() - start
				sendMessage({
					text = string.format('Dumped %d items in slot %d, used ', total, slot),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}, owner)
			elseif msg == 'takeall' then
				local start = os.clock()
				local total = 0
				for _, d in ipairs(iv.listChest(invSide)) do
					local ok, amount = playerCall(owner, iv.addItemToPlayer, invSide, {fromSlot=d.slot})
					if ok and amount then
						total = total + amount
					end
				end
				local uset = os.clock() - start
				sendMessage({
					text = string.format('Sended %d items, used ', total),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}, owner)
			end
		end
	end
end

main({...})
