-- Distributed system cluster
-- by zyxkad@gmail.com

local expect = require('cc.expect')
local crx = require('coroutinex')
local co_main = crx.main
local co_run = crx.run
local yield = crx.yield

local COMPUTER_ID = os.getComputerID()
local modemHub = nil
local clusterType = ''
local rednetProtocol = 'swarm-cluster'
local jobLimit = 100
local clusterAction = nil
local controllerAction = nil
local clusterCount = 0
local clusters = {}
local clusterNames = {}
local controllerId = nil
local clusterJobs = {}

local function printDebug(...)
	local args = table.pack(...)
	table.insert(args, 1, 'DBUG:')
	print(table.unpack(args, 1, args.n + 1))
end

local function binSearch(list, item, less, starts, ends)
	expect(1, list, 'table')
	expect(3, less, 'function', 'nil')
	expect(4, starts, 'number', 'nil')
	expect(5, ends, 'number', 'nil')
	less = less or function(a, b)
		return a < b
	end
	if #list <= 1 then
		return 1
	end
	local l, r = starts or 1, ends or #list
	if l < 1 then
		l = 1
	elseif l > #list then
		l = #list
	end
	if r < 1 then
		r = 1
	elseif r > #list then
		r = #list
	end
	while l < r do
		local i = math.floor((l + r) / 2)
		local m = list[i]
		if less(m, item) then
			l = i + 1
		elseif less(item, m) then
			r = i - 1
		else
			return i
		end
	end
	return math.floor((l + r) / 2)
end

--- setType returns the system's type/protocol
--
-- @treturn string the cluster's type
local function getType()
	return clusterType
end

--- setType register the system's type/protocol
--
-- @tparam string typ the cluster's type
local function setType(typ)
	expect(1, typ, 'string')
	clusterType = typ
	rednetProtocol = 'swarm-cluster/' .. typ
end

--- setAction register the action for clusters
-- This action will not be executed on controller
--
-- @tparam function action
-- @see setController
-- @see setLimit
local function setAction(action)
	expect(1, action, 'function')
	clusterAction = action
end

--- setController register the action for controller
-- This action will not be executed on cluster
--
-- @tparam function action
-- @see setAction
local function setController(action)
	expect(1, action, 'function')
	controllerAction = action
end

--- setLimit set maximum actions that can be run at same time
--
-- @tparam number action The limit of actions
-- @see setAction
local function setLimit(limit)
	expect(1, limit, 'number')
	jobLimit = limit
end

--- addCluster will be called when another cluster is found
-- 
-- @tparam number id The cluster id
-- @tparam table data The cluster init data
local function addCluster(id, data)
	clusterCount = clusterCount + 1
	clusters[id] = data
	clusterNames[data.name] = id
end

--- removeCluster will be called when a cluster is left the network
--
-- @tparam number id The cluster id
local function removeCluster(id)
	local data = clusters[id]
	if data then
		printDebug('removing cluster', id)
		clusterCount = clusterCount - 1
		clusters[id] = nil
		clusterNames[data.name] = nil
	end
end

--- getClusters returns all active clusters
--
-- @treturn { [id] = data } The cluster map, should not be modified
local function getClusters()
	return clusters
end

local function getInitData()
	return {
		name = modemHub.getNameLocal(),
	}
end

local function selectControllerIdOrder()
	local smallest = COMPUTER_ID
	for id, _ in pairs(clusters) do
		if id < smallest then
			smallest = id
		end
	end
	controllerId = smallest
end

