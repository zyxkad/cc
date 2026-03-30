-- Item share
-- by zyxkad@gmail.com

function main(source, target, targetSlot, rate)
	local sourceInv = assert(peripheral.wrap(source))
	local targetInv = assert(peripheral.wrap(target))
	targetSlot = assert(tonumber(targetSlot))
	rate = assert(tonumber(rate))
	print('Source:', source)
	print('Target:', target)
	print('Target Slot:', targetSlot)
	print('Rate:', rate, 'items/min')
	write('Allows: ')
	local _, allowY = term.getCursorPos()
	print('0')
	write('Transfered: ')
	local _, transferedY = term.getCursorPos()
	print('0')

	local allows = 0
	local transfered = 0
	while true do
		sleep(60)
		allows = allows + rate
		term.setCursorPos(1, allowY)
		term.write(string.format('Allows: %.2f', allows))
		if allows >= 1 then
			local tgSlot = targetInv.list()[targetSlot]
			if tgSlot == nil or tgSlot.count < 64 then
				for slot, item in ipairs(sourceInv.list()) do
					local amount = sourceInv.pushItems(target, slot, math.floor(allows), targetSlot)
					allows = allows - amount
					transfered = transfered + amount
					if allows < 1 then
						break
					end
				end
			end
		end
		term.setCursorPos(1, allowY)
		term.write(string.format('Allows: %.2f', allows))
		term.setCursorPos(1, transferedY)
		term.write(string.format('Transfered: %d', transfered))
	end
end

main(...)
