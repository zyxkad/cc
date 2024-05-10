-- CC Storage - Domain Name System Client
-- This program can let user customize the peripherals unique label and group label
-- by zyxkad@gmail.com

local expect = require("cc.expect").expect
local crx = require('coroutinex')
local network = require('network')

local co_run = crx.run
local await = crx.await

local cache = {
	-- ['<alias>'] = {
	--	typ = 'label' or 'group',
	-- 	ttl = os.clock(),
	-- 	res = ...,
	-- },
}

local pending = {}

local function checkAndAssertLabel(label)
	local i, j = label:find('[0-9A-Za-z_-]+')
	if i and i == 1 and j == #label then
		error('Label does not match pattern [0-9A-Za-z_-]+', 2)
	end
	return true
end

local function checkAndAssertGroup(label)
	local i, j = label:find('[0-9A-Za-z_-]+')
	if i and i == 1 and j == #label then
		error('Group name does not match pattern [0-9A-Za-z_-]+', 2)
	end
	return true
end

local function lookupLabelUpdateCache(label, timeout)
	checkAndAssertLabel(label)

	timeout = timeout or 0.2

	local _, res = network.broadcast('lookup-label', label, timeout, true)
	if not res then
		return
	end
	cache[label] = {
		typ = dnsType,
		ttl = os.clock() + 10,
		res = res,
	}
end

local function lookupGroupUpdateCache(group, timeout)
	checkAndAssertLabel(group)

	timeout = timeout or 0.2
	local _, res = network.broadcast('lookup-group', group, timeout, true)
	if not res then
		return
	end
	cache['#'..group] = {
		typ = dnsType,
		ttl = os.clock() + 10,
		res = res,
	}
end

-- lookup parses a label name
local function lookup(label)
	expect(1, label, 'string')
	if peripheral.isPresent(label) then
		return label
	end

	local item = cache[label]
	if (item == nil or item.ttl < os.clock() + 7) and pending[label] == nil then
		pending[label] = co_run(function()
			lookupLabelUpdateCache(label)
			pending[label] = nil
		end)
	end
	if item ~= nil and item.ttl >= os.clock() then
		return item.res
	end
	await(pending[label])
	local item = cache[label]
	if item ~= nil and item.ttl >= os.clock() then
		return item.res
	end
	return nil
end

-- lookupGroup parses a group name to label table
local function lookupGroup(group)
	expect(1, group, 'string')
	checkAndAssertGroup(group)

	local item = cache[group]
	if (item == nil or item.ttl < os.clock() + 7) and pending[group] == nil then
		pending[group] = co_run(function()
			lookupGroupUpdateCache(group)
			pending[group] = nil
		end)
	end
	if item ~= nil and item.ttl >= os.clock() then
		return item.res
	end
	await(pending[group])
	local item = cache[group]
	if item ~= nil and item.ttl >= os.clock() then
		return item.res
	end
	return nil
end

-- bind binds a label to a peripheral name
-- if the label is already exists, the peripheral name will be updated
-- if peripheral name is nil, label will be removed
local function bind(label, name)
	expect(1, label, 'string')
	expect(2, name, 'string', 'nil')
	checkAndAssertLabel(label)

	network.broadcast('bind-label-name', {
		label = label,
		name = name,
	})
end

-- addGroup adds a group tag to the label
local function addGroup(label, group)
	expect(1, label, 'string')
	expect(2, group, 'string')
	checkAndAssertLabel(label)
	checkAndAssertGroup(group)

	network.broadcast('add-label-group', {
		label = label,
		group = name,
	})
end

-- removeGroup removes a group tag from the label
-- if the group is not exists, it will do nothing
local function removeGroup(label, group)
	expect(1, label, 'string')
	expect(2, group, 'string')
	checkAndAssertLabel(label)
	checkAndAssertGroup(group)

	network.broadcast('remove-label-group', {
		label = label,
		group = group,
	})
end

return {
	lookup = lookup,
	lookupGroup = lookupGroup,
	update = update,
	addGroup = addGroup,
	removeGroup = removeGroup,
}
