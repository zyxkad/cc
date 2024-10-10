-- Pocket scanner
-- by zyxkad@gmail.com

local dictionary = {
	['#minecraft:block/forge:ores/certus_quartz'] = {
		value = -1,
	},
	['#minecraft:block/forge:dirt'] = {
		color = colors.brown,
	},
	['#minecraft:block/minecraft:leaves'] = {
		color = colors.green,
	},
	['#minecraft:block/minecraft:logs'] = {
		value = 1,
		color = colors.brown,
		ch = 'L',
	},
	['#minecraft:block/forge:ores/coal'] = {
		value = 1,
		color = colors.gray,
		ch = 'C',
	},
	['#minecraft:block/forge:ores/copper'] = {
		value = 1,
		textColor = colors.orange,
		ch = 'C',
	},
	['#minecraft:block/forge:ores/lapis'] = {
		value = 2,
		color = colors.lightBlue,
		ch = 'L',
	},
	['#minecraft:block/forge:ores/zinc'] = {
		value = 2,
		textColor = colors.lime,
		ch = 'Z',
	},
	['#minecraft:block/forge:ores/tin'] = {
		value = 2,
		color = colors.lightBlue,
		ch = 'T',
	},
	['#minecraft:block/forge:ores/sulfur'] = {
		value = 2,
		textColor = colors.green,
		ch = 'S',
	},
	['#minecraft:block/forge:ores/nickel'] = {
		value = 2,
		textColor = colors.yellow,
		ch = 'N',
	},
	['#minecraft:block/forge:ores/lead'] = {
		value = 2,
		textColor = colors.black,
		ch = 'L',
	},
	['#minecraft:block/forge:ores/iron'] = {
		value = 2,
		color = colors.pink,
	},
	['#minecraft:block/forge:ores/silver'] = {
		value = 2,
		textColor = colors.black,
		ch = 'S',
	},
	['#minecraft:block/forge:ores/gold'] = {
		value = 3,
		color = colors.yellow,
	},
	['#minecraft:block/forge:ores/redstone'] = {
		value = 3,
		color = colors.red,
	},
	['#minecraft:block/forge:ores/emerald'] = {
		value = 3,
		color = colors.lime,
	},
	['#minecraft:block/forge:ores/osmium'] = {
		value = 3,
		color = colors.lime,
		ch = 'O',
	},
	['#minecraft:block/forge:ores/diamond'] = {
		value = 4,
		color = colors.lightBlue,
		textColor = colors.blue,
		ch = 'O'
	},
	['#minecraft:block/forge:ores/netherite_scrap'] = {
		value = 8,
		color = colors.lightBlue,
		ch = 'A',
	},
	['#minecraft:block/forge:ores/quartz'] = {
		value = 2,
		color = colors.white,
	},
	['#minecraft:block/forge:barrels'] = {
		color = colors.cyan,
		ch = 'B',
	},
	['#minecraft:block/forge:chests'] = {
		value = 1,
		color = colors.cyan,
		ch = 'C',
	},
	['minecraft:water'] = {
		color = colors.blue,
	},
	['minecraft:ice'] = {
		color = colors.blue,
		ch = 'I',
	},
	['minecraft:packed_ice'] = {
		color = colors.blue,
		ch = 'P',
	},
	['minecraft:blue_ice'] = {
		color = colors.blue,
		ch = 'B',
	},
	['minecraft:lava'] = {
		value = 1,
		color = colors.orange,
	},
	['minecraft:obsidian'] = {
		value = 1,
		color = colors.black,
		ch = 'O',
	},
	['minecraft:soul_sand'] = {
		color = colors.brown,
	},
	['minecraft:soul_soil'] = {
		color = colors.brown,
	},
	['minecraft:magma_block'] = {
		color = colors.magenta,
		ch = 'M',
	},
	['minecraft:glowstone'] = {
		value = 1,
		color = colors.yellow,
		textColor = colors.orange,
		ch = 'G',
	},
	['minecraft:sponge'] = {
		value = 8,
		color = colors.yellow,
		ch = 'S',
	},
	['minecraft:wet_sponge'] = {
		value = 8,
		color = colors.yellow,
		ch = 'S',
	},

	['minecraft:dirt'] = '#minecraft:block/forge:dirt',
	['minecraft:dirt_path'] = '#minecraft:block/forge:dirt',
	['minecraft:grass_block'] = '#minecraft:block/forge:dirt',
	['minecraft:ancient_debris'] = '#minecraft:block/forge:ores/netherite_scrap',
}

local fallbackDict = {
	['#minecraft:block/forge:ores'] = {
		value = 1,
		color = colors.white,
		ch = 'E',
	},
}

