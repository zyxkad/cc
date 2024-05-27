-- TFMG Diesel Engine manager
-- by zyxkad@gmail.com

local engineType = 'tfmg:diesel_engine'
local airIntakeType = 'tfmg:air_intake'

local co2Id = 'tfmg:carbon_dioxide'

local dieselTankId = 'fluidTank_24'
local trashTankId = 'fluidTank_26'

local engines = {}
local airTanks = {}

local function update()
	for e, _ in pairs(engines) do
		for at, _ in pairs(airTanks) do
			if peripheral.call(e, 'pullFluid', at) == 0 then
				break
			end
		end
		coroutine.resume(coroutine.create(peripheral.call), e, 'pullFluid', dieselTankId)
		coroutine.resume(coroutine.create(peripheral.call), e, 'pushFluid', trashTankId, nil, co2Id)
	end
end

local function pullEvents()
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			if peripheral.hasType(name, engineType) then
				engines[name] = true
			elseif peripheral.hasType(name, airIntakeType) then
				airTanks[name] = true
			end
		elseif event == 'peripheral_detach' then
			engines[name] = nil
			airTanks[name] = nil
		end
	end
end

function main(args)
	peripheral.find(engineType, function(name)
		engines[name] = true
	end)
	peripheral.find(airIntakeType, function(name)
		airTanks[name] = true
	end)
	parallel.waitForAny(function()
		while true do
			update()
			sleep()
		end
	end, pullEvents)
end

main({...})
