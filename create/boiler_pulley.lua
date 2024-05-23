-- Create Hose Pulley pipe
-- It pumps pulley to every tanks
-- by zyxkad@gmail.com

local targetTypes = {
	'fluidTank',
	'ad_astra:oxygen_loader',
	'sophisticatedbackpacks:backpack',
}

function main(args)
	local pulleyName = assert(args[1])
	assert(type(pulleyName) == 'string')
	local pulley = assert(peripheral.wrap(pulleyName))
	local tanks = {}
	for _, typ in ipairs(targetTypes) do
		peripheral.find(typ, function(name)
			print('Find', name)
			tanks[name] = true
		end)
	end
	parallel.waitForAny(function()
		while true do
			local event, name = os.pullEvent()
			if event == 'peripheral' then
				for _, typ in ipairs(targetTypes) do
					if peripheral.hasType(name, typ) then
						print('Peripheral', name, 'connected')
						tanks[name] = true
						break
					end
				end
			elseif event == 'peripheral_detach' then
				tanks[name] = nil
			end
		end
	end, function()
		while true do
			local fn = {}
			for t, _ in pairs(tanks) do
				fn[#fn + 1] = function() pcall(pulley.pushFluid, t) end
			end
			parallel.waitForAll(table.unpack(fn))
		end
	end)
end

main({...})
