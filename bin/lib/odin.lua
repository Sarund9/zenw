

print 'Loading zenw odin module'

local os = os

local _ENV = {}

function build(dir, args)
    local cmd = 'odin build ' .. dir
    cmd = cmd .. ' '

    os.execute(cmd)
end




return _ENV