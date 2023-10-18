-- shulker box pack helper
-- by zyxkad@gmail.com


local triggerSide = 'front'
local triggerOutSide = 'top'
local sampleId = 'minecraft:barrel_0'
local boxSide = 'back'
local hopperId = 'minecraft:chest_6'
local interfaceName = 'ae2:interface'

local function writeEnd(str)
	local w, h = term.getSize()
	local _, y = term.getCursorPos()
	term.setCursorPos(w - #str + 1, y)
	term.write(str)
end

local function exportItemTo(target, item, count)
	local ints = {peripheral.find(interfaceName)}
	local remain = count
	local _, ty = term.getCursorPos()
	writeEnd(string.format(' - %d / %d ', count - remain, count))
	term.setCursorPos(1, ty)
	while remain > 0 do
		for _, int in ipairs(ints) do
			local l = int.list()
			for i = 1, int.size() do
				local it = l[i]
				if it and it.name == item then
					local n = int.pushItems(peripheral.getName(target), i, remain)
					remain = remain - n
					term.clearLine()
					writeEnd(string.format(' - %d / %d ', count - remain, count))
					term.setCursorPos(1, ty)
				end
			end
		end
	end
	term.clearLine()
end

local function pack()
	local sample = peripheral.wrap(sampleId)
	assert(sample, 'Sample inventory not found')
	local target = peripheral.wrap(hopperId)
	assert(target, 'Hopper not found')

	redstone.setOutput(triggerOutSide, true)
	-- wait for box actually placed
	repeat sleep(0.1)
	until peripheral.wrap(boxSide)

	local l = sample.list()
	for i = 1, sample.size() do
		local it = l[i]
		if it then
			print(string.format('-> exporting\n + %s * %d', it.name, it.count))
			exportItemTo(target, it.name, it.count)
		end
	end

	-- wait for the hopper cache cleaned
	repeat sleep(0.1)
	until table.getn(target.list()) == 0
	-- wait for the item cache transfered
	sleep(1)

	redstone.setOutput(triggerOutSide, false)
	-- wait for destroy the box
	repeat sleep(0.1)
	until not peripheral.wrap(boxSide)
	-- wait for box item drop into the collector
	sleep(1)
end

local function main()
	redstone.setOutput(triggerOutSide, false)
	while true do
		if redstone.getInput(triggerSide) then
			print('==> Packing...')
			pack()
			print('==> Done')
		end
		sleep(0.1)
	end
end

main()
