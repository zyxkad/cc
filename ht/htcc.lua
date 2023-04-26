-- Hyper Text for ComputerCraft
-- by zyxkad@gmail.com

local expect = require("cc.expect")

local exports = {}

local function parseColor(c)
	if c == nil then
		return nil
	end
	if type(c) == 'number' then
		return c
	end
	if #c == 0 then
		error("Color must be a hex character or a color's name", 1)
	end
	if #c == 1 then
		return 2 ^ tonumber(c, 16)
	end
	local n = colors[c] or colorus[c]
	if type(n) ~= 'number' then
		error(string.format("'%s' is not a color's name", c), 2)
	end
	return n
end

local strToBool = {
	['true'] = true,
	t = true,
	yes = true,
	y = true,
	ok = true,
}


local function isinstance(ins, ...)
	expect(1, ins, 'table', 'nil')
	local classes = {...}
	if #classes == 0 then
		return false
	end
	while ins do
		local mt = getmetatable(ins)
		if not mt then
			break
		end
		for _, cls in ipairs(classes) do
			if mt == cls then
				return true
			end
		end
		ins = mt
	end
	return false
end

local Event = {
	-- name = string,
	cancelable = false,
	canceled = false,
	-- value = table,
}

function Event:new(obj, value)
	expect(1, obj, 'table', 'nil')
	expect(2, value, 'table', 'nil')
	obj = obj or {}
	setmetatable(obj, { __index = function(obj, key)
		local v = self[key]
		if v ~= nil then
			return v
		end
		return obj.value[key]
	end, __metatable = self })
	obj.value = value or {}
	return obj
end

function Event:cancel()
	if self.cancelable then
		self.canceled = true
	end
end

local OnloadEvent = {
	name = 'load',
	-- elem = RootTag,
}
setmetatable(OnloadEvent, { __index = Event, __metatable = Event })
exports.OnloadEvent = OnloadEvent

function OnloadEvent:new(obj, elem)
	expect(1, obj, 'table', 'nil')
	expect(2, elem, 'table')
	obj = Event.new(self, obj, { elem = elem })
	return obj
end

local ClickEvent = {
	name = 'click',
	cancelable = true,
	-- x = integer,
	-- y = integer,
}
setmetatable(ClickEvent, { __index = Event, __metatable = Event })
exports.ClickEvent = ClickEvent

function ClickEvent:new(obj, x, y)
	expect(1, obj, 'table', 'nil')
	expect(2, x, 'number')
	expect(3, y, 'number')
	obj = Event.new(self, obj, { x = x, y = y })
	return obj
end


local ScriptSet = {
	main = nil, -- the main script
	-- map = table, -- the script map, include the main script
}

function ScriptSet:new(obj)
	obj = obj or {}
	setmetatable(obj, { __index = self, __metatable = self })
	obj.map = {}
	return obj
end

function ScriptSet:add(name)
	local s = self.map[name]
	if not s then
		s = require(name)
		self.map[name] = s
	end
	return s
end

function ScriptSet:addMain(name)
	local s = self:add(name)
	if self.main ~= nil then
		error('Main script already exists')
	end
	self.main = name
	return s
end

function ScriptSet:has(name)
	return self.map[name] ~= nil
end

function ScriptSet:get(name)
	return self.map[name]
end

function ScriptSet:symbol(symbol, typ)
	local i = symbol:find('%.')
	if not i then
		error('Must give a package name with a dot')
	end
	local pkt
	if i == 1 then
		pkt = self:get(self.main)
	else
		pkt = self:get(symbol:sub(1, i - 1))
	end
	symbol = symbol:sub(i)
	local value = pkt
	for name in symbol:gmatch('%.([^.]+)') do
		if value == nil then
			if typ ~= nil then
				error(string.format('Unexpected type for %s, expect function, but symbol is undefined', symbol), 1)
			end
			return nil
		end
		value = value[name]
	end
	if typ ~= nil and type(value) ~= typ then
		error(string.format('Unexpected type for %s, expect %s, but got %s', symbol, typ, type(value)), 1)
	end
	return value
