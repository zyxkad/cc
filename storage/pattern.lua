-- CC Storage - Recipe Pattern Storage
-- by zyxkad@gmail.com

local recipeDir = '/recipe'
-- structure:
-- recipeDir/
--   minecraft:oak_plank/
--     1.json
--     2.json
--   minecraft:iron_sword/
--     1.json

local network = require('network')

local recipes = {}

local function endswith(s, suffix)
	local _, i = string.find(s, suffix, 1, true)
	return i == #s
end

local function loadRecipes()
	local recipes = {}
	for _, item in ipairs(fs.list(recipeDir)) do
		local ritem = {}
		local dir = fs.combine(recipeDir, item)
		for _, n in ipairs(fs.list(dir)) do
			if endswith(n, '.json') then
				local filename = fs.combine(dir, n)
				local fd, err = fs.open(filename, 'r')
				if fd then
					local recipe = textutils.unserialiseJSON(fd.readAll())
					ritem[#ritem + 1] = recipe
				else
					printError('Err:', err)
				end
			end
		end
		if #ritem > 0 then
			recipes[item] = ritem
		end
	end
	return recipes
end

local function cmdAddRecipe(reply, data)
	local rtype, output = data.type, data.output
	if rtype == 'craft' then
		-- example:
		--  {
		--  	grid = {
		--  		'a  ',
		--  		'a  ',
		--  		'b  ',
		--  	},
		--  	slots = {
		--  		a = {
		--  			name = 'minecraft:diamond'
		--  			nbt = false,
		--  		},
		--  		b = {
		--  			name = 'minecraft:stick'
		--  			nbt = false,
		--  		},
		--  	},
		--  }
		if type(data.inputs) ~= 'table' or type(data.grid) ~= 'table' or type(data.slots) ~= 'table' or
			 type(grid[1]) ~= 'string' then
			reply({
				ok = false,
				err = 'payload.inputs (for craft) does not have correct structure',
			})
		end
	else if rtype == 'process'
		-- example:
		--  {
		--  	{
		--  		name = 'modid:material_1',
		--  		count = 2,
		--  	},
		--  	{
		--  		name = 'modid:material_2',
		--  		nbt = '<nbt md5>',
		--  		count = 128,
		--  	},
		--  }
		if type(data.inputs) ~= 'table' or type(data.inputs[1]) ~= 'table' then
			reply({
				ok = false,
				err = 'payload.inputs (for process) does not have correct structure',
			})
		end
	else
		reply({
			ok = false,
			err = 'unexpected payload.type ' .. tostring(rtype),
		})
		return
	end
	if type(output) ~= 'table' or type(output.name) ~= 'string' or type(output.count) ~= 'number' or output.count <= 0 then
		reply({
			ok = false,
			err = 'payload.output does not have correct structure',
		})
	end

	local outRecipeDir = fs.combine(recipeDir, output)
	if not fs.isDir(outRecipeDir) then
		fs.makeDir(outRecipeDir)
	end
	local outRecipeFile
	local i = 0
	repeat
		i = i + 1
		outRecipeFile = fs.combine(outRecipeDir, string.format('%d.json', i))
	until not fs.exists(outRecipeFile)
	local fd, err = fs.open(outRecipeFile, 'w')
	if not fd then
		reply({
			ok = false,
			err = err,
		})
		return
	end
	fd.write(textutils.serialiseJSON(data))
	fd.close()
	reply({
		ok = true,
	})
end

function main()
	network.setType('pattern-storage')
	peripheral.find('modem', function(modemSide)
		network.open(modemSide)
	end)

	network.registerCommand('add-recipe', function(_, _, payload, reply)
		cmdAddRecipe(reply, payload)
	end)

	network.registerCommand('list-recipes', function(_, _, _, reply)
		reply(recipes)
	end)

	network.registerCommand('get-recipe-chain', function(_, _, payload, reply)
		payload
		reply(recipes)
	end)

	network.run()
end

main()
