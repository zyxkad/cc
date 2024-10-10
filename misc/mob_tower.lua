-- Mob Tower controller
-- by zyxkad@gmail.com

local waterDelay = 1.8
local interval = 5

local integrators = {}

local function stop()
	for _, ri in ipairs(integrators) do
		ri.setOutput('back', false)
	end
end

function main(args)
	integrators = {peripheral.find('redstoneIntegrator')}
	print('Layers:', #integrators)
	if args[1] == 'stop' then
		stop()
		return
	end
	while true do
		if #integrators > 0 then
			local perD = interval / #integrators
			parallel.waitForAll(function()
				for _, ri in ipairs(integrators) do
					ri.setOutput('back', false)
					sleep(perD)
				end
			end, function()
				sleep(waterDelay)
				for _, ri in ipairs(integrators) do
					ri.setOutput('back', true)
					sleep(perD)
				end
			end, function()
				sleep(interval)
			end)
		else
			sleep(interval)
		end
	end
end

main({...})
