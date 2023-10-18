-- Coal Refueler
-- by zyxkad@gmail.com

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
	while turtle.getFuelLevel() < fuelLimit do
		drop()
		if not suck() then
			ok = false
			printError('No coal left in the inventory')
			break
		end
		turtle.refuel()
		print('fuel level:', turtle.getFuelLevel(), '/', fuelLimit)
	end
	if ok then
		-- don't keep the bucket
		drop()
	end
	print('Fuel end:', turtle.getFuelLevel(), 'out of', fuelLimit)
end

main({...})
