-- File copier
-- Copy file between disk and computer
-- by zyxkad@gmail.com

local specificDriveName = ''
local drive = #specificDriveName and peripheral.wrap(specificDriveName) or peripheral.find('drive')
assert(peripheral.getType(drive) == 'drive')
local drivePath = drive.getMountPath()
local tmpFileName = 'tmp.file'

function help()
	print('Usage:')
	print(' file_copier help')
	print(' file_copier <local path> <other target path> <options...>')
	print()
	print('Options:')
	print(' tmp: Only copy the file once')
	print(' reboot: Reboot the computer after copied')
	print('   Note: "shell.allow_disk_startup" will set to false on the target computer')
end

function main(args)
	if #args < 2 or args[1] == 'help' then
		help()
		return
	end
	local originPath = args[1]
	local targetPath = fs.combine('/', args[2])
	local flagTmp = false
	local flagReboot = false
	for _, opt in ipairs({table.unpack(args, 3)}) do
		if opt == 'tmp' then
			flagTmp = true
		elseif opt == 'reboot' then
			flagReboot = true
		end
	end
	local startupPath = fs.combine(drivePath, 'startup.lua')
	fs.copy(originPath, fs.combine(drivePath, tmpFileName))
	local fd, err = fs.open(startupPath, 'w')
	if not fd then
		printError(('Could not open file %s: %s'):format(startupPath, err))
		return
	end
	fd.write('-- generate by file_copier.lua\n')
	fd.write('local tmpFileName = fs.combine(fs.getDir(arg[0]),')
	fd.write(textutils.serialise(tmpFileName))
	fd.write(')\n')
	fd.write('local targetPath = ')
	fd.write(textutils.serialise(targetPath))
	fd.write('\n')
	fd.write('fs.copy(tmpFileName, targetPath)\n')
	if flagTmp then
		fd.write("fs.remove('startup.lua')\n")
		fd.write('fs.remove(tmpFileName)\n')
	end
	if flagReboot then
		fd.write("settings.set('shell.allow_disk_startup', false)\n")
		fd.write("settings.save()\n")
		fd.write("os.reboot()\n")
	end
	fd.close()
end

main({...})