local function selectControllerRandom()
	local selecting = {}
	selecting[COMPUTER_ID] = true
	local selectingCount = 1
	for id, _ in pairs(clusters) do
		selecting[id] = true
		selectingCount = selectingCount + 1
	end
	repeat
		local weights = {}
		local weightCount = 0
		local localWeight = nil
		local sendTimer = nil
		if selecting[COMPUTER_ID] then
			localWeight = math.random(0, 0x7fffffff)
			printDebug('local weight =', localWeight)
			sendTimer = os.startTimer(0.2)
		end
		local timeoutTimer = os.startTimer(0.5)
		while true do
			local event, p1, p2, p3 = os.pullEvent()
			if event == 'rednet_message' then
				if p3 == rednetProtocol then
					local sender, data = p1, p2
					if data.typ == 'controller-select' then
						os.cancelTimer(timeoutTimer)
						timeoutTimer = os.startTimer(0.5)
						printDebug('recv weight from', sender, selecting[sender], data.w)
						if selecting[sender] then
							local oldValue = weights[sender]
							weights[sender] = data.w
							if not oldValue then
								weightCount = weightCount + 1
								if weightCount >= selectingCount then
									break
								end
							end
						end
					end
				end
			elseif event == 'timer' then
				if p1 == sendTimer then
					sendTimer = nil
					rednet.broadcast({
						typ = 'controller-select',
						w = localWeight,
					}, rednetProtocol)
				elseif p1 == timeoutTimer then
					break
				end
			end
		end
		local smallestW = nil
		local smallests = nil
		if localWeight then
			smallestW = localWeight
			smallests = {COMPUTER_ID}
		end
		for id, w in pairs(weights) do
			if smallestW == nil or w < smallestW then
				smallestW = w
				smallests = {id}
			elseif w == smallestW then
				smallests[#smallests + 1] = id
			end
		end
		assert(smallests)
		printDebug('smallests:', table.unpack(smallests), 'with weight', smallestW)
		if #smallests == 1 then
			controllerId = smallests[1]
			return
		else
			selecting = {}
			selectingCount = 0
			for _, id in ipairs(smallests) do
				selecting[id] = true
				selectingCount = selectingCount + 1
			end
		end
	until false
end

local function selectController()
	print('Selecting controller ...')
	controllerId = nil
	-- return selectControllerIdOrder()
	selectControllerRandom()
end

local function selectControllerAndRunController()
	if controllerId == COMPUTER_ID then
		co_run(pollProducer)
		co_run(distributeNewJobs)
		co_run(function()
			yield() -- ensure producer has been executed
			assignJobs()
		end)
	end
end

--- init setup the system with the modem
-- It broadcast itself and query all other clusters
-- It will return when the controller is selected
--
-- @tparam string modem The wired modem's name
local function init(modem)
	expect(1, modem, 'string')
	assert(peripheral.hasType(modem, 'peripheral_hub'), 'modem must be a peripheral_hub')

	modemHub = assert(peripheral.wrap(modem))
	rednet.open(modem)

	local now = os.clock()
	local deadline = os.epoch('utc') + 1000

	rednet.broadcast({
		typ = 'init',
		deadline = deadline,
		data = getInitData(),
	}, rednetProtocol)

	while true do
		local timeout = (deadline - os.epoch('utc')) / 1000
		printDebug('next timeout:', timeout)
		local sender, data = rednet.receive(rednetProtocol, timeout)
		if not sender then
			break
		end
		if data.typ == 'init' then
			if data.deadline > deadline then
				deadline = data.deadline
			end
			printDebug('new cluster', sender)
			addCluster(sender, data.data)
		elseif data.typ == 'inited' then
			if data.isctrl then
				controllerId = sender
			end
			printDebug('found inited cluster', sender, data.isctrl and 'and is the controller' or nil)
			addCluster(sender, data.data)
		end
	end
	if not controllerId then
		selectController()
	end
	printDebug('controller:', controllerId)
end



--- run starts the cluster
-- it should only be called after init
--
-- @tparam function producer The producer that returns jobs passed to action
local function run(producer)
	local function controlling()
		return controllerId == COMPUTER_ID
	end

	local jobMap = {}
	local addingJobs = {}
	local removingJobs = {}
	local function resumeProducer(thr, ...)
		local res = table.pack(coroutine.resume(thr, ...))
		if not res[1] then
			error('producer error: ' .. tostring(res[2]))
		end
		if coroutine.status(thr) == 'dead' then
			local job, remove = res[2], res[3]
			if remove then
				if jobMap[job] ~= nil then
					printDebug('removing job', job)
					jobMap[job] = nil
					if addingJobs[job] then
						addingJobs[job] = nil
					else
						removingJobs[job] = true
					end
				end
			elseif jobMap[job] == nil then
				printDebug('new job', job)
				jobMap[job] = false
				if removingJobs[job] then
					removingJobs[job] = nil
				else
					addingJobs[job] = true
				end
			end
			return false
		end
		return res
	end

	local function pollProducer()
		local producerThr
		local producerRes = nil
		local firstProduce = true
		while controlling() do
			while not producerRes do
				producerThr = coroutine.create(producer)
				producerRes = resumeProducer(producerThr, firstProduce)
				firstProduce = false
			end
			producerRes = resumeProducer(producerThr, coroutine.yield(table.unpack(producerRes, 2, producerRes.n)))
		end
	end

	local function assignJobs()
		local jobList = {}
		for job, _ in pairs(jobMap) do
			jobList[#jobList + 1] = job
		end
		local perCluster = math.ceil(#jobList / clusterCount)
		if perCluster > jobLimit then
			printError(string.format('avg cluster jobs %d is more than job limit %d', perCluster, jobLimit))
			perCluster = jobLimit
		end
		clusterJobs = {}
		local i = 1
		for cluster, _ in pairs(clusters) do
			local l = {}
			for _ = 1, perCluster do
				if i > #jobList then
					break
				end
				local job = jobList[i]
				jobMap[job] = cluster
				l[#l + 1] = job
			end
			clusterJobs[cluster] = l
		end
		rednet.broadcast({
			typ = 'jobs-assign',
			jobs = clusterJobs,
		}, rednetProtocol)
	end

	local function distributeNewJobs()
		while controlling() do
			repeat
				crx.nextTick()
			until next(addingJobs) or next(removingJobs)
			local changes = {}
			for job, _ in pairs(removingJobs) do
				local cluster = jobMap[job]
				if cluster then
					jobMap[job] = nil
					local d = changes[cluster]
					if not d then
						d = {}
						changes[cluster] = d
					end
					local dr = d.removing
					if not dr then
						dr = {}
						d.removing = dr
					end
					local l = clusterJobs[cluster]
					for i, j in ipairs(l) do
						if j == job then
							l[i] = l[#l]
							l[#l] = nil
							break
						end
					end
					dr[#dr + 1] = job
				elseif cluster == false then
					jobMap[job] = nil
				end
				removingJobs[job] = nil
			end
			local clusterJobCounts = {}
			for cluster, _ in pairs(clusters) do
				printDebug('checking cluster', cluster)
				local jobs = clusterJobs[cluster]
				if not jobs then
					clusterJobCounts[#clusterJobCounts + 1] = {
						id = cluster,
						count = 0,
					}
				elseif #jobs < jobLimit then
					local item = {
						id = cluster,
						count = #jobs,
					}
					local i = binSearch(clusterJobCounts, item, function(a, b) return a.count > b.count end)
					printDebug('inserting', i, item.count)
					table.insert(clusterJobCounts, i, item)
				end
			end
			printDebug('clusterJobCounts:', textutils.serialize(clusterJobCounts))
			for job, _ in pairs(addingJobs) do
				if #clusterJobCounts == 0 then
					printError('Cannot distribute ' .. job .. ': all clusters are full')
					break
				end
				addingJobs[job] = nil

				local item = clusterJobCounts[#clusterJobCounts]
				item.count = item.count + 1
				local i = binSearch(clusterJobCounts, item, function(a, b) return a.count > b.count end, 1, #clusterJobCounts - 1)
				clusterJobCounts[#clusterJobCounts], clusterJobCounts[i] = clusterJobCounts[i], item

				local cluster = item.id
				jobMap[job] = cluster
				local d = changes[cluster]
				if not d then
					d = {}
					changes[cluster] = d
				end
				local da = d.adding
				if not da then
					da = {}
					d.adding = da
				end
				local l = clusterJobs[cluster]
				if l then
					l[#l + 1] = job
				else
					clusterJobs[cluster] = {job}
				end
				da[#da + 1] = job
			end
			for cluster, d in pairs(changes) do
				if d.removing or d.adding then
					rednet.send(cluster, {
						typ = 'job-change',
						removing = d.removing,
						adding = d.adding,
					}, rednetProtocol)
				end
			end
		end
	end

	local actions = {}
	local function startJob(job)
		local thr = coroutine.create(clusterAction)
		actions[job] = thr
		co_run(function()
			local eventData = {job}
			while true do
				local res = table.pack(coroutine.resume(thr, table.unpack(eventData, 1, eventData.n)))
				if not res[1] then
					printError('Job', job, 'error:', res[2])
					break
				elseif coroutine.status(thr) == 'dead' then
					printDebug('Job', job, 'done')
					rednet.send(controllerId, {
						typ = 'job-done',
						job = job,
					}, rednetProtocol)
					break
				end
				eventData = table.pack(coroutine.yield(table.unpack(res, 2, res.n)))
			end
			actions[job] = nil
		end)
	end

	local function onJobListAssign(newJobs)
		if not newJobs or #newJobs == 0 then
			for job, thr in pairs(actions) do
				coroutine.resume(thr, 'terminate')
				actions[job] = nil
				newJobMap[job] = nil
			end
			return
		end
		local newJobMap = {}
		for _, job in ipairs(newJobs) do
			newJobMap[job] = true
		end
		for job, thr in pairs(actions) do
			if not newJobMap[job] then
				coroutine.resume(thr, 'terminate')
				actions[job] = nil
				newJobMap[job] = nil
			end
		end
		for job, _ in pairs(newJobMap) do
			startJob(job)
		end
	end

	local function doRednetMessage(sender, data)
		local typ = data.typ
		if typ == 'init' then
			addCluster(sender, data.data)
			rednet.send(sender, {
				typ = 'inited',
				name = modemHub.getNameLocal(),
				isctrl = controlling(),
				data = getInitData(),
			}, rednetProtocol)
		elseif typ == 'disconnect' then
			removeCluster(sender)
			if sender == controllerId then
				co_run(selectControllerAndRunController)
			end
		elseif controlling() then
			if typ == 'job-done' then
				local job = data.job
				jobMap[job] = nil
				local l = clusterJobs[sender]
				for i, j in ipairs(l) do
					if j == job then
						l[i] = l[#l]
						l[#l] = nil
						break
					end
				end
			else
				printError('Unexpected message', typ)
			end
		elseif typ == 'jobs-assign' then
			if sender ~= controllerId then
				printError('Cluster', sender, 'tring to act like controller', controllerId)
				return
			end
			onJobListAssign(data.jobs[COMPUTER_ID])
		elseif typ == 'job-change' then
			if sender ~= controllerId then
				printError('Cluster', sender, 'tring to act like controller', controllerId)
				return
			end
			print('job event:', textutils.serialize(data))
			if data.removing then
				for _, job in ipairs(data.removing) do
					local thr = actions[job]
					if thr then
						coroutine.resume(thr, 'terminate')
						actions[job] = nil
					end
				end
			end
			if data.adding then
				for _, job in ipairs(data.adding) do
					startJob(job)
				end
			end
		else
			printError('Unexpected message', data.typ)
		end
	end

	local ok, err = pcall(co_main, function()
		if controlling() then
			co_run(pollProducer)
			co_run(distributeNewJobs)
			co_run(function()
				yield() -- ensure producer has been executed
				assignJobs()
			end)
		end
		while true do
			local event, p1, p2 = os.pullEvent()
			if event == 'rednet_message' then
				doRednetMessage(p1, p2)
			elseif event == 'peripheral_detach' then
				local name = p1
				local id = clusterNames[name]
				if id then
					removeCluster(id)
					if id == controllerId then
						co_run(selectControllerAndRunController)
					end
				end
			end
		end
	end, function()
		while true do
			local _, r, ok, err = os.pullEvent('#crx_thr_done')
			if not ok then
				printError(tostring(r.native) .. ': ' .. tostring(err))
			end
		end
	end)
	rednet.broadcast({
		typ = 'disconnect',
	}, rednetProtocol)
	if not ok then
		error(err)
	end
end

return {
	getType = getType,
	setType = setType,
	setAction = setAction,
	getClusters = getClusters,
	init = init,
	run = run,
}
