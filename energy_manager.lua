
if not redstone then
	error("redstone API not found")
end

function main(args)
	local energyBlockSide = args[1]
	if not energyBlockSide then
		printError('You must give a name for target energy block')
		return
	end
	local energyBlock = peripheral.wrap(energyBlockSide)
	if not energyBlock then
		printError(string.format('Cannot find peripheral %s', energyBlockSide))
		return
	end
	local redstoneOutputSide = args[2]
	if not redstoneOutputSide then
		printError('You must give a side for output redstone signal')
		return
	end
	local energyRequired = tonumber(args[3])
	while true do
		local flag = (energyRequired and energyBlock.getEnergy() >= energyRequired) or energyBlock.getEnergyFilledPercentage() >= 0.99
		redstone.setOutput(redstoneOutputSide, flag)
		sleep(0.1)
	end
end

main({...})
