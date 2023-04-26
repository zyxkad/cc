
local htcc = require("htcc")

print('example.lua invoked')

local exports = {}

function exports.onload(event)
	print('onload:', event)
end

function exports.onclick(event)
	print('onclick:', event)
end

return exports
