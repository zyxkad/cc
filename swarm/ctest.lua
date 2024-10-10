c=require('cluster')

hub = peripheral.find('peripheral_hub')
print('hub =', peripheral.getName(hub))

repeat sleep(0) until redstone.getInput('front')

c.setAction(function(job)
	print('doing job', job)
	sleep(4)
	print('the job', job, 'is done')
end)
c.init(peripheral.getName(hub))

local i = 0
c.run(function()
	sleep(3)
	i = i + 1
	return 'job_' .. i, false
end)
