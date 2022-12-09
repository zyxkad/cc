-- Sync API
-- Terminal-Monitor Synchronization
-- by MysticT
-- original source at <https://pastebin.com/KhyGwUPm>
-- improve by zyxkad@gmail.com

-- Usage: syncw = require("syncw")

local tApi = {}
local tTargets = {}
local tMonitors = {}

local bMax = false
local nWidth, nHeight = 0, 0
local nCursorX, nCursorY = 1, 1
local bBlink = false
local bgColor = colors.black
local txtColor = colors.white

local function resize()
	local w, h
	for target in pairs(tTargets) do
		local _w, _h = target.getSize()
		if bMax then
			if not(w and h) or (_w * _h) > (w * h) then
				w, h = _w, _h
			end
		else
			if not(w and h) or (_w * _h) < (w * h) then
				w, h = _w, _h
			end
		end
	end
	if w and h then
		nWidth = w
		nHeight = h
	end
end

local function call(func, ...)
	for target in pairs(tTargets) do
		x = target[func]
		if x then
			x(...)
		end
	end
end

-- Sync Functions

function tApi.getSize()
	return nWidth, nHeight
end

function tApi.getCursorPos()
	return nCursorX, nCursorY
end

function tApi.getTextColor()
	return txtColor
end
tApi.getTextColour = tApi.getTextColor

function tApi.getBackgroundColor()
	return bgColor
end
tApi.getBackgroundColour = tApi.getBackgroundColor

function tApi.setCursorPos(x, y)
	nCursorX, nCursorY = x, y
	call("setCursorPos", x, y)
end

function tApi.setCursorBlink(b)
	bBlink = b
	call("setCursorBlink", b)
end

function tApi.clear()
	call("clear")
end

function tApi.clearLine()
	call("clearLine")
end

function tApi.write(text)
	call("write", text)
	nCursorX = nCursorX + string.len(text)
end

function tApi.scroll(n)
	call("scroll", n)
end

function tApi.isColor()
	for target in pairs(tTargets) do
		if not target.isColor() then
			return false
		end
	end
	return true
end
tApi.isColour = tApi.isColor

function tApi.setBackgroundColor(c)
	bgColor = c
	call("setBackgroundColor", c)
end
tApi.setBackgroundColour = tApi.setBackgroundColor

function tApi.setTextColor(c)
	txtColor = c
	call("setTextColor", c)
end
tApi.setTextColour = tApi.setTextColor

-- API Functions

local function addTarget(target)
	tTargets[target] = true
	resize()
	target.setCursorPos(nCursorX, nCursorY)
	target.setCursorBlink(bBlink)
	target.setBackgroundColor(bgColor)
	target.setTextColor(txtColor)
end

local function removeTarget(target)
	tTargets[target] = nil
end

local function addMonitor(sSide)
	if tMonitors[sSide] then
		return true
	end
	if peripheral.isPresent(sSide) and peripheral.getType(sSide) == "monitor" then
		local mon = peripheral.wrap(sSide)
		tMonitors[sSide] = mon
		addTarget(mon)
		return true
	end
	return false
end

local function removeMonitor(sSide)
	if tMonitors[sSide] then
		removeTarget(tMonitors[sSide])
		tMonitors[sSide] = nil
	end
end

local function addMonitors()
	for _, s in ipairs(rs.getSides()) do
		addMonitor(s)
	end
end

local function removeAllMonitors()
	for s, m in pairs(tMonitors) do
		removeTarget(m)
		tMonitors[s] = nil
	end
end

local function useMaxSize(b)
	if b ~= bMax then
		bMax = b
		resize()
	end
end

local function redirect(bAddTerm)
	if bAddTerm then
		addTarget(term)
	end
	term.redirect(tApi)
end

local function restore()
	term.restore()
end

return {
	addTarget = addTarget,
	removeTarget = removeTarget,
	addMonitor = addMonitor,
	removeMonitor = removeMonitor,
	addMonitors = addMonitors,
	removeAllMonitors = removeAllMonitors,
	useMaxSize = useMaxSize,
	redirect = redirect,
	restore = restore,
}
