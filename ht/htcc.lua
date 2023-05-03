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

local function sendMessage(chatbox, msg, msgPrompt, target)
	if type(msg) == 'table' then
		if msg['text'] == nil then -- if it's an array
			msg = {
				text = '',
				extra = msg,
			}
		end
		msg = textutils.serialiseJSON(msg)
	elseif type(msg) ~= 'str' then
		error('Message must be a string or a table')
	end
	if target then
		local ok, err
		-- try for 1.05s
		for i = 0, 101 do
			ok, err = chatbox.sendFormattedMessageToPlayer(msg, target, msgPrompt)
			if ok then
				break
			end
			sleep(0.05)
		end
		if not ok then
			printError('Cannot send message to player:', ok, err)
		end
	else
		local ok, err
		for i = 0, 101 do
			ok, err = chatbox.sendFormattedMessage(msg, msgPrompt)
			if ok then
				break
			end
			sleep(0.05)
		end
		if not ok then
			printError('Cannot send message:', ok, err)
		end
	end
end


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
	-- elem = Tag,
	-- x = integer,
	-- y = integer,
	-- absX = integer,
	-- absY = integer,
}
setmetatable(ClickEvent, { __index = Event, __metatable = Event })
exports.ClickEvent = ClickEvent

function ClickEvent:new(obj, elem, x, y, absX, absY)
	expect(1, obj, 'table', 'nil')
	expect(2, elem, 'table')
	expect(3, x, 'number')
	expect(4, y, 'number')
	expect(5, absX, 'number')
	expect(6, absY, 'number')
	obj = Event.new(self, obj, {
		elem = elem,
		x = x,
		y = y,
		absX = absX,
		absY = absY,
	})
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

---- BEGIN VIEWBOX ----

local allOverflowMode = {
	['hidden'] = true,
	['visible'] = true,
}

