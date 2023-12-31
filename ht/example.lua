
local htcc = require("htcc")

print('example.lua invoked')

local exports = {}

function exports.onload(event)
	print('onload:', event)
end

function exports.onclick(event)
	print('onclick:', event)
end

function exports.onInputChanged(event)
	print('onInputChanged:', event)
end

function exports.onSaveInput(event)
	print('onSaveInput:', event)
end

return exports
