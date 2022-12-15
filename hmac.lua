-- hmac API ?
-- by zyxkad@gmail.com

local crc32 = crc32
if not crc32 then
	crc32 = require('crc32')
	if not crc32 then
		error("crc32 API not found", 3)
	end
end

local aes = aes
if not aes then
	aes = require('aes')
	if not aes then
		error("aes API not found", 3)
	end
end

local DEFAULT_KEY_FILE = 'id.aes'

local function fitTo16x(src)
	local ri = #src % 16
	if ri == 0 then
		return src
	end
	return src..string.rep('\x00', 16 - ri)
end

local function signCrc32(key, head, data)
	assert(type(head) == 'table')
	assert(data)
	local c = aes.Cipher:new(nil, key)
	local d = textutils.serialiseJSON(head)..'.'..textutils.serialiseJSON(data)
	d = fitTo16x(d)
	local s = ''
	for i = 1, #d, 16 do
		s = s..c:encrypt(d:sub(i, i + 15))
	end
	return crc32.sumIEEE(s)
end

return {
	signCrc32 = signCrc32,
}
