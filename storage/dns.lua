-- CC Storage - Domain Name System
-- This program can let user customize the peripherals unique label and group label
-- by zyxkad@gmail.com

local dataDiskId = 2
local dataDiskDrive = assert(peripheral.find('drive', function(_, drive) return drive.getDiskID() == dataDiskId end))
local dataPath = dataDiskDrive.getMountPath()

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local network = require('network')

local peripheralList = {
	--  [label] = {
	--  	label = label,
	--  	name = peripheral.name,
	--  	groups = {
	--  		[groupName] = 1,
	--  		[groupName2] = 1,
	--  	} or nil
	--  },
}
local labelMap = {
	-- [peripheral.name] = label
}
local groupMap = {
	--  [groupName] = {
	--  	[label1] = 1,
	--  	[label2] = 1,
	--  	[label3] = 1,
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
	local fd = fs.combime(dataPath, 'peripherals.json')
	if fd then
		local list = textutils.unserialiseJSON(fd.readAll())
		if type(list) == 'table' then
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
						l[label] = 1
					else
						groups0[group] = {
							[label] = 1,
						}
					end
				end
			end
			peripheralList = list
			labelMap = labelMap0
			groupMap = groups0
		end
	end
end

function main()
	loadPeripheralList()

	network.setType('dns')
	peripheral.find('modem', function(modemSide)
		network.open(modemSide)
	end)

	-- lookup peripheral(s)
	network.registerCommand('lookup', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.type) == 'string' and type(payload.name) == 'string' then
			local name = payload.name
			if payload.type == 'group' then
				local l = groupMap[name]
				if l then
					local res = {}
					for _, label in ipairs(l) do
						res[label] = peripheralList[label]
					end
					reply(res)
				else
					reply(nil)
				end
			elseif payload.type == 'label' then
				local p = peripheralList[name]
				if p then
					reply(p)
				else
					reply(nil)
				end
			end
		end
	end)

	network.registerCommand('set-peripheral-label', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.name) == 'string' then
			local name, label = payload.name, payload.label
			if type(label) == 'string' then
				if not checkLabel(label) then
					reply('Label does not match pattern [0-9A-Za-z_-]+')
					return
				end
				local item = peripheralList[label]
				if item then
					if item.name == name then
						reply(true)
					else
						reply(string.format('Label "%s" is already exists', label))
					end
					return
				end
			else
				local oldLabel = labelMap[name]
				labelMap[name] = nil
				if oldLabel then
					local item = peripheralList[oldLabel]
					peripheralList[oldLabel] = nil
					if item.groups then
						for group, _ pairs(item.groups) do
							local labels = groupMap[group]
							labels[oldLabel] = nil
						end
					end
				end
				return
			end
			local oldLabel = labelMap[name]
			labelMap[name] = label
			if oldLabel and oldLabel ~= label then
				local item = peripheralList[oldLabel]
				item.label = label
				if item.groups then
					for group, _ pairs(item.groups) do
						local labels = groupMap[group]
						labels[oldLabel] = nil
						labels[label] = 1
					end
				end
			else
				peripheralList[label] = {
					label = label,
					name = name,
				}
			end
			reply(true)
		end
	end)

	network.registerCommand('set-label-peripheral', function(_, _, payload, reply)
		if type(payload) == 'table' and type(name) == 'string' and type(payload.label) == 'string' then
			local name, label = payload.name, payload.label
			if not checkLabel(label) then
				reply('Label does not match pattern [0-9A-Za-z_-]+')
				return
			end
			local item = peripheralList[label]
			if not item then
				reply(string.format('Label "%s" is not exists', label))
				return
			end
			item.name = name
			reply(true)
		end
	end)

	network.registerCommand('set-label-groups', function(_, _, payload, reply)
		if type(payload) == 'table' and type(payload.label) == 'string' then
			local label, groups = payload.label, payload.groups
			local item = peripheralList[label]
			if not item then
				reply(string.format('Label "%s" is not exists', label))
				return
			end
			local oldGroups = item.groups
			if oldGroups then
				for group, _ in pairs(oldGroups) do
					local l = groupMap[group]
					if l then
						l[label] = nil
					end
				end
			end
			if type(groups) == 'table' and #groups > 0 then
				for _, group in ipairs(groups) do
					local l = groupMap[group]
					if l then
						l[label] = 1
					else
						groupMap[group] = {
							[label] = 1,
						}
					end
				end
			end
			reply(true)
		end
	end)

	co_main(network.run)
end

main()
