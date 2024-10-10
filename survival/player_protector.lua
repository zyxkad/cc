-- Player Protector
-- by zyxkad@gmail.com

local detector = assert(peripheral.find("playerDetector"))
local chatbox = assert(peripheral.find("chatBox"))

local baseName = "Auto Base"
local whitelist = {
	'ckupen',
}

local players = {}
local strangers = {}
local hasStranger = false

local function update()
	while true do
		players = detector.getPlayersInRange(100)
		strangers = {}
		hasStranger = false
		for _, p in pairs(players) do
			local flag = true
			for _, e in pairs(whitelist) do
				if p:lower() == e:lower() then
					flag = false
					break
				end
			end
			if flag then
				strangers[p] = 1
				hasStranger = true
			end
		end
		sleep(1)
	end
end

local function check()
	while true do
		if hasStranger then
			local str = textutils.serialiseJSON(strangers)
			local fd = fs.open(os.date('logs/%Y-%m-%d-%X.json'), 'w')
			fd.write(str)
			fd.close()
			local plCs = {}
			for p, _ in pairs(strangers) do
				if #plCs ~= 0 then
					plCs[#plCs + 1] = {
						text = ', ',
						color = 'green',
					}
				end
				plCs[#plCs + 1] = {
					text = p,
					bold = true,
					italic = true,
					underlined = true,
					color = 'green',
				}
			end
			local texts = {
				{
					text = '~~~',
					obfuscated = true,
					strikethrough = true,
				},
				{
					text = ' ',
				},
				{
					text = 'Unexpect players are visiting!',
					bold = true,
					underlined = true,
				},
				{
					text = ' The nearby players are ',
				},
				table.unpack(plCs)
			}
			texts[#texts + 1] = {
				text = ' ',
			}
			texts[#texts + 1] = {
				text = '~~~',
				obfuscated = true,
				strikethrough = true,
			}
			chatbox.sendFormattedMessage(textutils.serialiseJSON({
				text = '',
				color = 'red',
				extra = texts
			}), baseName, '##')
			sleep(59.9)
		end
		sleep(0.1)
	end
end

local function showMonitor(mName)
	local monitor
	if mName then
		monitor = peripheral.wrap(mName)
		if not monitor then
			printError('Cannot wrap monitor ' .. mName)
			return
		end
	else
		monitor = peripheral.find("monitor")
	end
	if monitor then
		print('Showing players on monitor', peripheral.getName(monitor))
	else
		print('Cannot find monitor, showing on current term')
		monitor = term
	end

	monitor.clear()
	while true do
		for i, p in ipairs(players) do
			local d = detector.getPlayerPos(p)
			monitor.setCursorPos(1, i)
			monitor.clearLine()
			if d and d.x then
				if strangers[p] then
					monitor.setTextColor(colors.orange)
				else
					monitor.setTextColor(colors.white)
				end
				monitor.write(string.format('%16s | %5d %3d %5d', p, d.x, d.y, d.z))
			end
		end
		monitor.setCursorPos(1, #players + 1)
		monitor.clearLine()
		sleep(0.1)
	end
end

local function main(args)
	parallel.waitForAny(
		update,
		check,
		function() showMonitor(args[1]) end
	)
end

main({...})
