-- Coal Refueler
-- by zyxkad@gmail.com

local function selectItem(item)
	for i = 1, 16 do
		local detial = turtle.getItemDetail(i)
		if (item == nil and detial == nil) or (item ~= nil and detial and detial.name == item) then
			turtle.select(i)
			return true
		end
	end
	return false
end

function main(args)
	local direction = args[1]
	local suck, drop
	if direction == 'top' or direction == 'up' then
		suck, drop = turtle.suckUp, turtle.dropUp
		print('using direction up')
	elseif direction == 'down' or direction == 'bottom' then
		suck, drop = turtle.suckDown, turtle.dropDown
		print('using direction down')
	else
		suck, drop = turtle.suck, turtle.drop
		print('using direction front')
	end
	if turtle.getFuelLevel() == 'unlimited' then
		print('Unlimited fuel')
		return
	end
	local fuelLimit = turtle.getFuelLimit()
	print('Fuel limit:', fuelLimit)
	print('Fuel left:', turtle.getFuelLevel())
	print('Fueling...')
	local ok = true
	if not selectItem(nil) then
		printError('ERR: Cannot found an empty slot')
		return
	end
	while true do
		local need = math.min(math.ceil((fuelLimit - turtle.getFuelLevel()) / 8), 64)
		if need <= 0 then
			break
		end
		if not suck(need) and not suck(need) then
			ok = false
			printError('No coal left in the inventory, require', need)
			break
		end
		turtle.refuel()
		print('fuel level:', turtle.getFuelLevel(), '/', fuelLimit)
	end
	drop()
	print('Fuel end:', turtle.getFuelLevel(), 'out of', fuelLimit)
end

main({...})