end

---- BEGIN TAGS ----

local Tag = {
	-- name = string, -- the tag's name
	single = false,
	-- args = list,

	parent = nil,
	children = nil, -- list or nil; will be nil when single is true

	block = true, -- if it's a block tag
	-- width = int or nil, -- integer or nil means unset
	-- height = int or nil, -- integer or nil means unset

	-- -- See absolute section at <https://developer.mozilla.org/en-US/docs/Web/CSS/position> for more information
	-- absolute = boolean, -- if it use absolute position
	-- top    = int or nil,
	-- left   = int or nil,
	-- bottom = int or nil,
	-- right  = int or nil,

	-- color = color or nil, -- The text color or nil means current color
	-- bgcolor = color or nil, -- The background color

	-- listeners = table,
	_parsed_listeners = false,
}
exports.Tag = Tag

function Tag:new(obj, args)
	expect(1, obj, 'table', 'nil')
	expect(2, args, 'table', 'nil')
	args = args or {}
	obj = obj or {}
	setmetatable(obj, { __index = self, __metatable = self })
	obj.args = args
	if not self.single then
		obj.children = {}
	end
	obj.block = nil
	if args.block then
		obj.block = strToBool[args.block:lower()]
	end
	obj.width = tonumber(args.width) or nil
	obj.height = tonumber(args.height) or nil
	obj.absolute = strToBool[args.abs]
	obj.top = tonumber(args.top) or nil
	obj.left = tonumber(args.left) or nil
	obj.bottom = tonumber(args.bottom) or nil
	obj.right = tonumber(args.right) or nil
	obj.color = parseColor(args.color) or parseColor(args.c) or nil
	obj.bgcolor = parseColor(args.bgcolor) or parseColor(args.bgc) or nil
	obj.listeners = {}
	return obj
end

