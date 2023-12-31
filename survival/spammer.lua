-- spam when player is online
-- by zyxkad@gmail.com

local detector = assert(peripheral.find('playerDetector'))
local chatbox = assert(peripheral.find('chatBox'))

local banned = {
	['raviolipals74'] = true,
}

local fd = fs.open('banned.dat', 'r')
if fd then
	banned = textutils.unserialise(fd.readAll())
	fd.close()
end

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function spam()
	while true do
		local players = detector.getOnlinePlayers()
		for _, p in pairs(players) do
			if banned[p:lower()] then
				chatbox.sendMessage('Banned player '..p..' is online, kick him!', 'Server')
				sleep(1.05)
			end
		end
		sleep(0)
	end
end

local function command()
	while true do
		local _, p, msg = os.pullEvent('chat')
		if p == 'ckupen' then
			if startswith(msg, '.ban ') then
				local t = msg:sub(#'.ban '):lower()
				banned[t] = true
				local fd = fs.open('banned.dat', 'w')
				fd.write(textutils.serialise(banned))
				fd.close()
			elseif startswith(msg, '.unban ') then
				local t = msg:sub(#'.unban '):lower()
				banned[t] = nil
				local fd = fs.open('banned.dat', 'w')
				fd.write(textutils.serialise(banned))
				fd.close()
			elseif startswith(msg, '.listban') then
				local text = ''
				for t, _ in pairs(banned) do
					if #text > 0 then
						text = text..'\n- '
					end
					text = text..t
				end
				chatbox.sendMessageToPlayer(text, p)
			end
		end
	end
end

parallel.waitForAny(
	spam,
	command
)
