-- Storage monitor
-- by zyxkad@gmail.com

if not parallel then
	error('Need parallel API')
end

local storage = peripheral.find('rsBridge')
if not storage then
	error('RS Storage not found')
end

function main(args)
	local monitor_name = #args >= 1 and args[1] or nil

	local items = {}
	local maxDisk = 0
	local maxExternal = 0
	local maxItem = 0
	local totalItem = 0

	function render(mName)
		local monitor = term
		if mName then
			monitor = peripheral.wrap(mName)
			if not monitor then
				printError('Cannot wrap monitor ' .. mName)
				exit()
				return
			end
			print('Showing storage on monitor', peripheral.getName(monitor))
		end
		monitor.setBackgroundColor(colors.black)
		monitor.clear()
		while true do
			local mWidth, mHeight = monitor.getSize()
			local itemPercent = totalItem / maxItem
			monitor.setTextColor(colors.white)
			monitor.setBackgroundColor(colors.black)
			monitor.setCursorPos(2, 2)
			monitor.clearLine()
			monitor.write(('%d / %d '):format(totalItem, maxItem))
			local x, y = monitor.getCursorPos()
			local barWidth = mWidth - x
			if barWidth < x then
				monitor.setCursorPos(2, 3)
				monitor.clearLine()
				barWidth = mWidth - 2
			end
			local percentText = string.format('%.2f%%', itemPercent * 100)
			local usedWidth = math.floor(barWidth * itemPercent)
			monitor.setTextColor(colors.black)
			monitor.setBackgroundColor(colors.green)
			monitor.write(percentText:sub(1, usedWidth))
			if #percentText < usedWidth then
				monitor.write(string.rep(' ', usedWidth - #percentText))
			end
			monitor.setBackgroundColor(colors.lightGray)
			local unusedWidth = barWidth - usedWidth
			if #percentText > usedWidth then
				unusedWidth = unusedWidth - (#percentText - usedWidth)
				monitor.write(percentText:sub(usedWidth + 1))
			end
			if unusedWidth > 0 then
				monitor.write(string.rep(' ', unusedWidth))
			end
			sleep(0.2)
		end
	end

	function updateData()
		local items0 = storage.listItems()
		maxDisk = storage.getMaxItemDiskStorage()
		maxExternal = storage.getMaxItemExternalStorage()
		maxItem = maxDisk + maxExternal
		local totalItem0 = 0
		for _, item in pairs(items) do
			totalItem0 = totalItem0 + item.amount
		end
		totalItem = totalItem0
		items = items0
	end

	updateData()
	parallel.waitForAny(
		function()
			render(monitor_name)
		end,
		function()
			while true do
				updateData()
				sleep(1)
			end
		end
	)
end

main({...})