function Tag:parseListener(scripts)
	assert(not self._parsed_listeners, 'parseListener can only be called once')
	for k, v in pairs(self.args) do
		if k:sub(1, 1) == '@' then
			k = k:sub(2)
			local fn = scripts:symbol(v, 'function')
			local l = self.listeners[k]
			if l then
				l[#l + 1] = fn
			else
				self.listeners[k] = {fn}
			end
		end
	end
	return self
end

function Tag:tostring()
	local s = '/' .. (self.name or '<unknown>')
	for k, v in pairs(self.args) do
		if type(v) == 'string' then
			s = s .. ' ' .. k .. '=' .. textutils.serialiseJSON(v)
		end
	end
	s = s .. '\n'
	if not self.single then
		local cs = ''
		local last = nil
		for _, c in ipairs(self.children) do
			if #cs > 0 and last and last.name == '&plain' then
				if c.name == '&plain' then
					cs = cs .. ' '
				else
					cs = cs .. '\n'
				end
			end
			last = c
			cs = cs .. c:tostring()
			for l in cs:gmatch('([^\n]*)\n') do
				s = s .. '  ' .. l .. '\n'
			end
			cs = cs:match('([^\n]*)$') or ''
		end
		if #cs > 0 then
			s = s .. '  ' .. cs .. '\n'
		end
	end
	return s
end

function Tag:getColor()
	return self.color or table.unpack(self.parent and {self.parent:getColor()} or {nil})
end

function Tag:getBgcolor()
	return self.bgcolor or table.unpack(self.parent and {self.parent:getBgcolor()} or {nil})
end

function Tag:addChild(child)
	assert(isinstance(child, Tag), 'child must be a tag, got '..type(child))
	assert(child.parent == nil, 'The element already have a parent')
	child.parent = self
	self.children[#(self.children) + 1] = child
	return child
end

function Tag:ondraw(win)
	local pWidth, pHeight = win.getSize()
	local pX, pY = win.getCursorPos()
	local wX, wY = pX, pY
	if self.absolute then
		wX, wY = 1, 1
	end
	local nWidth, nHeight = self.width or (pWidth - wX + 1), self.height or (pHeight - wY + 1)
	local w = window.create(win, wX, wY, nWidth, nHeight, false) -- draw it later
	win.setCursorBlink(true)
	w.setTextColor(self:getColor() or win.getTextColor())
	w.setBackgroundColor(self:getBgcolor() or win.getBackgroundColor())
	w.clear()
	-- if true then return end
	if self.single then
		self:draw(w)
	else
		local lastblock = nil
		for _, c in ipairs(self.children) do
			if lastblock ~= nil and not c.absolute and (c.block or lastblock) then
				local _, y = w.getCursorPos()
				w.setCursorPos(1, y + 1)
			end
			if not c.absolute then
				lastblock = c.block
			end
			c:ondraw(w)
		end
	end
	if self.absolute then
		local newX, newY = 1, 1
		local width, height = w.getCursorPos()
		if self.left then
			newX = self.left
		elseif self.right then
			newX = pWidth - self.right - width + 1
		end
		if self.top then
			newY = self.top
		elseif self.bottom then
			newY = pHeight - self.bottom - height + 1
		end
		w.reposition(newX, newY, width, height)
	end
	w.setVisible(true)
	-- w.redraw() -- auto called in setVisible
	if self.absolute then
		win.setCursorPos(pX, pY)
	else
		-- fix cursor position
		local dx, dy = w.getPosition()
		local x, y = w.getCursorPos()
		win.setCursorPos(dx + x - 1, dy + y - 1)
	end
end

function Tag:draw(win)
end

function Tag:onclick(event)
end

local RootTag = {
	name = '&root',
	block = true,
}
setmetatable(RootTag, { __index = Tag, __metatable = Tag })

function RootTag:new(obj, metas)
	expect(2, metas, 'table')
	obj = Tag.new(self, obj, metas)
	obj.scripts = metas.scripts
	return obj
end

local tags = {}
exports.tags = tags

local TagPlain = {
	name = '&plain',
	single = true,
	block = false,
	-- text = string,
}
setmetatable(TagPlain, { __index = Tag, __metatable = Tag })
exports.TagPlain = TagPlain

function TagPlain:new(obj, text)
	expect(2, text, 'string')
	obj = Tag.new(self, obj, nil)
	obj.text = text
	return obj
end

function TagPlain:tostring()
	return textutils.serialiseJSON(self.text)
end

function TagPlain:draw(win)
	win.write(self.text)
end

local TagBlit = {
	name = '&blit',
	single = true,
	block = false,
	-- text = string,
	-- blitcolor = string,
	-- blitbg = string,
}
setmetatable(TagBlit, { __index = Tag, __metatable = Tag })
exports.TagBlit = TagBlit

function TagBlit:new(obj, text, color, bg)
	expect(2, text, 'string')
	expect(3, color, 'string')
	expect(4, bg, 'string')
	assert(#text == #color and #text == #bg, 'the length of the arguments must be same')
	obj = Tag.new(self, obj, nil)
	obj.text = text
	obj.blitcolor = blitcolor
	obj.blitbg = blitbg
	return obj
end

function TagBlit:draw(win)
	win.blit(self.text, self.blitcolor, self.blitbg)
end

local TagP = {
	name = 'p',
	block = true,
}
setmetatable(TagP, { __index = Tag, __metatable = Tag })
tags.p = TagP

local TagT = {
	name = 't',
	block = false,
}
setmetatable(TagT, { __index = Tag, __metatable = Tag })
tags.t = TagT

local TagBr = {
	name = 'br',
	single = true,
	block = false,
}
setmetatable(TagBr, { __index = Tag, __metatable = Tag })
tags.br = TagBr

function TagBr:ondraw(win)
	local _, y = win.getCursorPos()
	win.setCursorPos(1, y + 1)
end

local TagLink = {
	name = 'a',
	block = false,
	color = colors.blue,
	-- target = string or nil, -- the target link, the protocol must be https or http
}
setmetatable(TagLink, { __index = Tag, __metatable = Tag })
tags.a = TagLink

function TagLink:new(obj, args)
	expect(2, args, 'table', 'nil')
	args = args or {}
	obj = Tag.new(self, obj, args)
	obj.target = args.target or args.t or args.href or nil
	return obj
end

function TagLink:onclick(x, y)
	print('Link:', obj.target)
end

local TagImg = {
	name = 'img',
	single = true,
	block = true,
	-- src = '', -- the images link
}
setmetatable(TagImg, { __index = Tag, __metatable = Tag })
tags.img = TagImg

function TagImg:new(obj, args)
	expect(2, args, 'table', 'nil')
	args = args or {}
	obj = Tag.new(self, obj, args)
	obj.src = args.src or args.s or nil
	return obj
end

---- END TAGS ----

local function trim(str)
	return str:match('^%s*(.-)%s*$')
end

local function trimLeft(str)
	local i, j = str:find('^%s+')
	if i then
		return str:sub(j + 1)
	end
	return str
end

local function findAny(str, patterns, starti, endi)
	expect(1, str, 'string')
	expect(2, patterns, 'table')
	expect(3, starti, 'number', 'nil')
	expect(4, endi, 'number', 'nil')
	local ind, jnd = nil
	for i, p in ipairs(patterns) do
		expect(1 + i, p, 'string')
		local j, l = str:find(p, starti, endi)
		if j and (not ind or j < ind) then
			ind, jnd = j, l
		end
	end
	return ind, jnd
end

local function unescapeStr(str, tk)
	return textutils.unserialiseJSON(tk .. str .. tk)
	-- local s = ''
	-- local i = 1
	-- local j = 0
	-- while true do
	-- 	j = line:find('\\', i)
	-- 	if not j then
	-- 		return s
	-- 	end
	-- 	s = s .. str:sub(i, j - 1) .. str:sub(j + 1, j + 1)
	-- 	i = j + 2
	-- end
end

local function parseStr0(line, tk)
	if tk then
		local i = 0
		while true do
			i = line:find(tk, i + 1)
			if not i then
				error('String missing end token ('..tk..')', 4)
			end
			if line:sub(i - 1, i - 1) ~= '\\' then
				return unescapeStr(line:sub(1, i - 1), tk), line:sub(i + 1)
			end
		end
	else
		local i = line:find('[%s;]')
		if not i then
			return line, ''
		end
		return line:sub(1, i - 1), line:sub(i)
	end
end

local function parseStr(line)
	local tk = line:sub(1, 1)
	if tk == "'" or tk == '"' then
		return parseStr0(line:sub(2), tk)
	end
	return parseStr0(line)
end

local function parseTag(line)
	local name
	do
		local i, j = line:find('^[a-zA-Z0-9_-]+')
		if not i then
			error('Unexpected character "'..line:sub(1, 1)..'"')
		end
		name, line = line:sub(1, j), trimLeft(line:sub(j + 1))
	end
	local tagCls = tags[name]
	if not tagCls then
		error('Tag '..name..' is unexpected', 3)
	end
	local args = {}
	while #line > 0 and line:sub(1, 1) ~= ';' do
		if #line == 1 and line:sub(1, 1) == '\\' then
			return nil
		elseif line:sub(1, 2) == '--' then
			line = ''
			break
		end
		local i, j = line:find('^@?[a-zA-Z0-9_-]+')
		if not i then
			error('Unexpected character "'..line:sub(1, 1)..'"')
		end
		local key
		local value = ''
		key, line = line:sub(i, j), line:sub(j + 1)
		local s = line:sub(1, 1)
		if s == '=' then
			value, line = parseStr(line:sub(2))
			local i, j = line:find('^%s+')
			if i then
				line = line:sub(j + 1)
			end
		elseif #line > 0 then
			local i, j = line:find('^%s+')
			if not i then
				error('Unexpected character "'..line:sub(1, 1)..'"')
			end
			line = line:sub(j + 1)
		end
		args[key] = value
	end
	local tag = tagCls:new(nil, args)
	return tag, line
end

local function parse(r)
	local meta = nil
	local scripts = ScriptSet:new()
	local body = nil -- RootTag
	local current = nil
	local line = ''
	local next = true
	while true do
		if next then
			local cache = r:read('*line')
			if not cache then
				if #line > 0 then
					error('Unexpected EOF')
				end
				break
			end
			line = line .. cache
		else
			next = true
		end
		local tline = trimLeft(line)
		line = '' -- clear cache
		if #tline > 0 and tline:sub(1, 2) ~= '--' then
			if body then
				if tline:sub(1, 1) == '/' then -- a tag
					local tag
					tag, line = parseTag(tline:sub(2))
					if tag then
						tag = tag:parseListener(scripts)
						if line:sub(1, 1) == ';' then
							next = false
							line = line:sub(2)
						end
						current:addChild(tag)
						if line:sub(1, 1) == ';' then -- two continue semicolon
							line = line:sub(2)
						elseif not tag.single then
							current = tag
						end
					else
						line = tline:sub(1, -2) .. ' '
					end
				else -- a plain text
					local t = ''
					local last = 1
					local noeol = true
					while true do
						local i = findAny(tline, {'\\', ';', '-%-'}, last)
						if not i then
							t = t .. tline:sub(last)
							break
						end
						t = t .. tline:sub(last, i - 1)
						local c = tline:sub(i, i)
						if c == '-' then -- it's a comment
							break
						end
						if c == ';' then -- EOL
							next = false
							noeol = false
							if not t:find('^%s+$') then
								current:addChild(TagPlain:new(nil, t))
							end
							if tline:sub(i + 1, i + 1) == ';' then
								if current == body then
									error('Cannot end the root node')
								end
								current = current.parent
								line = tline:sub(i + 2)
							else
								line = tline:sub(i + 1)
							end
							break
						end
						-- parse escape
						if i == #tline then -- escape EOL
							noeol = false
							line = tline:sub(1, i - 1) .. ' '
							break
						end
						c = tline:sub(i + 1, i + 1)
						if c == '-' then
							local p, q = tline:find('%-+', i + 1)
							t = t .. tline:sub(p, q)
							last = q + 1
						else
							t = t .. c
							last = i + 2
						end
					end
					if noeol then
						if not t:find('^%s+$') then
							current:addChild(TagPlain:new(nil, t))
						end
					end
				end
			elseif meta then
				if tline == '@body' then
					body = RootTag:new({}, meta)
					current = body
				else
					local i = tline:find('-%-')
					if i then
						tline = trim(tline:sub(1, i - 1))
					end
					if #tline > 0 then
						local i, j = tline:find('^[a-zA-Z0-9_-]+')
						if not i then
							error('Unexpected character "'..tline:sub(1, 1)..'"', 5)
						end
						local name, value
						name, tline = tline:sub(1, j), tline:sub(j + 1)
						if not tline:match('^[%s=]') then
							error('Unexpected character "'..tline:sub(1, 1)..'"', 5)
						end
						value = tline:match('^%s*=?%s*(.*)')
						if name == 'width' or name == 'height' then
							meta[name] = tonumber(value)
						elseif name == 'color' or name == 'bgcolor' then
							meta[name] = parseColor(value)
						elseif name == 'main' then
							scripts:addMain(value)
							if scripts['__main'] then
								error('Main script already exists')
							end
							local s = require(value)
							scripts[value] = s
							scripts['__main'] = s
						elseif name == 'script' then
							scripts:add(value)
							scripts[value] = require(value)
						end
					end
				end
			elseif tline == '@meta' then
				meta = {
					scripts = scripts,
				}
			end
		end
	end
	return body
end
exports.parse = parse

return exports
