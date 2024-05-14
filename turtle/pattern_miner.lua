-- Pattern Miner
-- by zyxkad@gmail.com

local function joinArr(arr)
	local s = '['
	for i, e in ipairs(arr) do
		if i ~= 1 then
			s = s .. ', '
		end
		s = s .. tostring(e)
	end
	s = s .. ']'
	return s
end

local function linkedTableTo(t, prev)
	setmetatable(t, {
		__index = function(t, k)
			local m = getmetatable(t)
			return m and m.prev and m.prev[k]
		end,
		prev = prev,
	})
	return t
end

local function patternToMap(pattern)
	if type(pattern) == 'string' then
		local lines = {}
		for line in pattern:gmatch('%s*([^\n]*)%s*\n?') do
			if #line > 0 then
				lines[#lines + 1] = line
			end
		end
		pattern = lines
	end
	if type(pattern) ~= 'table' or #pattern == 0 then
		error('Arg #1 (pattern) is not a valid pattern')
	end
	local map = {
		_map = true,
		width = nil,
		height = #pattern,
		startX = nil,
		startY = nil,
		blocks = 0,
	}
	for i, s in ipairs(pattern) do
		local row = {}
		map[i] = row
		for c in s:gmatch("[^%s]") do
			if c == '0' then
				row[#row + 1] = false
			elseif c == '1' then
				row[#row + 1] = true
				map.blocks = map.blocks + 1
			elseif c == 'A' then
				row[#row + 1] = true
				map.startX = #row
				map.startY = i
			else
				error(string.format('Unexpected character %s at line %d, col %d', c, i, #row + 1), 1)
			end
		end
		if map.width == nil then
			map.width = #row
		elseif map.width ~= #row then
			error(string.format('Line width not match, expect %d, got %d', map.width, #row), 1)
		end
	end
	return map
end

local function opposideFace(face)
	if face == 1 then
		return 4
	elseif face == 2 then
		return 3
	elseif face == 3 then
		return 2
	elseif face == 4 then
		return 1
	else
		error('face is out of the range [1,4]')
	end
end

local function moveToFace(x, y, face)
	if face == 1 then
		return x, y - 1
	elseif face == 2 then
		return x - 1, y
	elseif face == 3 then
		return x + 1, y
	elseif face == 4 then
		return x, y + 1
	else
		error('face is out of the range [1,4]')
	end
end

local Node = {
	-- x = number,
	-- y = number,

	-- -- face is a enumerate number:
	-- --   1 means turtle's forward,  or y- direction
	-- --   2 means turtle's left,     or x- direction
	-- --   3 means turtle's right,    or x+ direction
	-- --   4 means turtle's backward, or y+ direction
	-- face = enum(number),

	-- -- oper saves the last operation made this node
	-- -- valid operations are:
	-- --   'dig' dig front
	-- --   'left' turn left
	-- --   'right' turn right
	-- --   'forward' move forward
	-- --   'backward' move backward
	-- oper = enum(string) or nil,

	-- last = Node or nil,
	-- cleaned = number,
}

function Node:getRoot()
	return self.last and self.last:getRoot() or self
end

function Node:toPath()
	local path = self.last and self.last:toPath() or {}
	path[#path + 1] = self.oper
	return path
end

function Node:attemptForward()
	return moveToFace(self.x, self.y, self.face)
end

function Node:attemptBackward()
	return moveToFace(self.x, self.y, opposideFace(self.face))
end

function Node:digged(x, y)
	if self._digMp then
		return self._digMp[x * 0x10000 + y] or false
	end
	if self.x == x and self.y == y then
		return true
	end
	if self.oper == 'dig' then
		local mx, my = self:attemptForward()
		if mx and mx == x and my == y then
			return true
		end
	end
	return (self.last or false) and self.last:digged(x, y)
end

function Node:statusExists(x, y, face, oper, cleaned)
	if self.x == x and self.y == y and self.face == face and self.cleaned == cleaned then
		if (self.oper ~= 'backward') == (oper ~= 'backward') then
			return true
		end
	end
	return (self.last or false) and self.last:statusExists(x, y, face, oper, cleaned)
end

local function newNode(x, y, face, oper, last)
	local node = {
		x = x,
		y = y,
		face = face,
		oper = oper,
		last = last,
		cleaned = last and last.cleaned or 0,
		_stack = (last and last._stack or 0) + 1,
	}
	if last == nil then
		node._digMp = {}
	elseif node._stack > 32 then
		node._stack = 1
		node._digMp = {}
		local l = last
		while not l._digMp do
			if l.oper == 'dig' then
				local mx, my = l:attemptForward()
				node._digMp[mx * 0x10000 + my] = true
			end
			l = l.last
		end
		linkedTableTo(node._digMp, l._digMp)
	end
	if oper == 'dig' then
		node.cleaned = node.cleaned + 1
	end
	setmetatable(node, { __index=Node })
	return node
end

local function newDigNode(last)
	return newNode(last.x, last.y, last.face, 'dig', last)
end

local function newNodeIfNotExists(x, y, face, oper, last)
	if oper == 'right' and last.oper == 'right' then
		return nil
	end
	if last:statusExists(x, y, face, oper, last.cleaned) then
		return nil
	end
	return newNode(x, y, face, oper, last)
end

local function doMap(map)
	if type(map) ~= 'table' or not map._map then
		error('Arg #1 is not a map', 1)
	end
	if map.startX == nil or map.startY == nil then
		error('Start point is not defined', 1)
	end
	local width, height, blocks = map.width, map.height, map.blocks
	if blocks == 0 then
		return {} -- nothing need to clean
	end

	local queue = {newNode(map.startX, map.startY, 1)}
	local qi, qj = 1, 2
	function push(n)
		if n then
			queue[qj] = n
			qj = qj + 1
		end
	end
	local iter, discard = 0, 0
	while qi < qj do
		iter = iter + 1
		if iter % 10000 == 0 then
			print('iter:', iter, 'qj:', qj, 'qj - qi:', qj - qi)
		end
		local n = queue[qi]
		queue[qi] = nil
		qi = qi + 1

		local dx, dy, face = n.x, n.y, n.face

		local qj0 = qj
		-- print('node:', dx, dy, face, joinArr(n:toPath()))

		if face == 1 then
			if dx > 1 then
				if map[dy][dx - 1] then
					push(newNodeIfNotExists(dx, dy, 2, 'left', n))
				end
			end
			if dx < width then
				if map[dy][dx + 1] then
					push(newNodeIfNotExists(dx, dy, 3, 'right', n))
				end
			end
			if dy > 1 then
				dy = dy - 1
			end
		elseif face == 2 then
			if dy > 1 then
				if map[dy - 1][dx] then
					push(newNodeIfNotExists(dx, dy, 1, 'right', n))
				end
			end
			if dy < height then
				if map[dy + 1][dx] then
					push(newNodeIfNotExists(dx, dy, 4, 'left', n))
				end
			end
			if dx > 1 then
				dx = dx - 1
			end
		elseif face == 3 then
			if dy > 1 then
				if map[dy - 1][dx] then
					push(newNodeIfNotExists(dx, dy, 1, 'left', n))
				end
			end
			if dy < height then
				if map[dy + 1][dx] then
					push(newNodeIfNotExists(dx, dy, 4, 'right', n))
				end
			end
			if dx < width then
				dx = dx + 1
			end
		elseif face == 4 then
			if dx > 1 then
				if map[dy][dx - 1] then
					push(newNodeIfNotExists(dx, dy, 2, 'right', n))
				end
			end
			if dx < width then
				if map[dy][dx + 1] then
					push(newNodeIfNotExists(dx, dy, 3, 'left', n))
				end
			end
			if dy < height then
				dy = dy + 1
			end
		else
			error('unreachable: face is not in range [1,4]')
		end
		if (dx ~= n.x or dy ~= n.y) and map[dy][dx] then
			local digged = n:digged(dx, dy)
			if digged then
				push(newNodeIfNotExists(dx, dy, face, 'forward', n))
			else
				-- print('digging:', dx, dy, joinArr(map[dy]), map[dy][dx])
				local m = newDigNode(n)
				if m.cleaned == blocks then
					print('qj:', qj, qj - qi, 'discard:', discard, 'iter:', iter)
					-- while qi < qj do
					-- 	local n = queue[qi]
					-- 	qi = qi + 1
					-- 	print('ex node:', n.x, n.y, n.face, joinArr(n:toPath()))
					-- end
					return m:toPath()
				end
				push(m)
			end
		end
		if qj0 == qj then
			discard = discard + 1
			-- print('  discard')
		end
		-- if qj - qi > 10000 then
		-- 	break
		-- end
	end
	print('qj:', qj, 'iter:', iter)
	return nil
end


local function test()
	local map1 = patternToMap([[
		0 0 1 1 1 0 0
		0 1 1 1 1 1 0
		1 1 1 1 1 1 1
		1 1 1 A 1 1 1
		1 1 1 1 1 1 1
		0 1 1 1 1 1 0
		0 0 1 1 1 0 0
	]])

	local map2 = patternToMap([[
		0 0 0
		1 1 1
		0 1 1
		0 1 1
		0 1 1
		0 1 0
		0 A 0
	]])

	local map = map1

	print('map:', map.width, map.height, map.startX, map.startY)
	for _, l in ipairs(map) do
		local s = ''
		for _, v in ipairs(l) do
			s = s .. (v and '1' or '0')
		end
		print(s)
	end
	print()

	local path = doMap(map)
	if path then
		print('path length =', #path)
		for _, p in ipairs(path) do
			print('-', p)
		end
	else
		print('NO PATH')
	end
end

test()
