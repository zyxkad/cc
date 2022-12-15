
local iv = peripheral.find("inventoryManager")
if not iv then
	error('No player detector was found')
end

local chatbox = peripheral.find('chatBox')
if not chatbox then
	error('No chat box was found')
end

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function sendErrorMsg(msg, player)
	return chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
		text = 'ERROR: ',
		color = 'red',
		extra = {
			{
				text = msg,
				underlined = true,
			}
		}
	}), player)
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
			if msg == '#dump' then
				local start = os.clock()
				local ls = iv.list()
				local total = 0
				for _, d in ipairs(ls) do
					local ok, amount = playerCall(owner, iv.removeItemFromPlayer, invSide, d.count, d.slot)
					if ok then
						total = total + amount
					end
				end
				local uset = os.clock() - start
				chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = string.format('Dumped %d items, used ', total),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}), owner)
			elseif startswith(msg, '#dump ') then
				local slot = tonumber(msg:sub(7))
				local start = os.clock()
				local ls = iv.list()
				local total = 0
				for _, d in ipairs(ls) do
					if d.slot == slot then
						local ok, amount = playerCall(owner, iv.removeItemFromPlayer, invSide, d.count, slot)
						if ok then
							total = amount
						end
						break
					end
				end
				local uset = os.clock() - start
				chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = string.format('Dumped %d items in slot %d, used ', total, slot),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}), owner)
			elseif msg == '#takeall' then
				local start = os.clock()
				local total = 0
				while true do
					if not iv.isSpaceAvailable() then
						sendErrorMsg('Send item error, no space available', owner)
						break
					end
					local ok, amount = playerCall(owner, iv.addItemToPlayer, invSide, 64)
					if not ok or amount == 0 then
						break
					end
					total = total + amount
				end
				local uset = os.clock() - start
				chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = string.format('Sended %d items, used ', total),
					color = 'aqua',
					extra = {
						{
							text = string.format('%.2fs', uset),
							italic = true,
						}
					}
				}), owner)
			end
		end
	end
end

main({...})
