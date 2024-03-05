

local odin = require 'odin'
local track = require 'filetrack'

-- print 'LUA: Workspace'

for key, value in pairs(odin) do
    print("[" .. key .. "] = " .. tostring(value))
end


function build()
    local files = track('src/*.odin', 'test.cache')
    local a = files.any

    print "Build!"
    odin.build {
        dir = 'src',
        out = 'test',
        mode = 'exe'
    }


end

function build_shaders()

end
