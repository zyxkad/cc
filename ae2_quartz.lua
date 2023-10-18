-- AE2 certus quartz generator
-- by zyxkad@gmail.com

local quartz_cluster_id = 'ae2:quartz_cluster'
local quartz_charged_cluster_id = 'ae2:charged_certus_quartz_crystal'
local quartz_block_id = 'ae2:quartz_block'
local quartz_budding_block_ids = {
	'ae2:flawed_budding_quartz',
	'ae2:chipped_budding_quartz',
	'ae2:damaged_budding_quartz',
}

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


local function bud()
	while true do
		if not redstone.getInput('back') then
			local ok, data = turtle.inspect()
			if ok then
				if data.name == quartz_cluster_id then
					turtle.dig()
				end
			end
		end
		sleep(0)
	end
end

local function base()
	while true do
		local ok, data = turtle.inspectDown()
		if ok then
			if data.name == quartz_block_id then
				print('digging quartz block')
				sleep(0) -- yield for the turtle who are mining bud
				turtle.digDown()
				selectItem(quartz_block_id)
				turtle.drop()
				while not selectItem(quartz_charged_cluster_id) do
					print('waiting charged cluster')
					turtle.suckUp()
				end
				turtle.drop()
				print('placing new budding block')
				while not turtle.detectDown() do
					for _, id in ipairs(quartz_budding_block_ids) do
						if selectItem(id) and turtle.placeDown() then
							break
						end
					end
				end
				print('done')
			end
		else
			for _, id in ipairs(quartz_budding_block_ids) do
				if selectItem(id) and turtle.placeDown() then
					print('placed new budding block')
					break
				end
			end
		end
		sleep(0)
	end
end

function main(args)
	local subcmd = args[1]
	if subcmd == 'bud' then
		bud()
	elseif subcmd == 'base' then
		base()
	end
	printError('Unknown subcommand ' .. subcmd)
end

main({...})
