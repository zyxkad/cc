-- Automated golden carrot
-- by zyxkad@gmail.com

local modem = peripheral.wrap('bottom')
assert(peripheral.hasType(modem, 'modem'))
local localName = modem.getNameLocal()
local nuggetsInvName = 'minecraft:barrel_13'
local carrotsInvName = 'quark:variant_chest_29'
local outputInvName = 'quark:variant_chest_30'

local nuggetsInv = assert(peripheral.wrap(nuggetsInvName))
local carrotsInv = assert(peripheral.wrap(carrotsInvName))
local outputInv = assert(peripheral.wrap(outputInvName))

function main()
	turtle.select(4)
	while true do
		while turtle.getItemCount(4) > 0 and not outputInv.pullItems(localName, 4) do
			sleep(1)
		end
		while true do
			local missing = false
			parallel.waitForAll(
				function() nuggetsInv.pushItems(localName, 1, 64, 1) end,
				function() nuggetsInv.pushItems(localName, 2, 64, 2) end,
				function() nuggetsInv.pushItems(localName, 3, 64, 3) end,
				function() nuggetsInv.pushItems(localName, 4, 64, 5) end,
				function() nuggetsInv.pushItems(localName, 5, 64, 7) end,
				function() nuggetsInv.pushItems(localName, 6, 64, 9) end,
				function() nuggetsInv.pushItems(localName, 7, 64, 10) end,
				function() nuggetsInv.pushItems(localName, 8, 64, 11) end,
				function()
					local l = carrotsInv.list()
					if l then
						local slot = next(l)
						if slot then
							carrotsInv.pushItems(localName, slot, 64, 6)
						end
					end
				end
			)
			for _, slot in ipairs({1, 2, 3, 5, 6, 7, 9, 10, 11}) do
				if turtle.getItemCount(slot) == 0 then
					missing = true
					if slot ~= 6 then
						nuggetsInv.pushItems(localName, 1, 64, slot)
					end
				end
			end
			if not missing then
				break
			end
			sleep(1)
		end
		turtle.craft()
		sleep(0)
	end
end

main()
