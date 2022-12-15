-- More turtle actions -- roller
-- by zyxkad@gmail.com

local chatbox = peripheral.find('chatBox')
if not chatbox then
	error('No chat box was found')
end

local function startswith(s, prefix)
	return string.find(s, prefix, 1, true) == 1
end

local function sendErrorMsg(msg, player)
	return chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
		text = 'ERROR: ',
		color = 'red',
		extra = {
			{
				text = msg,
				underlined = true,
			}
		}
	}), player)
end

local function cmd_echo(player, msg)
	if #msg == 0 then
		chatbox.sendFormattedMessage(textutils.serialiseJSON({
			text = 'HELLO ',
			bold = true,
			color = 'gold',
			clickEvent = {
				action = 'suggest_command',
				value = 'echo ',
			},
			extra = {
				{
					text = player,
					italic = true,
					underlined = true,
					color = 'aqua',
					clickEvent = {
						action = 'suggest_command',
						value = player,
					},
					hoverEvent = {
						action = 'show_text',
						value = player,
					},
				}
			}
		}))
		return
	end
	chatbox.sendFormattedMessage(textutils.serialiseJSON({
		text = 'ECHO: ',
		bold = true,
		color = 'green',
		extra = {
			{
				text = msg,
				color = 'blue',
				clickEvent = {
					action = 'suggest_command',
					value = msg,
				}
			}
		}
	}))
end

local function cmd_random(player, msg)
	chatbox.sendFormattedMessage(textutils.serialiseJSON({
		text = 'Oops: ',
		bold = true,
		color = 'green',
		clickEvent = {
			action = 'suggest_command',
			value = '@random ',
		},
		extra = {
			{
				text = msg,
				obfuscated = true,
				strikethrough = true,
				color = 'red',
				clickEvent = {
					action = 'suggest_command',
					value = msg,
				},
				hoverEvent = {
					action = 'show_text',
					value = msg,
				},
			}
		}
	}))
end

local function cmd_mail(player, msg)
	local i = msg:find(' ', 1)
	if not i then
		sendErrorMsg('Missing mail body', player)
		return
	end
	local target = msg:sub(1, i - 1)
	local remsg = msg:sub(i + 1)
	if #remsg < 3 then
		sendErrorMsg('Mail body cannot less than 3 bytes', player)
		return
	end
	chatbox.sendMessageToPlayer('TODO', player)
end

local noticing = nil

local function cmd_notice(player, msg)
	local i = msg:find(' ', 1)
	if not i then
		sendErrorMsg('Missing message body', player)
		return
	end
	local target = msg:sub(1, i - 1)
	local remsg = msg:sub(i + 1)
	if #remsg < 3 then
		sendErrorMsg('Message body cannot less than 3 bytes', player)
		return
	end
	if noticing then
		sendErrorMsg('There is already a notice in progress', player)
		return
	end
	noticing = {
		src = player,
		tg = target,
		msg = remsg,
	}
end

local function cmd_gotit(player, msg)
	if #msg == 0 then
		sendErrorMsg('You must type source player name of the notice', player)
		return
	end
	if not noticing then
		sendErrorMsg('There is none notice in progress', player)
		return
	end
	if noticing.tg ~= player then
		sendErrorMsg('There is none notice in progress', player)
		return
	end
	if noticing.src ~= msg then
		sendErrorMsg(string.format("This notice is not from '%s', it's from '%s'", msg, noticing.src), player)
		return
	end
	chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
		text = 'You got the notice',
		bold = true,
		color = 'green',
	}), player)
	noticing = nil
end

local subCommands = {
	echo = cmd_echo,
	['@random'] = cmd_random,
	['@mail'] = cmd_mail,
	['@notice'] = cmd_notice,
	['@gotit'] = cmd_gotit,
}

local timerid = os.startTimer(5)
while true do
	local eargs = table.pack(os.pullEvent())
	local event = eargs[1]
	if event == 'timer' then
		if eargs[2] == timerid then
			if noticing then
				local ok = chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON({
					text = 'NOTICE FROM ',
					bold = true,
					color = 'green',
					extra = {
						{
							text = '<'..noticing.src..'> ',
							italic = true,
							underlined = true,
							color = 'aqua',
							clickEvent = {
								action = 'suggest_command',
								value = '@gotit '..noticing.src,
							},
							hoverEvent = {
								action = 'show_text',
								value = 'Click to disable this notick from '..noticing.src,
							},
						},
						{
							text = noticing.msg,
							color = 'gold',
						},
						{
							text = string.format('\nClick or type `@gotit %s` to diable this message', noticing.src),
							color = 'gray',
							underlined = true,
							bold = false,
							clickEvent = {
								action = 'suggest_command',
								value = '@gotit '..noticing.src,
							},
							hoverEvent = {
								action = 'show_text',
								value = 'Click to disable this notick from '..noticing.src,
							},
						}
					}
				}), noticing.tg)
			end
			timerid = os.startTimer(5)
		end
	elseif event == 'chat' then
		local player, msg, _ = table.unpack(eargs, 2)
		local cmd = subCommands[msg]
		if cmd then
			cmd(player, '')
		else
			for k, cmd in pairs(subCommands) do
				if startswith(msg:lower(), k..' ') then
					cmd(player, msg:sub(#k + 2))
					break
				end
			end
		end
	end
end
