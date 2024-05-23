-- Deployer Loot Transfer
-- by zyxkad@gmail.com

local deployerId = 'create:deployer'

local deployers = {}

local function transferItems(deployer, target)
	local targetName = peripheral.getName(target)
	local l = deployer.list()
	local foundSword = false
	for slot, item in pairs(l) do
		if slot <= 2 then
			if not foundSword and item.name:match('^.+_sword$') then
				foundSword = true
			else
				print('pushing', peripheral.getName(deployer), slot, item.name)
				deployer.pushItems(targetName, slot)
			end
		end
	end
end

function main()
	deployers = {peripheral.find(deployerId)}
	local vault = assert(peripheral.find('inventory', function(name) return not peripheral.hasType(name, deployerId) end))

	print(string.format('found %d deployers', #deployers))
	print('Target:', peripheral.getName(vault))
	while true do
		local fns = {}
		for i, dep in ipairs(deployers) do
			fns[i] = function()
				transferItems(dep, vault)
			end
		end
		parallel.waitForAll(sleep, table.unpack(fns))
	end
end

main({...})
