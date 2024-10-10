-- Distributed system cluster without a controller
-- by zyxkad@gmail.com

local expect = require("cc.expect")

local modemHub = nil
local clusterType = ''
local rednetProtocol = 'swarm-cluster-nc'
local jobLimit = 100
local mainAction = nil
local clusterCount = 0
local clusters = {}
local clusterNames = {}

local function printDebug(...)
	local args = table.pack(...)
	table.insert(args, 'DBUG:', 1)
	print(table.unpack(args, 1, args.n))
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
	rednetProtocol = 'swarm-cluster-nc/' .. typ
end

--- setAction register the action for the system
--
-- @tparam function action It will be called with the values of producer queued.
-- @see setLimit
local function setAction(action)
	expect(1, action, 'function')
	mainAction = action
end

--- setLimit set max actions that can be run at same time
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

--- init setup the system with the modem
-- It broadcast itself and query all other clusters
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
		local sender, data = rednet.receive(rednetProtocol, timeout)
		if not sender then
			break
		end
		if data.typ == 'init' then
			if data.deadline > deadline then
				deadline = data.deadline
			end
			addCluster(sender, data.data)
		elseif data.typ == 'inited' then
			addCluster(sender, data.data)
		end
	end
end

--- run starts the cluster
-- it should only be called after init
--
-- @tparam function producer The producer that returns jobs passed to action
local function run(producer)
	local jobs = {}

	local function resumeProducer(thr, ...)
		local ok, res1, res2 = coroutine.resume(thr, ...)
		if not ok then
			error('producer error: ' .. tostring(res1))
		end
		if coroutine.status(thr) == 'dead' then
			local job, remove = res1, res2
			if remove then
				jobs[job] = nil
			else
				jobs[job] = true
			end
			return false
		end
		return true
	end

	local producerThr
	repeat
		producerThr = coroutine.create(producer)
	until resumeProducer(producerThr)

	local function pollProduce()
		while true do
			if not resumeProducer(producerThr, os.pullEvent()) then
				repeat
					producerThr = coroutine.create(producer)
				until resumeProducer(producerThr)
			end
		end
	end

	if #jobs > 0 then
		-- TODO
		table.sort(jobs, function(a, b) return a < b end)
		local jobCount = #jobs
		local perCluster = jobCount / clusterCount
		if perCluster > jobLimit then
			printError(string.format('avg cluster jobs %d is more than job limit %d', perCluster, jobLimit))
			perCluster = jobLimit
		end
		local marked = {}
		local markedJobs = {}
		for _ = 1, perCluster do
			local iter = 0
			while true do
				if iter > 1000 then
					printError('generated over 1000 times')
					iter = 0
					sleep(0)
				end
				local i = math.random(jobCount)
				local job = jobs[i]
				if not marked[job] then
					marked[job] = 1
					markedJobs[#markedJobs + 1] = job
					break
				end
				marked[job] = marked[job] + 1
			end
		end
		printDebug(string.format('allocating %d jobs', #markedJobs))
		rednet.broadcast({
			typ = 'job-alloc-request',
			jobs = markedJobs,
		}, rednetProtocol)

		while true do
			local sender, data = rednet.receive(rednetProtocol, 0.5)
			if data.typ == 'job-alloc-request' then
				local dups = {}
				for _, job in ipairs(data.jobs) do
					if marked[job] ~= nil then
						dups[#dups + 1] = job
						marked[job] = false
					end
				end
				rednet.broadcast({
					typ = 'job-alloc-response',
					to = sender,
					dups = dups,
				}, rednetProtocol)
			elseif data.typ == 'job-alloc-response' then
				for _, job in ipairs(data.dups) do
				end
			end
		end

		local acceptedJobs = {}
		for job, v in pairs(marked) do
			if v then
				acceptedJobs[job] = true
			else

			end
		end
	end

	parallel.waitForAny(pollProduce, function()
		while true do
			local event, p1, p2 = os.pullEvent()
			if event == 'rednet_message' then
				local sender, data = p1, p2
				if data.typ == 'init' then
					addCluster(sender, data.data)
					rednet.broadcast({
						typ = 'inited',
						name = modemHub.getNameLocal(),
						data = getInitData(),
					}, rednetProtocol)
				elseif data.typ == 'job' then
				end
			elseif event == 'peripheral_detach' then
				local name = p1
				local id = clusterNames[name]
				if id then
					removeCluster(id)
				end
			end
		end
	end)
end

return {
	setType = setType,
	setProducer = setProducer,
	setAction = setAction,
	getClusters = getClusters,
	init = init,
	run = run,
}
