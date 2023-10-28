-- Security Station Hack protecter
-- by zyxkad@gmail.com

local stationName = 'CK Station'
local stationSide = 'top'

local chatbox = assert(peripheral.find('chatBox'))
local detector = assert(peripheral.find('playerDetector'))

local oldHacked = false

local function check()
	local hacked = redstone.getInput(stationSide)
	if hacked and not oldHacked then
		local players = detector.getPlayersInRange(30)
		local str = textutils.serialiseJSON(players)
		local fd = fs.open(os.date('logs/%Y-%m-%d-%X.json'), 'w')
		fd.write(str)
		fd.close()
		local plCs = {}
		for _, p in ipairs(players) do
			print(p, #plCs + 1)
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
				text = '!!!',
				obfuscated = true,
				strikethrough = true,
			},
			{
				text = ' Station is ',
			},
			{
				text = 'HACKED',
				bold = true,
				underlined = true,
			},
			{
				text = '. The nearby players are ',
			},
			table.unpack(plCs)
		}
		texts[#texts + 1] = {
			text = ' ',
		}
		texts[#texts + 1] = {
			text = '!!!',
			obfuscated = true,
			strikethrough = true,
		}
		chatbox.sendFormattedMessage(textutils.serialiseJSON({
			text = '',
			color = 'red',
			extra = texts
		}), stationName, '##')
	end
	oldHacked = hacked
end

function main()
	while true do
		check()
		sleep(0.1)
	end
end

main()
