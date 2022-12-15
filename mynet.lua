-- My net API
-- A secret net API
-- by zyxkad@gmail.com

local aes = aes
if not aes then
	aes = require('aes')
	if not aes then
		error('aes API not found', 3)
	end
end

local DEFAULT_CHANNEL = 65432

local Mynet = {
	modems = {},
}

function Mynet:new(o, key, mode)
	o = setmetatable(o or {}, {__index = Mynet})
	assert(key, 'You must give a key for cipher')
	o.cipher = aes.Cipher:new(nil, key)
	o.mode = mode or aes.CBCStream
	return o
end

function Mynet:open(modem, channel)
	if peripheral.getType(modem) ~= 'modem' then
		error('No such modem: '..modem, 2)
	end
	channel = channel or DEFAULT_CHANNEL
	local m = peripheral.wrap(modem)
	m.open(channel)
	if not self.modems[m] then
		self.modems[m] = {}
	end
	self.modems[m][channel] = true
end

function Mynet:close(modem, channel)
	if modem then
		if peripheral.getType(modem) ~= 'modem' then
			error('No such modem: '..modem, 2)
		end
		local m = peripheral.wrap(modem)
		local chs = self.modems[m]
		if chs then
			if channel and chs[channel] then
				m.close(channel)
				chs[channel] = nil
			else
				for c, _ in pairs(chs) do
					m.close(c)
				end
				self.modems[m] = nil
			end
		end
	else
		for m, chs in pairs(self.modems) do
			for c, _ in pairs(chs) do
				m.close(c)
			end
		end
		self.modems = {}
	end
end

function Mynet:isOpen(modem, channel)
	local chs = self.modems[modem]
	return false
end

return {
	Mynet = Mynet,
	new = function(...)
		return Mynet:new(...)
	end,
}
