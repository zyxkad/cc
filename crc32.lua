-- crc32 hash API
-- translate by zyxkad@gmail.com
-- original code is from golang.org standard library "hash/crc32"

if not bit then
	error("bit API not found")
end


local band, bor, bxor, bnot =
	bit.band, bit.bor, bit.bxor, bit.bnot

local function blshift(v, n)
	return band(bit.blshift(v, n), 0xffffffff)
end

local function brshift(v, n)
	if n == 0 then
		return v
	end
	if band(v, 0x80000000) == 0 then
		return bit.brshift(v, n)
	end
	return bxor(bit.brshift(0x7fffffff, n - 1), bit.brshift(bnot(v), n))
end

local function uint8(v)
	return band(v, 0xff)
end

local function simplePopulateTable(poly, t)
	for i = 0, 255 do
		local crc = i
		for j = 0, 7 do
			if crc % 2 == 1 then
				crc = bxor(brshift(crc, 1), poly)
			else
				crc = brshift(crc, 1)
			end
		end
		t[i] = crc
	end
end

local function simpleUpdate(crc, tab, p)
	crc = bnot(crc)
	for _, v in ipairs({p:byte(1, -1)}) do
		crc = bxor(tab[bxor(uint8(crc), v)], brshift(crc, 8))
	end
	return bnot(crc)
end

local Table = {}

local function makeTable(poly)
	local t = {}
	setmetatable(t, {__index = Table})
	simplePopulateTable(poly, t)
	return t
end

local function slicingMakeTable(poly)
	local t = {}
	for i = 1, 7 do t[i] = {} end
	t[0] = makeTable(poly)
	for i = 0, 255 do
		local crc = t[0][i]
		for j = 1, 7 do
			crc = bxor(t[0][uint8(crc)], brshift(crc, 8))
			t[j][i] = crc
		end
	end
	return t
end

local slicing8Cutoff = 16

local function slicingUpdate(crc, tab, p)
	if #p >= slicing8Cutoff then
		crc = bnot(crc)
		while #p > 8 do
			crc = bxor(crc, bor(p:byte(1), bor(blshift(p:byte(2), 8), bor(blshift(p:byte(3), 16), blshift(p:byte(4), 24)))))
			crc = bxor(tab[0][p:byte(8)], bxor(tab[1][p:byte(7)], bxor(tab[2][p:byte(6)], bxor(tab[3][p:byte(5)],
			bxor(tab[4][brshift(crc, 24)], bxor(tab[5][uint8(brshift(crc, 16))],
			bxor(tab[6][uint8(brshift(crc, 8))], bxor(tab[7][uint8(crc)]))))))))
			p = p:sub(9)
		end
		crc = bnot(crc)
	end
	if #p == 0 then
		return crc
	end
	return simpleUpdate(crc, tab[0], p)
end

local IEEE = 0xedb88320
local ieeeTable8 = slicingMakeTable(IEEE)
local IEEETable = ieeeTable8[0]

local Digest = { crc = 0, tab = IEEETable }

function Digest:new(o, tab)
	o = o or {}
	setmetatable(o, {__index = self})
	o.crc = 0
	o.tab = tab or self.tab
	return o
end

function Digest:reset()
	self.crc = 0
end

function Digest:update(data)
	if self.tab == IEEETable then
		self.crc = slicingUpdate(self.crc, ieeeTable8, data)
		return self
	end
	self.crc = simpleUpdate(self.crc, self.tab, data)
	return self
end

function Digest:sum()
	return self.crc
end

local function sumIEEE(data)
	return slicingUpdate(0, ieeeTable8, data)
end

return {
	IEEE = IEEE,
	IEEETable = IEEETable,
	Digest = Digest,
	sumIEEE = sumIEEE,
}
