-- Botania purifier
-- make living log & stone
-- by zyxkad@gmail.com

local targetBlocks = {
	['botania:livingwood_log'] = true,
	['botania:livingrock'] = true,
}

local function listTurtle()
	local list = {}
	local cb = {}
	for i = 1, 16 do
		cb[i] = function()
			list[i] = turtle.getItemDetail(i, true)
		end
	end
	parallel.waitForAll(table.unpack(cb))
	return list
end

local function selectItem(list, item)
	for slot, detial in pairs(list) do
		if detial.name == item then
			turtle.select(slot)
			return true
		end
	end
	return false
end

local function selectLog(list)
	for slot, detial in pairs(list) do
		if detial.tags['minecraft:logs'] and detial.name ~= 'botania:livingwood_log' then
			turtle.select(slot)
			return true
		end
	end
	return false
end

function main()
	while true do
		local flag = true
		local ok, block = turtle.inspectUp()
		if ok then
			if targetBlocks[block.name] then
				turtle.digUp()
			else
				flag = false
			end
		end
		if flag then
			local list = listTurtle()
			if selectItem(list, 'minecraft:stone') or selectLog(list) then
				turtle.placeUp()
				sleep(30.05)
			else
				sleep(1)
			end
		else
			sleep(1)
		end
	end
end

main()
