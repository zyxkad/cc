-- Sorter
-- by zyxkad@gmail.com

local function parseSlots(str)
	local slots = {}
	if str == '' or str == '*' then
		return true
	end
	for s in str:gmatch('([^,]+)') do
		local l, r = s:match('^(%d+)~(%d+)$')
		if l then
			l, r = tonumber(l), tonumber(r)
			if not l or not r then
				return nil
			end
			for n = l, r do
				slots[#slots + 1] = n
			end
		else
			local n = tonumber(s)
			if n == nil then
				return nil
			end
			slots[#slots + 1] = n
		end
	end
	return slots
end

function main(sourceInvName, backupOutputInvName, ...)
	local sourceInv = assert(peripheral.wrap(sourceInvName))
	assert(backupOutputInvName)
	local targetsStr = {...}
	local targets = {}
	for i, target in ipairs(targetsStr) do
		local item, inv, slots = target:match('^([^;]+);([^;]+);([^;]+)$')
		if not item then
			printError(string.format('format of #%d is not correct', i))
			return
		end
		slots = parseSlots(slots)
		if not slots then
			printError(string.format('slots format of #%d is not correct', i))
		end
		local map = targets[item]
		if not map then
			map = {}
			targets[item] = map
		end
		map[inv] = slots
		print(item, '->', inv)
	end

	while true do
		local list = sourceInv.list()
		for slot, item in pairs(list) do
			local tgs = targets[item.name]
			if tgs and item.count > 1 then
				print('Trying', '#' .. slot, item.name)
				item.count = item.count - 1
				for inv, slots in pairs(tgs) do
					if slots == true then
						local amount = sourceInv.pushItems(inv, slot, item.count)
						item.count = item.count - amount
					else
						for _, toSlot in ipairs(slots) do
							local amount = sourceInv.pushItems(inv, slot, item.count, toSlot)
							item.count = item.count - amount
							if item.count <= 0 then
								break
							end
						end
					end
					if item.count <= 0 then
						break
					end
				end
			end
		end
		sleep(1)
	end
end

main(...)
