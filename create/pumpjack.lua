-- tfmg Crude Oil puller
-- by zyxkad@gmail.com

local towerControllerType = 'tfmg:distillation_tower_controller'
local towerOutputType = 'tfmg:distillation_tower_output'
local pumpJackType = 'tfmg:pumpjack_base'
local dilControllerType = 'tfmg:distillery_controller'
local distilleryType = 'tfmg:distillery'

local heavyOilId = 'tfmg:heavy_oil'
local lubricationOilId = 'tfmg:lubrication_oil'
local dieselId = 'tfmg:diesel'
local keroseneId = 'tfmg:kerosene'
local gasolineId = 'tfmg:gasoline'
local lpgId = 'tfmg:lpg'

local itemOutput = 'minecraft:chest_678'
local trashTank = 'fluidTank_19'
local oilOutputs = {}
oilOutputs[lubricationOilId] = {
	['fluidTank_15'] = true,
}
oilOutputs[dieselId] = {
	['fluidTank_20'] = true,
}
oilOutputs[keroseneId] = {
	['fluidTank_21'] = true,
}
oilOutputs[gasolineId] = {
	['fluidTank_22'] = true,
}
oilOutputs[lpgId] = {
	['fluidTank_23'] = true,
}

local towerControllers = {}
local towerOutputs = {}
local pumpjacks = {}
local dilControllers = {}
local distilleries = {}

local function updateOutputTypes()
	local fns = {sleep}
	for o, t in pairs(towerOutputs) do
		fns[#fns + 1] = function()
			local tanks = peripheral.call(o, 'tanks')
			if tanks and tanks[1] then
				local fluid = tanks[1]
				if fluid.name ~= 'minecraft:empty' then
					towerOutputs[o] = fluid.name
					if not t then
						print(o, 'output', fluid.name)
					end
					if fluid.amount > 7500 then
						pcall(peripheral.call, o, 'pushFluid', trashTank, 500)
					end
				end
			end
		end
	end
	for o, t in pairs(distilleries) do
		if t == false then
			fns[#fns + 1] = function()
				local tanks = peripheral.call(o, 'tanks')
				if tanks and tanks[1] and tanks[1].name ~= 'minecraft:empty' then
					distilleries[o] = tanks[1].name
					print(o, 'output', tanks[1].name)
				end
			end
		end
	end
	parallel.waitForAll(table.unpack(fns))
end

local function update()
	while true do
		for c, _ in pairs(towerControllers) do
			for p, _ in pairs(pumpjacks) do
				coroutine.resume(coroutine.create(peripheral.call), c, 'pullFluid', p)
			end
		end
		updateOutputTypes()
		for o, t in pairs(towerOutputs) do
			if t == heavyOilId then
				for c, _ in pairs(dilControllers) do
					coroutine.resume(coroutine.create(peripheral.call), c, 'pullFluid', o)
				end
			else
				local tanks = oilOutputs[t]
				if tanks then
					for tank, _ in pairs(tanks) do
						coroutine.resume(coroutine.create(peripheral.call), o, 'pushFluid', tank)
					end
				end
			end
		end
		for o, t in pairs(distilleries) do
			local tanks = oilOutputs[t]
			if tanks then
				for tank, _ in pairs(tanks) do
					coroutine.resume(coroutine.create(peripheral.call), o, 'pushFluid', tank)
				end
			end
		end
		for c, _ in pairs(dilControllers) do
			coroutine.resume(coroutine.create(peripheral.call), c, 'pushItems', itemOutput, 1)
			coroutine.resume(coroutine.create(peripheral.call), c, 'pushItems', itemOutput, 2)
		end
		sleep()
	end
end

local function pullEvents()
	while true do
		local event, name = os.pullEvent()
		if event == 'peripheral' then
			if peripheral.hasType(name, towerControllerType) then
				print('new tower', name)
				towerControllers[name] = true
			elseif peripheral.hasType(name, towerOutputType) then
				print('new output', name)
				towerOutputs[name] = false
			elseif peripheral.hasType(name, pumpJackType) then
				print('new pumpjack', name)
				pumpjacks[name] = true
			elseif peripheral.hasType(name, dilControllerType) then
				print('new distillery controller', name)
				dilControllers[name] = true
			elseif peripheral.hasType(name, distilleryType) then
				print('new distillery', name)
				distilleries[name] = false
			end
		elseif event == 'peripheral_detach' then
			towerControllers[name] = nil
			towerOutputs[name] = nil
			pumpjacks[name] = nil
			dilControllers[name] = nil
			distilleries[name] = nil
		end
	end
end

function main()
	peripheral.find(towerControllerType, function(name)
		print('find tower', name)
		towerControllers[name] = true
	end)
	peripheral.find(towerOutputType, function(name)
		print('find output', name)
		towerOutputs[name] = false
	end)
	peripheral.find(pumpJackType, function(name)
		print('find pumpjack', name)
		pumpjacks[name] = true
	end)
	peripheral.find(dilControllerType, function(name)
		print('find distillery controller', name)
		dilControllers[name] = true
	end)
	peripheral.find(distilleryType, function(name)
		print('find distillery', name)
		distilleries[name] = false
	end)
	parallel.waitForAny(pullEvents, update)
end

main({...})