function createView(mWidth, mHeight)
	expect(1, mWidth, 'number', 'nil')
	expect(2, mHeight, 'number', 'nil')

	local view = {}

	local maxWidth, maxHeight = mWidth, mHeight
	local cursorX = 1
	local cursorY = 1
	local textColor = colors.white
	local backgroundColor = colors.black
	local cursorBlink = false
	local lines = {}
	local usedY = 0

	function view.drawOn(win, dx, dy, width, height, overflowMode)
		expect(1, win, 'table')
		expect(2, dx, 'number')
		expect(3, dy, 'number')
		expect(4, width, 'number')
		expect(5, height, 'number')
		expect(6, overflowMode, 'string', 'nil')
		overflowMode = overflowMode or 'hidden'
		if not allOverflowMode[overflowMode] then
			error('Unknown overflow mode "' .. overflowMode .. '"', 1)
		end
		local tc = colors.toBlit(textColor)
		local bc = colors.toBlit(backgroundColor)
		win.setCursorBlink(cursorBlink)
		local maxWidth, maxHeight = win.getSize()
		maxWidth, maxHeight = maxWidth - dx + 1, maxHeight - dy + 1
		if overflowMode == 'hidden' then
			height = math.min(height, maxHeight)
		end
		for i = 1, height do
			local l = lines[i]
			local s, t, b
			if l then
				s, t, b = table.unpack(l)
			else
				s, t, b = string.rep(' ', width), tc:rep(width), bc:rep(width)
			end
			if #s < width then
				local a = width - #s
				s, t, b = s .. string.rep(' ', a), t .. tc:rep(a), b .. bc:rep(a)
			elseif #s > width then
				if overflowMode == 'hidden' then
					s, t, b = s:sub(1, width), t:sub(1, width), b:sub(1, width)
				end
			end
			win.setCursorPos(dx, dy + i - 1)
			win.blit(s, t, b)
		end
	end

	function view.clearLine()
		lines[cursorY] = nil
		if cursorY == usedY then
			usedY = usedY - 1
		end
	end

	function view.clear()
		lines = {}
		usedY = 0
	end

	function view.getLine(y)
		expect(1, y, 'number')
		return lines[y]
	end

	function view.scroll(n)
		expect(1, n, 'number')
		n = math.floor(n)
		if usedY > 0 then
			if n > 0 then
				if n >= usedY then
					view.clear()
				else
					for i = 1, usedY - n do
						lines[i] = lines[i + n]
					end
					usedY = usedY - n
				end
			elseif n < 0 then
				if n <= -usedY then
					view.clear()
				else
					for i = usedY, 1, -1 do
						lines[i + n] = lines[i]
					end
					usedY = usedY + n
				end
			end
		end
	end

	function view.getCursorBlink()
		return cursorBlink
	end

	function view.setCursorBlink(blink)
		expect(1, blink, 'boolean')
		cursorBlink = blink
	end

	function view.getCursorPos()
		return cursorX, cursorY
	end

	function view.setCursorPos(x, y)
		expect(1, x, 'number')
		expect(2, y, 'number')
		cursorX, cursorY = x, y
	end

	function view.nextLine()
		cursorX, cursorY = 1, cursorY + 1
	end

	function view.getSize()
		return maxWidth, maxHeight
	end

	function view.setSize(mWidth, mHeight)
		maxWidth, maxHeight = mWidth, mHeight
	end

	function view.getUsedSize()
		local usedX = 0
		for y = 1, usedY do
			local l = lines[y]
			if l then
				local s = l[1]
				usedX = math.max(usedX, #s)
			end
		end
		return usedX, usedY
	end

	function view.isColor()
		return true
	end

	view.isColour = view.isColor

	function view.getTextColor()
		return textColor
	end

	view.getTextColour = view.getTextColor

	function view.setTextColor(color)
		expect(1, color, 'number')
		textColor = color
	end

	view.setTextColour = view.setTextColor

	function view.getBackgroundColor()
		return backgroundColor
	end

	view.getBackgroundColour = view.getBackgroundColor

	function view.setBackgroundColor(color)
		expect(1, color, 'number')
		backgroundColor = color
	end

	view.setBackgroundColour = view.setBackgroundColor

	local function internalBlit(data, color, bgcolor)
		expect(1, data, 'string')
		expect(2, color, 'string')
		expect(3, bgcolor, 'string')
		assert(#data == #color and #data == #bgcolor, "Text's length is not match the colors' length")
		if #data == 0 then
			return cursorX
		end
		local l = lines[cursorY]
		local nl
		if l then
			local newX = cursorX + #data
			lines[cursorY] = {
				l[1]:sub(1, cursorX - 1) .. data .. l[1]:sub(newX + 1),
				l[2]:sub(1, cursorX - 1) .. color .. l[2]:sub(newX + 1),
				l[3]:sub(1, cursorX - 1) .. bgcolor .. l[3]:sub(newX + 1)
			}
			cursorX = newX
		else
			lines[cursorY] = { 
				string.rep(' ', cursorX - 1) .. data,
				string.rep(colors.toBlit(textColor), cursorX - 1) .. color,
				string.rep(colors.toBlit(backgroundColor), cursorX - 1) .. bgcolor
			}
			cursorX = #data
		end
		if cursorY > usedY then
			usedY = cursorY
		end
		return cursorX, usedY
	end

	function view.write(data)
		data = tostring(data)
		return internalBlit(data,
			colors.toBlit(textColor):rep(#data),
			colors.toBlit(backgroundColor):rep(#data))
	end

	function view.blit(data, color, bgcolor)
		return internalBlit(data, color:lower(), bgcolor:lower())
	end

	return view
end

---- END VIEWBOX ----

local strToBool = {
	['true'] = true,
	t = true,
	yes = true,
	y = true,
	ok = true,

	['false'] = false,
	f = false,
	no = false,
	n = false,
}

---- BEGIN TAGS ----

local Tag = {
	-- name = string, -- the tag's name
	single = false,
	-- args = list,

	parent = nil,
	children = nil, -- list or nil; will be nil when single is true

	--- begin args ---

	visible = true,
	block = true, -- if it's a block tag
	-- width = int or nil, -- integer or nil means unset
	-- height = int or nil, -- integer or nil means unset
	overflow = 'hidden', -- enum of ['hidden', 'visible'] -- TODO 'break', 'scroll'

	-- -- See absolute section at <https://developer.mozilla.org/en-US/docs/Web/CSS/position> for more information
	absolute = false, -- boolean; if it use absolute position
	-- top    = int or nil,
	-- left   = int or nil,
	-- bottom = int or nil,
	-- right  = int or nil,

	-- color = color or nil, -- The text color or nil means current color
	-- bgcolor = color or nil, -- The background color

	-- listeners = table,
	_parsed_listeners = false,

	--- end args ---

	-- _view = view,
	-- _dx = number,
	-- _dy = number,
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
	if args.visible then
		obj.visible = strToBool[args.visible:lower()]
	end
	if args.block then
		obj.block = strToBool[args.block:lower()]
	end
	obj.width = tonumber(args.width) or nil
	obj.height = tonumber(args.height) or nil
	if args.abs then
		obj.absolute = strToBool[args.abs:lower()]
	end
	obj.top = tonumber(args.top) or nil
	obj.left = tonumber(args.left) or nil
	obj.bottom = tonumber(args.bottom) or nil
	obj.right = tonumber(args.right) or nil
	obj.color = parseColor(args.color) or parseColor(args.c) or nil
	obj.bgcolor = parseColor(args.bgcolor) or parseColor(args.bgc) or nil
	obj.listeners = {}
	obj._view = createView()
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
	return self.bgcolor or table.unpack(self.parent and { self.parent:getBgcolor() } or { nil })
end

function Tag:addChild(child)
	assert(isinstance(child, Tag), 'child must be a tag, got '..type(child))
	assert(child.parent == nil, 'The element already have a parent')
	child.parent = self
	self.children[#(self.children) + 1] = child
	return child
end

function Tag:draw(win)
	if not self.visible then
		return
	end

	local pWidth, pHeight = win.getSize()
	local pX, pY = win.getCursorPos()
	local wX, wY = pX, pY
	if self.absolute then
		wX, wY = 1, 1
	end
	local nWidth, nHeight = self.width or (pWidth - wX + 1), self.height or (pHeight - wY + 1)
	self._view.setCursorPos(1, 1)
	self._view.setSize(nWidth, nHeight)
	self._view.setTextColor(self:getColor() or win.getTextColor())
	self._view.setBackgroundColor(self:getBgcolor() or win.getBackgroundColor())
	self._view.clear()
	-- if true then return end
	if self.single then
		self:ondraw(self._view)
	else
		local lastblock = nil
		for _, c in ipairs(self.children) do
			if lastblock ~= nil and not c.absolute and (c.block or lastblock) then
				self._view.nextLine()
			end
			if not c.absolute then
				lastblock = c.block
			end
			c:draw(self._view)
		end
	end
	local uWidth, uHeight = self._view.getUsedSize()
	uWidth, uHeight = self.width or uWidth, self.height or uHeight
	if self.absolute then
		local dX, dY = 1, 1
		if self.left then
			dX = self.left
		elseif self.right then
			dX = pWidth - self.right - uWidth + 1
		end
		if self.top then
			dY = self.top
		elseif self.bottom then
			dY = pHeight - self.bottom - uHeight + 1
		end
		self._dx, self._dy = dX, dY
	else
		self._dx, self._dy = pX, pY
	end
	self._view.drawOn(win, self._dx, self._dy, uWidth, uHeight, self.overflow)
	-- fix cursor position
	if self.absolute then
		win.setCursorPos(pX, pY)
	else
		win.setCursorPos(pX + uWidth, pY + uHeight - 1)
	end
end

function Tag:ondraw(win)
end

function Tag:click(x, y, absX, absY)
	if not self.visible then
		return nil
	end
	if not self._dx or not self._dy then -- must be rendered at lease once
		return nil
	end
	x, y = x - self._dx + 1, y - self._dy + 1
	local uWidth, uHeight = self._view.getUsedSize()
	uWidth, uHeight = self.width or uWidth, self.height or uHeight
	if x < 1 or x > uWidth or y < 1 or y > uHeight then
		return nil
	end
	local event = nil
	if not self.single then
		for i = #self.children, 1, -1 do -- z-index is reversed
			local c = self.children[i]
			if not c.absolute then
				event = c:click(x, y, absX, absY)
				if event then
					if event.canceled then
						return event
					end
					break
				end
			end
		end
	end
	if not event then
		event = ClickEvent:new(nil, self, x, y, absX, absY)
	end
	self:onclick(event)
	if not event.canceled then
		self:fireEvent(event)
	end
	return event
end

function Tag:onclick(event)
end

function Tag:fireEvent(event)
	local lnrs = self.listeners[event.name]
	if lnrs then
		for _, l in ipairs(lnrs) do
			l(event)
			if event.canceled then
				return
			end
		end
	end
end

local RootTag = {
	name = '&root',
	block = true,
}
setmetatable(RootTag, { __index = Tag, __metatable = Tag })

function RootTag:new(obj, metas)
	expect(2, metas, 'table')
	obj = Tag.new(self, obj, metas)
	obj._mWidth = obj.width
	obj._mHeight = obj.height
	obj.scripts = metas.scripts
	return obj
end

function RootTag:draw(win)
	local w, h = win.getSize()
	local x, y = win.getCursorPos()
	self.width = w - x + 1
	self.height = h - y + 1
	if self._mWidth and self._mWidth < self.width then
		self.width = self._mWidth
	end
	if self._mHeight and self._mHeight < self.Hhight then
		self.Hhight = self._mHeight
	end
	return Tag.draw(self, win)
end

function RootTag:click(x, y)
	return Tag.click(self, x, y, x, y)
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

function TagPlain:ondraw(win)
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

function TagBlit:ondraw(win)
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

function TagBr:draw(win)
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

function TagLink:onclick(event)
	event:cancel()
	local cb = peripheral.find('chatBox')
	if cb then
		sendMessage(cb, {
			text = self.target,
			color = 'blue',
			underlined = true,
			clickEvent = {
				action = 'open_url',
				value = self.target,
			},
			hoverEvent = {
				action = 'show_text',
				value = self.target,
			},
		}, 'HT-Link')
	else
		print('Link:', self.target)
	end
	return true
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
