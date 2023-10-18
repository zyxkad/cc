-- Redstone Interface
-- by zyxkad@gmail.com

if not redstone then
	error('Cannot found redstone API')
end

local redstoneIntegratorId = 'redstoneIntegrator'

local RedstoneInterface = {
	int = nil, -- peripheral
	side = nil, -- string
}

function RedstoneInterface:new(obj, int, side)
	if int ~= redstone then
		if type(int) == 'string' then
			local name = int
			if name:sub(1, 1) == '#' then
				name = redstoneIntegratorId..'_'..name:sub(2)
			end
			int = peripheral.wrap(name)
			if not int then
				error(string.format('Peripheral %s is not found', name))
			end
		end
		if peripheral.getType(int) ~= redstoneIntegratorId then
			error(string.format('Unexpected type %s for %s, expect %s',
				peripheral.getType(int),
				peripheral.getName(int),
				redstoneIntegratorId))
		end
	end
	assert(type(side) == 'string', 'Argument #3(side) must be a string')
	obj = obj or {}
	setmetatable(obj, { __index = self })
	obj.int = int
	obj.side = side
	return obj
end

function RedstoneInterface:createFromStr(obj, data)
	local i = data:find(':')
	local int = i and data:sub(1, i - 1) or redstone
	local side = i and data:sub(i + 1) or data
	return self:new(obj, int, side)
end

function RedstoneInterface:setOutput(value)
	assert(type(value) == 'boolean', 'Argument #1(value) must be a boolean'))
	return self.int.setOutput(self.side, value)
end

function RedstoneInterface:getOutput()
	return self.int.getOutput(self.side)
end

function RedstoneInterface:setAnalogInput(value)
	assert(type(value) == 'number', 'Argument #1(value) must be a number')
	return self.int.setAnalogInput(self.side, value)
end

function RedstoneInterface:getAnalogInput()
	return self.int.getAnalogInput(self.side)
end


function RedstoneInterface:getInput()
	return self.int.getInput(self.side)
end

function RedstoneInterface:getAnalogInput()
	return self.int.getAnalogInput(self.side)
end

return RedstoneInterface
