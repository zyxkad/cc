-- Furnace Manager
-- by zyxkad@gmail.com

function main(inputName, outputName, fuelName, ...)
	local furnaces = {...}
	print('Input:', inputName)
	local inputInv = assert(peripheral.wrap(inputName))
	print('Output:', outputName)
	local outputInv = assert(peripheral.wrap(outputName))
	print('Fuel:', fuelName)
	local fuelInv = assert(peripheral.wrap(fuelName))
	while true do
		local minFurnaceInd = 0
		for slot, item in pairs(inputInv.list()) do
			if item.count >= 8 then
				for i, furnace in ipairs(furnaces) do
					if i > minFurnaceInd then
						local amount = inputInv.pushItems(furnace, slot, 8, 1)
						item.count = item.count - amount
						if amount < 8 then
							inputInv.pullItems(furnace, 1, amount)
							minFurnaceInd = i
						end
						if item.count < 8 then
							break
						end
					end
				end
			end
		end
		minFurnaceInd = 0
		for slot, item in pairs(fuelInv.list()) do
			for i, furnace in ipairs(furnaces) do
				if i > minFurnaceInd then
					local amount = fuelInv.pushItems(furnace, slot, item.count, 2)
					item.count = item.count - amount
					if item.count <= 0 then
						break
					else
						minFurnaceInd = i
					end
				end
			end
		end
		for _, furnace in ipairs(furnaces) do
			outputInv.pullItems(furnace, 3)
		end
		sleep(0.5)
	end
end

main(...)
