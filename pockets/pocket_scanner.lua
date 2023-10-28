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
}

local fallbackDict = {
	['#minecraft:block/forge:ores'] = {
		value = 1,
		color = colors.white,
		ch = 'E',
	},
}

local scanner = peripheral.find('geoScanner')
if not scanner then
	error('geoScanner not found', 1)
end

local MAX_RADIUS
if true then
	MAX_RADIUS = scanner.getConfiguration().scanBlocks.maxCostRadius
else
	MAX_RADIUS = scanner.getConfiguration().scanBlocks.maxFreeRadius
end
local NIL_TABLE = {}

local function scan(n)
	if not n then
		n = MAX_RADIUS
	end
	local scaned, err
	term.setTextColor(colors.white)
	while true do
		local cool = scanner.getOperationCooldown('scanBlocks')
		if cool <= 0 then
			break
		end
		term.setCursorPos(1, 1)
		term.clearLine()
		term.write(string.format('Remain: %dms', cool))
		sleep(0)
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

local function getMostValuable(data)
	if data then
		local d, d0
		for _, b0 in pairs(data) do
			local b = dictionary[b0.name]
			if not b then
				for _, t in ipairs(b0.tags) do
					b = dictionary['#'..t]
					if b then
						break
					end
				end
				if not b then
					for _, t in ipairs(b0.tags) do
						b = fallbackDict['#'..t]
						if b then
							break
						end
					end
					if not b then
						b = NIL_TABLE
					end
				end
			end
			if not d or (d.value or 0) < (b.value or 0) or
				 ((d.value or 0) == (b.value or 0) and math.abs(d0.y) > math.abs(b0.y)) then
				d, d0 = b, b0
			end
		end
		return d, d0
	end
	return nil
end

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
		if mapwin.isVisible() then
			mapwin.setVisible(false)
			mapwin.setBackgroundColor(colors.black)
			mapwin.clear()
			for z = -MAX_RADIUS - 1, MAX_RADIUS do
				local py = cy + z
				if 0 < py and py <= height then
					local l = data[z]
					if l then
						for x = -MAX_RADIUS - 1, MAX_RADIUS do
							local px = cx + x
							if 0 < px and px <= width then
								local d, d0 = getMostValuable(l[x])
								mapwin.setCursorPos(px, py)
								if d then
									mapwin.setBackgroundColor(d.color or colors.lightGray)
									mapwin.setTextColor(d.textColor or (d.color == colors.white and colors.black or colors.white))
									mapwin.write((x == 0 and z == 0 and 'X') or d.ch or ' ')
								else
									mapwin.setBackgroundColor(colors.black)
									mapwin.setTextColor(colors.white)
									mapwin.write((x == 0 and z == 0 and (d0 and d0.y <= 0 and 'X' or 'x')) or ' ')
								end
							end
						end
					end
				end
			end
			mapwin.setVisible(true)
			mapwin.redraw()
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
		for i, t in ipairs(anaBlk.tags) do
			if i + anaTdy > 0 then
				anatagwin.setCursorPos(1, i + anaTdy)
				anatagwin.write(string.sub('- '..t, anaTdx))
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
		anawin.setCursorPos(1, 4)
		anawin.write(string.format('Have %d tags', #d0.tags))
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

	parallel.waitForAny(whileScan, pullEvents)
end

main()
