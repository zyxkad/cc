-- auto stop ME quantum ring
-- by zyxkad@gmail.com

local singularId = 'ae2:quantum_entangled_singularity'
local cellId = 'ae2:energy_cell'
local range = 200

local function selectItem(item)
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if detial and detial.name == item then
			turtle.select(i)
			return true
		end
	end
	return false
end

function main()
	local detector = assert(peripheral.find('playerDetector'), 'cannot find a player detector')
	while true do
		if detector.isPlayersInRange(range) then
			if selectItem(singularId) then
				turtle.drop()
			end
			if selectItem(cellId) then
				turtle.placeUp()
			end
		else
			repeat until not turtle.detectUp() or turtle.digUp()
			turtle.suck()
		end
		sleep(1)
	end
end

main()
