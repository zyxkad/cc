-- Automate source gem
-- by zyxkad@gmail.com

---- BEGIN CONFIG ----

local chamberType = 'ars_nouveau:imbuement_chamber'
local materials = {
	['minecraft:lapis_lazuli'] = true,
	['minecraft:amethyst_shard'] = true,
	['minecraft:amethyst_block'] = true,
}
local product = 'ars_nouveau:source_gem'
local inputInvName = 'minecraft:barrel_9'
local outputInvName = 'minecraft:barrel_10'

---- END CONFIG ----

local inputInv = assert(peripheral.wrap(inputInvName))
local outputInv = assert(peripheral.wrap(outputInvName))
local chambers = {}

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local thrPool -- = crx.newThreadPool(160)

local function addChamber(chamber)
	local chamberName = peripheral.getName(chamber)
	print('Connected', chamberName)
	local l = chamber.list()
	l = l[1]
	local idle = true
	if l then
		if l.name == product then
			outputInv.pullItems(chamberName, 1)
		else
			idle = false
		end
	end
	chambers[chamberName] = {
		idle = idle,
		p = chamber,
	}
end

local function pollEvents()
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			local chamber = peripheral.wrap(name)
			if peripheral.hasType(chamber, chamberType) then
				thrPool.queue(addChamber, chamber)
			end
		elseif event == 'peripheral_detach' then
			if chambers[name] then
				chambers[name] = nil
			end
		end
	end
end

local function pushMaterial()
	while true do
		for slot, item in pairs(inputInv.list()) do
			if materials[item.name] then
				local remain = item.count
				for chamberName, data in pairs(chambers) do
					if data.idle then
						data.idle = false
						local c = inputInv.pushItems(chamberName, slot, 1)
						remain = remain - c
						if remain <= 0 then
							break
						end
					end
				end
				if remain > 0 then
					-- just jump here because all chambers are working
					break
				end
			end
		end
		sleep(1)
	end
end

local function pollChambers()
	for _, chamber in ipairs({peripheral.find(chamberType)}) do
		thrPool.queue(addChamber, chamber)
	end

	while true do
		local thrs = {}
		for chamberName, data in pairs(chambers) do
			thrs[#thrs + 1] = thrPool.queue(function(chamberName, data)
				if not data.idle then
					local l = data.p.list()[1]
					if l and l.name == product then
						outputInv.pullItems(chamberName, 1)
						data.idle = true
					end
				end
			end, chamberName, data)
		end
		await(table.unpack(thrs))
		sleep(1)
	end
end

function main()
	co_main(function()
		thrPool = crx.newThreadPool(160)
	end, pollEvents, pushMaterial, pollChambers)
end

main()