local scanner = peripheral.wrap('back')
if not scanner then
	error('scanner not found', 1)
elseif not scanner.scan then
	error('backside is not a scanner', 1)
end
local isGeoScanner = peripheral.hasType(scanner, 'geoScanner')

local MAX_RADIUS = 8
if isGeoScanner then
	if true then
		MAX_RADIUS = scanner.getConfiguration().scanBlocks.maxCostRadius
	else
		MAX_RADIUS = scanner.getConfiguration().scanBlocks.maxFreeRadius
	end
end

local canvasScale = 0.5
local canvas = scanner.canvas and scanner.canvas()
local canvasObjs = {}
if canvas then
	canvas.clear()
	debugText = canvas.addText({ x=10, y=150 }, '', 0xffffffff, 0.8)
	for z = -MAX_RADIUS - 1, MAX_RADIUS do
		local row = {}
		canvasObjs[z] = row
		for x = -MAX_RADIUS - 1, MAX_RADIUS do
			row[x] = {
				rect = canvas.addRectangle(10 + (x + MAX_RADIUS + 1) * 10 * canvasScale, 10 + (z + MAX_RADIUS + 1) * 10 * canvasScale, 10 * canvasScale, 10 * canvasScale, 0),
				text = canvas.addText({
					x = 10 + ((x + MAX_RADIUS + 1) * 10 + 3) * canvasScale,
					y = 10 + ((z + MAX_RADIUS + 1) * 10 + 1) * canvasScale,
				}, '', 0, canvasScale)
			}
		end
	end
end
local _canvas3d = scanner.canvas3d and scanner.canvas3d()
if _canvas3d then
	_canvas3d.clear()
end
local canvas3d = _canvas3d and _canvas3d.create()
local canvas3dObjs = {}
local canvas3dObjCaches = {}
local canvas3dObjCaches2 = {}
if canvas3d then
	for z = -MAX_RADIUS - 1, MAX_RADIUS do
		local row = {}
		canvas3dObjs[z] = row
		for x = -MAX_RADIUS - 1, MAX_RADIUS do
			row[x] = {}
		end
	end
end

