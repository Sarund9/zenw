package main


import lua "vendor:lua/5.4"

import "base:runtime"
import "core:log"


REGISTRY_KEY :: "_ZENW"
CONTEXT :: "context"

init :: proc(L: State) {
    using lua
/*
_ZENW = {
    zenw = {

    }
}

*/
    newtable(L)
    defer setfield(L, REGISTRYINDEX, REGISTRY_KEY)
    
    def_std(L)

    // Set globals.zenw to _ZENW.std
    {
        pushglobaltable(L)
        getfield(L, -2, "std")
        setfield(L, -2, "zenw")

        // Custom package searcher
        getfield(L, -1, "package")
        getfield(L, -1, "searchers")
        pushcfunction(L, custom_searcher) // {search} {c()}
        lua.len(L, -2)                    // {search} {c()} int
        l := tointeger(L, -1)             // 
        pop(L, 1)                         // {search} {c()}
        
        seti(L, -2, l + 1)

        pop(L, 3)
    }

    custom_searcher :: proc "c" (L: State) -> i32 {
        using lua
        context = startfunc(L)
        cstr := tostring(L, -1)
        settop(L, 0)

        loader, ok := gZenwModules[cstr]
        if ok {
            pushcfunction(L, loader)
        } else {
            pushnil(L)
        }
        return 1
    }
}

dofile :: proc(L: State, path: cstring) {
    using lua

    s := L_loadfile(L, path)
    if s != .OK {
        log.error("Workspace load failed:", s)
        return
    }

    s = auto_cast pcall(L, 0, 0, 0)
    
    // TODO: Yield handling

    if s != .OK {
        log.error("Workspace call failed:", s)
        dumpstack(L)
        return
    }
    
}

startfunc :: proc "c" (L: State) -> runtime.Context {
    using lua
    getfield(L, REGISTRYINDEX, REGISTRY_KEY)
    getfield(L, -1, CONTEXT)
    ctx_type := type(L, -1)
    if ctx_type != .LIGHTUSERDATA {
        context = runtime.default_context()
        panic("Invalid context")
    }
    
    ptr := touserdata(L, -1)

    if ptr == nil {
        context = runtime.default_context()
        panic("Invalid context")
    }

    // Pop both values from the stack
    pop(L, 2)
    return (cast(^runtime.Context) ptr)^
}

def_std :: proc(L: State) {
    using lua
    newtable(L)
    defer setfield(L, -2, "std")

    // Constants
    {
        // ext_run
        when ODIN_OS == .Windows {
            pushstring(L, ".exe")
        } else when ODIN_OS == .Linux {
            pushstring(L, ".bin")
        } else when ODIN_OS == .Darwin {
            pushstring(L, ".app")
        } else {
            // TODO: Compile error
            pushstring(L, ".??")
        }
        setfield(L, -2, "ext_run")
    
        // ext_lib
        when ODIN_OS == .Windows {
            pushstring(L, ".dll")
        } else when ODIN_OS == .Linux {
            pushstring(L, ".so")
        } else when ODIN_OS == .Darwin {
            pushstring(L, ".so")
        } else {
            // TODO: Compile error
            pushstring(L, ".??")
        }
        setfield(L, -2, "ext_shared")
    }

}

def_classes :: proc(L: State) {
    using lua
    newtable(L)
    defer setfield(L, -2, "class")

    // Classes are declared
    class_track(L)
}
