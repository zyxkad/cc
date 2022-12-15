
band, bor, bxor, bnot =
	bit.band, bit.bor, bit.bxor, bit.bnot

function blshift(v, n)
	return band(bit.blshift(v, n), 0xffffffff)
end

function brshift(v, n)
	if n == 0 then
		return v
	end
	if band(v, 0x80000000) == 0 then
		return bit.brshift(v, n)
	end
	return bxor(bit.brshift(0x7fffffff, n - 1), bit.brshift(bnot(v), n))
end

function uint8(v)
	return band(v, 0xff)
end

function xor_ints(a, b)
	local c = (#b < #a and b) or a
	local r = {}
	for i, _ in ipairs(c) do
		r[i] = bxor(a[i], b[i])
	end
	return r
end

function b2uint32(bts)
	return bor(bts[4], bor(blshift(bts[3], 8), bor(blshift(bts[2], 16), blshift(bts[1], 24))))
end

function uint32ToBts(v)
	return string.char(
		uint8(brshift(v, 24)),
		uint8(brshift(v, 16)),
		uint8(brshift(v, 8)),
		uint8(v))
end

function str2ints(s)
	if #s == 16 then
		return {
			b2uint32({s:byte(1, 4)}),
			b2uint32({s:byte(5, 8)}),
			b2uint32({s:byte(9, 12)}),
			b2uint32({s:byte(13, 16)}),
		}
	end
	assert(#s % 4 == 0)
	local res = {}
	for i = 1, #s / 4 do
		res[i] = b2uint32({s:byte((i - 1) * 4 + 1, i * 4)})
	end
	return res
end

function ints2str(b)
	if #b == 4 then
		return uint32ToBts(b[1])..uint32ToBts(b[2])..uint32ToBts(b[3])..uint32ToBts(b[4])
	end
	local res = ''
	for _, n in ipairs(b) do
		res = res..uint32ToBts(n)
	end
	return res
end
