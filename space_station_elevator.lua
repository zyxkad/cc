-- Space Station Elevator
-- by zyxkad@gmail.com


function main(args)
	while true do
		local detector = peripheral.find('playerDetector')
		while not detector do
			local _, pid = os.pullEvent('peripheral')
			local p = peripheral.wrap(pid)
			if peripheral.getType(p) == 'playerDetector' then
				detector = p
			end
		end
		detector.getPlayersInRange(2)
		sleep(0.1)
	end
end

main({...})
