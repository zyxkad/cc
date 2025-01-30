-- Create Big Cannon Refiller
-- by zyxkad@gmail.com

local cannonEndLock = peripheral.wrap('Create_SequencedGearshift_0')
local cannonEndPistonGearshift = peripheral.wrap('redstone_relay_10')
local cannonLoadPiston = peripheral.wrap('Create_SequencedGearshift_5')
local powderHandLoadPiston = peripheral.wrap('Create_SequencedGearshift_4')
local powderHandPiston = peripheral.wrap('Create_SequencedGearshift_6')
local shellHandInv = peripheral.wrap('create:deployer_0')
local shellHand = peripheral.wrap('Create_SequencedGearshift_1')
local shellLoadPiston = peripheral.wrap('Create_SequencedGearshift_2')

local itemStorage = peripheral.wrap('ae2:cable_bus_1')
local fluidStorage = peripheral.wrap('ae2:cable_bus_2')
local powderInterface = peripheral.wrap('ae2:interface_1')

local fluidShellPeripheralName = 'createbigcannons:fluid_shell_0'

local powderId = 'createbigcannons:powder_charge'
local fluidShellId = 'createbigcannons:fluid_shell'
local shellInfos = {
	['solid'] = {
		name = 'createbigcannons:solid_shot',
	},
	['ap_shot'] = {
		name = 'createbigcannons:ap_shot',
	},
	['he'] = {
		name = 'createbigcannons:he_shell',
	},
	['ap'] = {
		name = 'createbigcannons:ap_shell',
	},
	['shrapnel'] = {
		name = 'createbigcannons:shrapnel_shell',
	},
	['smoke'] = {
		name = 'createbigcannons:smoke_shell',
	},
	['dm'] = {
		name = 'createbigcannons:drop_mortar_shell',
	},
	['lava'] = {
		name = fluidShellId,
		fluid = 'minecraft:lava',
	},
	['water'] = {
		name = fluidShellId,
		fluid = 'minecraft:water',
	},
}

local fuzeInfos = {
	['impact'] = {
		name = 'createbigcannons:impact_fuze',
	},
	['timed'] = {
		name = 'createbigcannons:timed_fuze',
	},
	['proximity'] = {
		name = 'createbigcannons:proximity_fuze',
	},
	['delayed_impact'] = {
		name = 'createbigcannons:delayed_impact_fuze',
	},
}

local function waitSequenceDone(controller)
	repeat
		sleep(0.1)
	until not controller.isRunning()
end

local function extractItemTo(info, target, needs, targetSlot)
	while needs > 0 do
		for slot, item in pairs(itemStorage.list() or {}) do
			if item.name == info.name then
				local amount = itemStorage.pushItems(target, slot, needs, targetSlot)
				if amount ~= nil then
					needs = needs - amount
					if needs <= 0 then
						break
					end
				end
			end
		end
	end
end

local function extractFluidTo(fluid, target, needs)
	print('exporting', fluid, needs)
	while needs > 0 do
		local amount = fluidStorage.pushFluid(target, needs, fluid)
		if amount ~= nil then
			needs = needs - amount
		end
	end
end

-- Open the cannon end
local function openCannonEnd()
	cannonEndPistonGearshift.setOutput('bottom', true)
	cannonEndLock.rotate(180, -1)
	waitSequenceDone(cannonEndLock)
	cannonEndPistonGearshift.setOutput('bottom', false)
	sleep(0.5)
end

-- Close the cannon end
local function closeCannonEnd()
	cannonEndPistonGearshift.setOutput('bottom', true)
	sleep(0.7)
	cannonEndLock.rotate(180, 1)
	waitSequenceDone(cannonEndLock)
end

--- Place powder in the powder cache
local function placePowder(num)
	powderHandLoadPiston.move(1, 1)
	waitSequenceDone(powderHandLoadPiston)

	powderHandPiston.move(num - 1, -1)
	waitSequenceDone(powderHandPiston)

	extractItemTo({
		name = powderId
	}, peripheral.getName(powderInterface), num)

	local function getPowderCount()
		local count = 0
		local ok, list
		repeat ok, list = pcall(powderInterface.list) until ok and list
		for slot, item in pairs(list) do
			if item.name == powderId then
				count = count + item.count
			end
		end
		return count
	end

	local function waitPowderConsumed(targetCount)
		repeat
			sleep(0.05)
		until getPowderCount() < targetCount
	end

	waitPowderConsumed(num)
	for i = num - 1, 1, -1 do
		powderHandPiston.move(1, 1)
		waitSequenceDone(powderHandPiston)
		waitPowderConsumed(i)
	end

	powderHandLoadPiston.move(1, -1)
	waitSequenceDone(powderHandLoadPiston)
end

--- Prepare shell in the shell cache
local function prepareShell(shellType, fuzeType)
	local function rotateUntilConsumed()
		while true do
			shellHand.rotate(180)
			waitSequenceDone(shellHand)
			local list = shellHandInv.list()
			if list and list[1] == nil then
				break
			end
		end
	end

	local shellInfo = assert(shellInfos[shellType], 'shell ' .. shellType .. ' not found')
	extractItemTo(shellInfo, peripheral.getName(shellHandInv), 1)
	rotateUntilConsumed()

	if shellInfo.name == fluidShellId then
		extractFluidTo(shellInfo.fluid, fluidShellPeripheralName, 2000)
	end

	if fuzeType ~= nil and fuzeInfos[fuzeType] ~= nil then
		extractItemTo(fuzeInfos[fuzeType], peripheral.getName(shellHandInv), 1)
		rotateUntilConsumed()
	end
end

--- Push prepared shell into powder cache
local function loadShell()
	shellLoadPiston.move(1, 1)
	waitSequenceDone(shellLoadPiston)
	shellLoadPiston.move(1, -1)
	waitSequenceDone(shellLoadPiston)
end

--- Prepare powder, shell, and load into cannon
local function loadCannonWithShell(shellType, fuzeType)
	parallel.waitForAll(function()
		placePowder(5)
	end, function()
		prepareShell(shellType, fuzeType)
		parallel.waitForAll(loadShell, openCannonEnd)
	end)
	cannonLoadPiston.move(11, -1)
	waitSequenceDone(cannonLoadPiston)
	cannonLoadPiston.move(11, 1)
	sleep(0.5)
	closeCannonEnd()
	waitSequenceDone(cannonLoadPiston)
end

function main(command, shellType)
	if command == 'auto' then
		shellType = shellType or 'he'
		while true do
			os.pullEvent('redstone')
			while redstone.getInput('top') do
				loadCannonWithShell(shellType, 'proximity')
				redstone.setOutput('right', true)
				sleep(0.5)
				redstone.setOutput('right', false)
			end
		end
	elseif command == 'fix' then
		cannonLoadPiston.move(11, 1)
		waitSequenceDone(cannonLoadPiston)
		openCannonEnd()
		closeCannonEnd()
	else
		shellType = command or 'he'
		while true do
			os.pullEvent('redstone')
			if redstone.getInput('top') then
				loadCannonWithShell(shellType, 'proximity')
				sleep(3)
			end
		end
	end
end

main(...)
