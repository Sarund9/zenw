
local install_dir = arg[1]
local current_dir = arg[2]

-- TODO: zenw package

-- Run preload script
local preload_path = install_dir .. "/preload.lua"
local preload, err = loadfile(preload_path)
if preload ~= nil then
    preload()
end

-- Setup package path to have lib
local lib = ';' .. install_dir .. '/lib/?'
package.path = package.path .. lib .. lib .. ".lua"

-- Run workspace script
local workspace_path = current_dir .. "/zenw.lua"
local script, err = loadfile(workspace_path)
if script == nil then
    error("ZENW: " .. err)
    return
end
script() -- Run the current workspace



--Post run
if arg[3] == nil then
    return
end

local post = "" .. arg[3]
local elem_index = 4
while true do
    local elem = arg[elem_index]
    
    if elem == nil then
        break
    end

    print("Element: " .. elem)
    elem_index = elem_index + 1
end

print("Post Call:", post)
