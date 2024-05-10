-- CC Storage - Domain Name System Server
-- This program can let user customize the peripherals unique label and group label
-- by zyxkad@gmail.com

local dataDiskId = 2
local dataDiskDrive = assert(peripheral.find('drive', function(_, drive) return drive.getDiskID() == dataDiskId end))
local DATA_PATH = dataDiskDrive.getMountPath()
local DATAFILE_NAME = 'peripherals.json'
local DATAFILE_PATH = fs.combine(DATA_PATH, DATAFILE_NAME)

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local network = require('network')

local dataDirty = false
local function setDirty()
	dataDirty = true
end

local peripheralList = {
	--  [label] = {
	--  	label = label,
	--  	name = peripheral.name,
	--  	groups = {
	--  		[groupName] = true,
	--  		[groupName2] = true,
	--  	} or nil
	--  },
}

local labelMap = {
	-- [peripheral.name] = label
}

local groupMap = {
	--  [groupName] = {
	--  	[label1] = true,
	--  	[label2] = true,
	--  	[label3] = true,
	--  }
}

local function checkLabel(label)
	local i, j = label:find('[0-9A-Za-z_-]+')
	if i and i == 1 and j == #label then
		return false
	end
	return true
end

local function loadPeripheralList()
	if not fs.exists(DATAFILE_PATH) then
		return true
	end
	local fd, err = fs.open(DATAFILE_PATH, 'r')
	if not fd then
		return nil, err
	end
	local list = textutils.unserialiseJSON(fd.readAll())
	if type(list) ~= 'table' then
		return nil, 'root data is not a object'
	end
	local labelMap0 = {}
	local groups0 = {}
	for label, item in pairs(list) do
		assert(type(item.label) == 'string')
		assert(type(item.name) == 'string')
		assert(item.label == label)
		labelMap0[item.name] = label
		for _, group in ipairs(item.groups0) do
			local l = groups0[group]
			if l then
				l[label] = true
			else
				groups0[group] = {
					[label] = true,
				}
			end
		end
	end
	peripheralList = list
	labelMap = labelMap0
	groupMap = groups0
	return true
end

local function savePeripheralList()
	local data = textutils.serialiseJSON(peripheralList)
	local fd, err = fs.open(DATAFILE_PATH, 'w')
	if not fd then
		return nil, err
	end
	fd.write(data)
	fd.close()
	return true
end

-- bindLabel binds a label to a peripheral name
-- if name is nil, the label will be removed
local function bindLabel(label, name)
	if not checkLabel(label) then
		return nil, 'Label does not match pattern [0-9A-Za-z_-]+'
	end
	local item = peripheralList[label]
	if not item then
		return nil, string.format('Label "%s" is not exists', label)
	end

	setDirty()

	if name ~= nil then
		item.name = name
		return true
	end
	peripheralList[label] = nil
	for group, _ in pairs(item.groups) do
		local labels = groupMap[group]
		if labels then
			labels[label] = nil
		end
	end
	return true
end

-- addLabelGroup adds a group tag to the label
local function addLabelGroup(label, group)
	if not checkLabel(label) then
		return nil, 'Label does not match pattern [0-9A-Za-z_-]+'
	end
	if not checkLabel(group) then
		return nil, 'Group name does not match pattern [0-9A-Za-z_-]+'
	end
	local item = peripheralList[label]
	if item.groups[group] then
		return true
	end

	setDirty()

	item.groups[group] = true
	local labels = groupMap[label]
	if labels then
		labels[label] = true
	else
		groupMap[label] = true
	end
end

-- removeLabelGroup removes a group tag from the label
local function removeLabelGroup(label, group)
	if not checkLabel(label) then
		return nil, 'Label does not match pattern [0-9A-Za-z_-]+'
	end
	if not checkLabel(group) then
		return nil, 'Group name does not match pattern [0-9A-Za-z_-]+'
	end

	local item = peripheralList[label]
	if not item.groups[group] then
		return true
	end

	setDirty()

	item.groups[group] = nil
	local labels = groupMap[label]
	if labels then
		labels[label] = nil
		-- TOOD: cleanup empty groups
	end
end

local function scheduledSave()
	while true do
		sleep(0)
		if dataDirty then
			dataDirty = false
			local ok, err = savePeripheralList()
			if not ok then
				printError('ERR: Cannot save peripheral list:')
				printError(err)
			end
			sleep(3)
		end
	end
end

function main()
	local ok, err = loadPeripheralList()
	if not ok then
		printError('ERR: Cannot load peripheral list:')
		printError(err)
	end

	network.setType('dns')
	peripheral.find('modem', function(modemSide)
		network.open(modemSide)
	end)

	network.registerCommand('lookup-label', function(_, _, payload, reply)
		if type(payload) == 'string' then
			local p = peripheralList[payload]
			if p then
				reply(p)
			else
				reply(nil)
			end
		end
	end)

	network.registerCommand('lookup-group', function(_, _, payload, reply)
		if type(payload) == 'string' then
			local l = groupMap[payload]
			if l then
				local res = {}
				for label, _ in pairs(l) do
					res[label] = peripheralList[label]
				end
				reply(res)
			else
				reply(nil)
			end
		end
	end)

	network.registerCommand('bind-label-name', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.label) == 'string' then
			local name, label = payload.name, payload.label
			local ok, err = bindLabel(label, name)
			if ok then
				reply(true)
			else
				reply(err)
			end
		end
	end)

	network.registerCommand('add-label-group', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.label) == 'string' and type(payload.group) == 'string' then
			local label, group = payload.label, payload.group
			local ok, err = addLabelGroup(label, group)
			if ok then
				reply(true)
			else
				reply(err)
			end
		end
	end)

	network.registerCommand('remove-label-group', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.label) == 'string' and type(payload.group) == 'string' then
			local label, group = payload.label, payload.group
			local ok, err = removeLabelGroup(label, group)
			if ok then
				reply(true)
			else
				reply(err)
			end
		end
	end)

	co_main(network.run, scheduledSave)
end

main()
