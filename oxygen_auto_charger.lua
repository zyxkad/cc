-- Oxygen Tank auto recharger for Ad Astra Giselle Addon
-- by zyxkad@gmail.com

-- configs
local tankInputSide = 'left'
local tankOutputSide = 'bottom'
local refillWhenLessThan = 100
local onlyGiveNetheriteCan = false

-- constants
local msgPrompt = 'O2 Charger'
local oxygenCanId = 'ad_astra_giselle_addon:oxygen_can'
local netheriteOxygenCanId = 'ad_astra_giselle_addon:netherite_oxygen_can'

local iv = peripheral.find("inventoryManager")
if not iv then
	error('No inventory manager was found')
end

local chatbox = peripheral.find('chatBox')
if not chatbox then
	printError('WARN: No chat box was found')
end

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local function sendMessage(msg, target)
	if not chatbox then
		return false
	end
	if type(msg) == 'table' then
		if msg['text'] == nil then -- if it's an array
			msg = {
				text = '',
				extra = msg,
			}
		end
		msg = textutils.serialiseJSON(msg)
	elseif type(msg) == 'str' then
		msg = textutils.serialiseJSON({
			text = msg,
		})
	else
		error('Message must be a string or a table')
	end
	if target then
		local i = 0
		for i = 0, 101 do
			if chatbox.sendFormattedMessageToPlayer(msg, target, msgPrompt) then
				return true
			end
			sleep(0.05)
		end
		return false
	end
	repeat sleep(0.05) until chatbox.sendFormattedMessage(msg, msgPrompt)
	return true
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
		if res[2] == 'Terminated' then
			error(res[2])
		end
		sendErrorMsg(res[2], player)
	end
	return table.unpack(res)
end

local function getTanks()
	local tanks = {}
	for _, item in ipairs(iv.getItems()) do
		if item.name == oxygenCanId or item.name == netheriteOxygenCanId then
			if item.nbt and
				 item.nbt.BotariumData and
				 item.nbt.BotariumData.StoredFluids and
				 item.nbt.BotariumData.StoredFluids[0] then
				local fluid = item.nbt.BotariumData.StoredFluids[0]
				local oxygens = fluid.Amount
				tanks[#tanks + 1] = {
					name = item.name,
					displayName = item.displayName,
					nbt = item.nbt,
					slot = item.slot,
					tags = item.tags,
					oxygens = oxygens,
				}
			end
		end
	end
	return tanks
end

local function giveTank()
	if not onlyGiveNetheriteCan and
		 iv.addItemToPlayerNBT(tankOutputSide, 1, nil, { name=oxygenCanId }) == 1 then
		return oxygenCanId
	end
	if iv.addItemToPlayerNBT(tankOutputSide, 1, nil, { name=netheriteOxygenCanId }) == 1 then
		return netheriteOxygenCanId
	end
	sendErrorMsg('Cound not find vaild oxygen can', iv.getOwner())
	return nil
end

function main(args)
	local owner = nil
	function check()
		while true do
			do
				local newowner = iv.getOwner()
				while not newowner do -- wait until player online
					sleep(1)
					newowner = iv.getOwner()
				end
				if newowner ~= owner then
					owner = newowner
					print('Program runs for '..owner)
					sendMessage({
						text = 'Oxygen auto recharger online',
						color = 'light_purple',
					}, owner)
				end
			end
			local ok, tanks = playerCall(owner, getTanks)
			if ok then
				-- TODO: calc total oxygen amount
				for _, tank in ipairs(tanks) do
					repeat
						if tank.oxygens <= refillWhenLessThan then
							if not giveTank() and tank.oxygens > 0 then
								break
							end
							if not iv.removeItemFromPlayerNBT(tankInputSide, 1, nil, { name=tank.name, fromSlot=tank.slot }) then
								break
							end
							sendMessage({
								{
									text = 'Success refilled tank ',
									color = 'green',
								},
								{
									text = trim(tank.displayName),
									color = 'aqua',
									underlined = true,
								}
							}, owner)
						end
					until true
				end
			end
			sleep(0.2)
		end
	end
	function listenCmd()
		while true do
			local _, player, msg = os.pullEvent('chat')
			if player == owner then
				if msg == 'o2' then
					giveTank()
				end
			end
		end
	end
	parallel.waitForAny(
		check,
		listenCmd
	)
end

main({...})
