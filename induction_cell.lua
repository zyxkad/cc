-- mekanism induction cell tools
-- by zyxkad@gmail.com

if not parallel then
	error('Need parallel API')
end

chatbox = peripheral.find('chatBox')
assert(chatbox, 'Cannot find chat box')
cell = peripheral.wrap('bottom')
assert(cell, 'Cannot find induction cell')

k = 1000
M = k * 1000
G = M * 1000
T = G * 1000
P = T * 1000

units = {
	'k', 'M', 'G', 'T', 'P',
}

local function formatEnergy(fe)
	local prefix = ''
	local negative = fe < 0
	if negative then
		fe = -fe
	end
	for _, u in ipairs(units) do
		if fe < 1000 then
			break
		end
		prefix = u
		fe = fe / 1000
	end
	if negative then
		fe = -fe
	end
	return string.format('%.2f %sFE', fe, prefix)
end

local function formatSec(tm)
	unit = 's'
	if tm > 60 then
		unit = 'm'
		tm = tm / 60
		if tm > 60 then
			unit = 'h'
			tm = tm / 60
			if tm > 24 then
				unit = 'd'
				tm = tm / 24
			end
		end
	end
	return string.format('%.2f%s', tm, unit)
end

local energy = 0
local inputRate = 0
local outputRate = 0
local lossing = false
local gainRate = 0
local lastUpdate = 0

local function updateData()
	energy = cell.getEnergy() / 2.5 -- J to RF
	maxEnergy = cell.getMaxEnergy() / 2.5
	inputRate = cell.getLastInput() / 2.5
	outputRate = cell.getLastOutput() / 2.5
	gainRate = inputRate - outputRate
	lossing = gainRate < 0
	if lossing then
		gainRate = -gainRate
	end
	lastUpdate = os.clock()
end

local function sendMessage(msg, target)
	if type(msg) ~= 'str' then
		assert(type(msg) == 'table', 'Message must be a string or a table')
		if msg[1] then -- if it's an array
			msg = {
				text = '',
				extra = msg,
			}
		end
		msg = textutils.serialiseJSON(msg)
	end
	if target then
		local i = 0
		for i = 0, 101 do
			if chatbox.sendFormattedMessageToPlayer(msg, target, 'CK Induction Cell') then
				break
			end
			sleep(0.05)
		end
	else
		repeat sleep(0.05) until chatbox.sendFormattedMessage(msg, 'CK Induction Cell')
	end
end

local function sendEnergyWarn()
	sendMessage({
		{
			text = '****',
			obfuscated = true,
		},
		{
			text = ' WARN: Energy not enough, only ',
			color = 'gold',
			bold = true,
		},
		{
			text = formatEnergy(energy),
			color = 'red',
			underlined = true,
			bold = true,
		},
		{
			text = ' left.',
			color = 'gold',
			bold = true,
		},
		lossing and
			{
				text = ' Energy loss rate: ',
				color = 'dark_red',
			} or
			{
				text = ' Energy gain rate: ',
				color = 'aqua',
			},
		{
			text = string.format('%s/t', formatEnergy(gainRate)),
			color = 'yellow',
			underlined = true,
		},
		{
			text = '****',
			obfuscated = true,
		},
	})
end

local function sendStat()
	sendMessage({
		{
			text = '\n - Energy: ',
			color = 'green',
		},
		{
			text = formatEnergy(energy),
			color = 'yellow',
		},
		{
			text = ' / ',
			color = 'yellow',
		},
		{
			text = formatEnergy(maxEnergy),
			color = 'yellow',
		},
		{
			text = '\n - Energy Input: ',
			color = 'blue',
		},
		{
			text = formatEnergy(inputRate)..'/t',
			color = 'blue',
		},
		{
			text = '\n - Energy Output: ',
			color = 'dark_purple',
		},
		{
			text = formatEnergy(outputRate)..'/t',
			color = 'dark_purple',
		},
		lossing and
			{
				text = '\n - Energy Lossing: ',
				color = 'dark_red',
			} or
			{
				text = '\n - Energy Gaining: ',
				color = 'aqua',
			},
		{
			text = formatEnergy(gainRate)..'/t',
			color = lossing and 'dark_red' or 'aqua',
		},
		lossing and
			{
				text = string.format('\n - Empty after %s', formatSec(energy / gainRate / 20)),
				color = 'light_purple'
			} or
			{
				text = string.format('\n - Fully charged after %s', formatSec((maxEnergy - energy) / gainRate / 20)),
				color = 'dark_green'
			},
	})
end

local function main(args)
	local function pollEnergy()
		redstone.setOutput('back', true)
		local lastWarn = -0x7fffffff
		local lastLoosing = false
		while true do
			if energy < 10 * T then
				redstone.setOutput('back', true)
				if lossing and os.clock() - lastWarn > 10 then
					sendEnergyWarn()
					lastWarn = os.clock()
				end
			elseif energy < 100 * T then
				if lossing and os.clock() - lastWarn > 600 then
					sendEnergyWarn()
					lastWarn = os.clock()
				end
			elseif not lastLoosing and lossing then
				lastLoosing = true
				sendMessage({
					{
						text = '****',
						obfuscated = true,
					},
					{
						text = ' WARN: Energy start lossing. ',
						color = 'gold',
						bold = true,
					},
					{
						text = ' Energy loss rate: ',
						color = 'dark_red',
					},
					{
						text = string.format('%s/t', formatEnergy(gainRate)),
						color = 'yellow',
						underlined = true,
					},
					{
						text = string.format('. Cell will empty after %s', formatSec(energy / gainRate / 20)),
						color = 'light_purple',
					},
					{
						text = '****',
						obfuscated = true,
					},
				})
			else
				redstone.setOutput('back', false)
			end
			if not lossing and lastLoosing then
				lastLoosing = false
			end
			sleep(0.1)
		end
	end

	local function pollCommand()
		while true do
			local _, sender, msg = os.pullEvent('chat')
			if msg == '.stat' then
				sendStat()
			end
		end
	end

	parallel.waitForAny(function()
		while true do
			updateData()
			sleep(0.05)
		end
	end, pollEnergy, pollCommand)
end

main({...})
