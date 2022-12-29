-- Mechanical Crafter System (MCS)
-- by zyxkad@gmail.com

if not redstone then
	error('Need redstone API')
end

if not parallel then
	error('Need parallel API')
end

local crafter_id = 'create:mechanical_crafter'
local rsBridge_id = 'rsBridge'
local blockReader_id = 'blockReader'
local redstoneIntegrator_id = 'redstoneIntegrator'

---BEGIN default configs---
local defConfigPath = 'crafter.cfg'

local cfg = {
	emptyBeforeCraft = true,
	waitUnitlIdle = true,

	rsBridge = rsBridge..'_0',
	redstoneIntegrator = '', -- leave it blank to output redstone signal from the computer
	triggerSide = 'top',
	blockReader = blockReader_id..'_0'
}
-- generate crafter id
--[[
  x  1  2  3  x
  4  5  6  7  8
  9 10 11 12 13
 14 15 16 17 18
  x 19 20 21  x
]]
--[[
	the config will like:
	C1=create:mechanical_crafter_1
	C2=create:mechanical_crafter_2
	...
	C21=create:mechanical_crafter_21
]]
for i = 1, 21 do
	cfg[string.format('C%d', i)] = string.format('%s_%d', crafter_id, i)
end

---END default configs---

local function loadConfig(configPath)
	configPath = configPath or defConfigPath
	local ok, config_loader = pcall(require, 'config')
	if ok then
		if fs.exists(configPath) then
			cfg = config_loader.load(configPath, cfg)
		else
			printError(('Config file not exists, saving default config at "%s"'):format(configPath))
			config_loader.save(configPath, cfg)
		end
	else
		error('module "config.lua" not found')
	end
end

local function empty(crafters, rsBridge)
	for i = 1, 21 do
		local c = crafters[i]
		local d = c.getItemDetail(1)
		if d then
			rsBridge.importItemFromPeripheral({name=d.name}, peripheral.getName(c))
		end
	end
end

local function craft(recipe, crafters, rsBridge, blockReader, options)
	local emptyBeforeCraft = cfg.emptyBeforeCraft
	local waitUnitlIdle = cfg.emptyBeforeCraft
	local rsInt = redstone
	local rsSide = cfg.triggerSide
	if options then
		if options.empty ~= nil then
			emptyBeforeCraft = options.empty
		end
		if options.waitUnitlIdle ~= nil then
			waitUnitlIdle = options.waitUnitlIdle
		end
		rsInt = options.rsInt or rsInt
	end
	if emptyBeforeCraft then
		empty(crafters, rsBridge)
	end
	if checkItemBeforeCraft then
		local ok, err = check(recipe, rsBridge)
		if not ok then
			return ok, err
		end
	end

	for i = 1, 21 do
		local item = recipe[i]
		assert(type(item) == 'string')
		local c = crafters[i]
		local amount = rsBridge.exportItemToPeripheral({name=item}, peripheral.getName(c))
		if amount == 0 then
			return false, string.format('Cannot export item[%s] to crafter [%d]%s', item, i, peripheral.getName(c))
		end
	end

	rsInt.setOutput(rsSide, true)
	sleep(0.05) -- wait one tick
	rsInt.setOutput(rsSide, false)
	if cfg.waitUnitlIdle then
		local d
		repeat
			sleep(0) -- yield
			if blockReader.getBlockName() ~= crafter_id then
				return false, string.format('Target block not a %s', crafter_id)
			end
			d = blockReader.getBlockData()
			if not d then
				return false, 'Cannot read block data'
			end
		until d.Phase:upper() == 'IDLE'
	end
	return true
end

local function main(args)
	loadConfig()

	local rsBridge = peripheral.wrap(cfg.rsBridge)
	if not rsBridge then
		printError(string.format('Cannot find peripheral %s', cfg.rsBridge))
		return
	elseif peripheral.getType(rsBridge) ~= rsBridge_id then
		printError(string.format('%s is not a rsBridge', cfg.rsBridge))
		return
	end
	local crafters = {}
	for i = 1, 21 do
		local Cid = cfg[string.format('C%d', i)]
		local Cp = peripheral.wrap(Cid)
		if not Cp then
			printError(string.format('Cannot find peripheral %s', Cid))
			return
		elseif peripheral.getType(Cp) ~= crafter_id then
			printError(string.format("%s is not a create's mechanical crafter", Cid))
			return
		end
	end
	local rsInt = nil
	if cfg.redstoneIntegrator then
		if not rsInt then
			printError(string.format('Cannot find peripheral %s', cfg.redstoneIntegrator))
			return
		elseif peripheral.getType(rsInt) ~= redstoneIntegrator_id then
			printError(string.format('%s is not a redstoneIntegrator', cfg.redstoneIntegrator))
			return
		end
	end

	-- craft(recipe)
	peripheral.waitForAny(function()
		while true do
			sleep(0.1)
		end
	end)
end

-- main({...})
