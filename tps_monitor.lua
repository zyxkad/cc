-- TPS monitor
-- by zyxkad@gmail.com

function main()
	while true do
		local startT = os.epoch('utc')
		sleep(0) -- sleep a tick
		local endT = os.epoch('utc')
		local td = (endT - startT) / 1000
		print(string.format('TPS=%.2f; td=%.5f', 1 / td, td))
		sleep(1)
	end
end

main()
