-- Fusion reactor system
-- by zyxkad@gmail.com


---BEGIN default configs---
local mode = 'never' --[[ ENUM:
	never = always run,
	smart = smart mode,
]]
local cellName = 'mekanism' -- the cell's name

local reactors = {
	{
		controller = 'mekanism:',
		heatSource = '',
	}
}

---END default configs---

function main(args)
	--
end

return main({...})
