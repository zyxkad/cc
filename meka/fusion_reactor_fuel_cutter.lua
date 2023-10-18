-- Fusion reactor fuel cutter
-- by zyxkad@gmail.com

local cutters = {peripheral.find('redstoneIntegrator')}
if #cutters == 0 then
	error('No redstoneIntegrator was found')
end

local blockReader = peripheral.find('blockReader')
if not blockReader then
	error('No blockReader was found')
end

print('Checking block', blockReader.getBlockName())

while true do
	local data = blockReader.getBlockData()
	local amount = data.GasTanks[0] ~= nil and data.GasTanks[0].stored.amount or 0
	local _, y = term.getCursorPos()
	term.setCursorPos(1, y)
	term.clearLine()
	term.write(string.format('Fuel: %d', amount))
	local enable = amount >= 8000000
	for _, c in ipairs(cutters) do
		c.setOutput('back', not enable)
	end
	sleep(0.5)
end
