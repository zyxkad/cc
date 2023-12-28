-- CC Storage - Tank
-- Fluid storage
-- by zyxkad@gmail.com

local REDNET_PROTOCOL = 'storage'
local HOSTNAME = string.format('tank-controller-%d', os.getComputerID())

local crx = require('coroutinex')
local co_run = crx.run
local await = crx.await
local co_main = crx.main

local modem = peripheral.find('modem', function(_, modem) return peripheral.hasType(modem, 'peripheral_hub') end)
local modemName = modem.getNameLocal()


