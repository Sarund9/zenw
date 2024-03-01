

local odin = require 'odin'

-- print 'LUA: Workspace'

for key, value in pairs(odin) do
    print("[" .. key .. "] = " .. tostring(value))
end


function build()
    print "Build!"
    odin.build {
        dir = 'src',
        out = 'test',
        mode = 'exe'
    }
end

