-- Botania Runic Altar Autocrafting (Bottom part)
-- by zyxkad@gmail.com

while true do
	if redstone.getInput('top') then
		turtle.place() -- use the wand
		redstone.setOutput('top', true)
		repeat sleep(0.1) until not redstone.getInput('top')
		redstone.setOutput('top', false)
	else
		sleep(0.2)
	end
end