local function getOrAddObjAt(x, y, z)
	local obj = canvas3dObjs[z][x][y]
	if obj then
		return obj
	end
	if #canvas3dObjCaches > 0 then
		obj = canvas3dObjCaches[#canvas3dObjCaches]
		canvas3dObjCaches[#canvas3dObjCaches] = nil
		obj.box.setPosition(x, y, z)
		obj.box.setSize(1, 1, 1)
	elseif #canvas3dObjCaches2 > 0 then
		obj = canvas3dObjCaches2[#canvas3dObjCaches2]
		canvas3dObjCaches2[#canvas3dObjCaches2] = nil
		obj.box.setPosition(x, y, z)
		obj.box.setSize(1, 1, 1)
	else
		obj = {
			box = canvas3d.addBox(x, y, z, 1, 1, 1, 0)
		}
	end
	obj.box.setDepthTested(false)
	canvas3dObjs[z][x][y] = obj
	return obj
end

local function remove3dObjAt(x, y, z)
	local obj = canvas3dObjs[z][x][y]
	if not obj then
		return
	end
	canvas3dObjs[z][x][y] = nil
	obj.box.setAlpha(0)
	obj.box.setSize(0, 0, 0)
	canvas3dObjCaches[#canvas3dObjCaches + 1] = obj
end

local NIL_TABLE = {}

local function scan(n)
	if not n then
		n = MAX_RADIUS
	end
	local scaned, err
	term.setTextColor(colors.white)
	while true do
		sleep(0)
		local cool = isGeoScanner and scanner.getOperationCooldown('scanBlocks') or 0
		if cool <= 0 then
			break
		end
		term.setCursorPos(1, 1)
		term.clearLine()
		term.write(string.format('Remain: %dms', cool))
	end
	term.setCursorPos(1, 1)
	term.clearLine()
	term.write('Scanning...')
	scaned, err = scanner.scan(n)
	term.setCursorPos(1, 1)
	term.clearLine()
	term.write('Scanned')
	if not scaned then
		term.setTextColor(colors.red)
		term.write(' FAILED')
		return nil, err
	end
	term.setTextColor(colors.green)
	term.write(' SUCCESSED')
	local data = {}
	for _, d in ipairs(scaned) do
		-- table.sort(d.tags, function(a, b) return #a > #b end)
		local z = data[d.z]
		if not z then
			z = {}
			data[d.z] = z
		end
		local x = z[d.x]
		if not x then
			x = {}
			z[d.x] = x
		end
		x[d.y] = d
	end
	term.write(' CVD')
	return data
end

local function parseBlock(blk)
	if blk.name == 'minecraft:air' then
		return NIL_TABLE
	end
	local b = dictionary[blk.name]
	if type(b) == 'string' then
		b = dictionary[b]
	end
	if b then
		return b
	end
	if blk.name:match('_log$') then
		b = dictionary['#minecraft:block/minecraft:logs']
	elseif blk.name:match('coal_ore$') then
		b = dictionary['#minecraft:block/forge:ores/coal']
	elseif blk.name:match('copper_ore$') then
		b = dictionary['#minecraft:block/forge:ores/copper']
	elseif blk.name:match('iron_ore$') then
		b = dictionary['#minecraft:block/forge:ores/iron']
	elseif blk.name:match('gold_ore$') then
		b = dictionary['#minecraft:block/forge:ores/gold']
	elseif blk.name:match('redstone_ore$') then
		b = dictionary['#minecraft:block/forge:ores/redstone']
	elseif blk.name:match('emerald_ore$') then
		b = dictionary['#minecraft:block/forge:ores/emerald']
	elseif blk.name:match('lapis_ore$') then
		b = dictionary['#minecraft:block/forge:ores/lapis']
	elseif blk.name:match('diamond_ore$') then
		b = dictionary['#minecraft:block/forge:ores/diamond']
	elseif blk.name:match('quartz_ore$') then
		b = dictionary['#minecraft:block/forge:ores/quartz']
	elseif blk.tags then
		for _, t in ipairs(blk.tags) do
			b = dictionary['#'..t]
			if b then
				return b
			end
		end
		for _, t in ipairs(blk.tags) do
			b = fallbackDict['#'..t]
			if b then
				return b
			end
		end
	end
	return b or NIL_TABLE
end

local function getMostValuable(data)
	if not data then
		return nil
	end
	local d, d0
	for _, b0 in pairs(data) do
		if b0.name ~= 'minecraft:air' then
			local b = parseBlock(b0)
			if not d or (d.value or 0) < (b.value or 0) or
				 ((d.value or 0) == (b.value or 0) and math.abs(d0.y) > math.abs(b0.y)) then
				d, d0 = b, b0
			end
		end
	end
	return d, d0
end

local ownerData = nil

function main()
	local data, anaBlk
	local twidth, theight = term.getSize()
	local mapwin = window.create(term.current(), 1, 2, twidth, theight)
	local width, height = mapwin.getSize()
	local hx, hy = math.floor(width / 2), math.floor(height / 2)
	local cx, cy = hx, hy

	term.clear()
	function drawData()
		if not data then
			return false
		end
		local mapwinVisible = mapwin.isVisible()
		if mapwinVisible then
			mapwin.setVisible(false)
			mapwin.setBackgroundColor(colors.black)
			mapwin.clear()
		end
		if canvas3d then
			local pos = {0, 0, 0}
			if ownerData then
				pos[1] = -ownerData.withinBlock.x - ownerData.deltaPosX
				pos[2] = -ownerData.withinBlock.y - ownerData.deltaPosY
				pos[3] = -ownerData.withinBlock.z - ownerData.deltaPosZ
			end
			canvas3d.recenter(pos[1], pos[2], pos[3])
		end
		for z = -MAX_RADIUS - 1, MAX_RADIUS do
			local py = cy + z
			local l = data[z]
			for x = -MAX_RADIUS - 1, MAX_RADIUS do
				local px = cx + x
				local c = l and l[x]
				for y = -MAX_RADIUS - 1, MAX_RADIUS do
					local blk = c and c[y]
					if blk then
						local b = parseBlock(blk)
						if b.value and b.value > 0 and b.color then
							local obj = getOrAddObjAt(x, y, z)
							obj.box.setColor(colors.packRGB(term.getPaletteColour(b.color)) * 0x100 + 0x10)
						else
							remove3dObjAt(x, y, z)
						end
					else
						remove3dObjAt(x, y, z)
					end
				end
				local d, d0 = getMostValuable(c)
				local bgColor, textColor, ch = colors.black, colors.white, ' '
				if d then
					bgColor = d.color or colors.lightGray
					textColor = d.textColor or (d.color == colors.white and colors.black or colors.white)
					ch = (x == 0 and z == 0 and 'X') or d.ch or ' '
				else
					ch = (x == 0 and z == 0 and (d0 and d0.y <= 0 and 'X' or 'x')) or ' '
				end
				mapwin.setBackgroundColor(bgColor)
				mapwin.setTextColor(textColor)
				if 0 < py and py <= height and 0 < px and px <= width then
					mapwin.setCursorPos(px, py)
					mapwin.write(ch)
				end
				if canvas then
					local obj = canvasObjs[z][x]
					if d then
						obj.rect.setColor(colors.packRGB(term.getPaletteColour(bgColor)) * 0x100 + 0x80)
					else
						obj.rect.setAlpha(0)
					end
					obj.text.setText(ch)
					obj.text.setColor(colors.packRGB(term.getPaletteColour(textColor)) * 0x100 + 0xff)
				end
			end
		end
		if mapwinVisible then
			mapwin.setVisible(true)
			mapwin.redraw()
		end
		if canvas3d then
			for _, obj in ipairs(canvas3dObjCaches2) do
				obj.box.remove()
			end
			canvas3dObjCaches2 = canvas3dObjCaches
			canvas3dObjCaches = {}
		end
	end
	function whileScan()
		local err
		while true do
			if mapwin.isVisible() then
				data, err = scan()
				if not data then
					term.clear()
					term.setCursorPos(1, 2)
					printError(err)
					sleep(3)
				else
					drawData()
				end
			else
				sleep(0.1)
			end
		end
	end
	function whileUpdateOwner()
		while true do
			ownerData = scanner.getMetaOwner()
		end
	end

	local anawin = window.create(term.current(), 1, 2, twidth, theight, false)
	local anatagwin = window.create(anawin, 1, 5, twidth, theight - 5)
	local anaTdx, anaTdy = 1, 0

	function redrawAnaTags()
		anawin.setBackgroundColor(colors.black)
		anawin.setTextColor(colors.white)
		anawin.setCursorPos(1, 2)
		anawin.clearLine()
		anawin.write(anaBlk.name:sub(anaTdx))
		anatagwin.clear()
		if anaBlk.tags then
			for i, t in ipairs(anaBlk.tags) do
				if i + anaTdy > 0 then
					anatagwin.setCursorPos(1, i + anaTdy)
					anatagwin.write(string.sub('- '..t, anaTdx))
				end
			end
		end
	end
	function analysis(d, d0)
		anaBlk = d0
		anaTdx, anaTdy = 1, 0
		anawin.clear()
		anawin.setCursorPos(1, 1)
		anawin.setBackgroundColor(d.color or colors.lightGray)
		anawin.setTextColor(d.chColor or (d.color == colors.white and colors.black or colors.white))
		anawin.write(d.ch or ' ')
		anawin.setBackgroundColor(colors.black)
		anawin.setTextColor(colors.white)
		anawin.setCursorPos(1, 3)
		anawin.write(string.format('Pos: %d %d %d', d0.x, d0.y, d0.z))
		if d0.tags then
			anawin.setCursorPos(1, 4)
			anawin.write(string.format('Have %d tags', #d0.tags))
		end
		redrawAnaTags()
	end
	function onClick(x, y, btn)
		term.setCursorPos(1, 1)
		if y == 1 then
			if mapwin.isVisible() then
				cx, cy = hx, hy
				drawData()
			end
		else
			if anawin.isVisible() then
				anawin.setVisible(false)
				mapwin.setVisible(true)
			else -- clicking the map
				local dx, dz = x - cx, y - 1 - cy
				if data then
					local l = data[dz]
					if l then
						local d, d0 = getMostValuable(l[dx])
						if d then
							analysis(d, d0)
							mapwin.setVisible(false)
							anawin.setVisible(true)
						end
					end
				end
			end
		end
	end
	function onKeyDown(key, is_held)
		if anawin.isVisible() then
			if key == keys.left then
				if anaTdx > 1 then
					anaTdx = anaTdx - 1
				end
			elseif key == keys.right then
				anaTdx = anaTdx + 1
			elseif key == keys.up then
				if true then
					anaTdy = anaTdy + 1
				end
			elseif key == keys.down then
				anaTdy = anaTdy - 1
			end
			redrawAnaTags()
		else
			if key == keys.left then
				cx = cx + 1
			elseif key == keys.right then
				cx = cx - 1
			elseif key == keys.up then
				cy = cy + 1
			elseif key == keys.down then
				cy = cy - 1
			end
			drawData()
		end
	end
	function pullEvents()
		while true do
			local event, a1, a2, a3 = os.pullEvent()
			if event == 'mouse_click' then
				local btn, x, y = a1, a2, a3
				onClick(x, y, btn)
			elseif event == 'key' then
				local key, is_held = a1, a2
				onKeyDown(key, is_held)
			end
		end
	end

	parallel.waitForAny(whileScan, whileUpdateOwner, pullEvents)
end

main()
