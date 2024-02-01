package main


import lua "vendor:lua/5.4"

import "core:os"
import "core:builtin"
import "core:fmt"
import str "core:strings"
import "core:log"
import "core:runtime"
import path "core:path/filepath"


State :: ^lua.State
Func  :: lua.CFunction

/*
Key in the registry to the ZENW table 
Members {
    / pointer to odin context, set before calling lua
    context = *
    / metatable to the global table
    STD = {

    }
}
*/
REGISTRY_KEY :: "ZENW"


init :: proc(L: State) {
    using lua

    settop(L, 0)
    { // Create registry table and push it to the stack
        newtable(L)
        setfield(L, REGISTRYINDEX, REGISTRY_KEY)
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)
    }

    // Sets ZENW["context"] to null
    pushlightuserdata(L, nil)
    setfield(L, -2, "context")

    setf :: proc(L: State, name: cstring, func: Func) {
        using lua
        pushcfunction(L, func)
        setfield(L, -2, name)
    }

    newtable(L)
    setfield(L, -2, "STD")
    getfield(L, -1, "STD") // {zenw} {std}

    setf(L, "include", l_include)

    pushglobaltable(L) // {zenw} {std} {glob}
    insert(L, 2)       // {zenw} {std} {glob}
    setmetatable(L, -2)


    // dumplua(L)
}

dofile :: proc(L: State, path: cstring) {
    using lua

    s := L_loadfile(L, path)
    if s != .OK {
        log.error("Workspace load failed:", s)
        return
    }

    // Set odin context
    current_context := context
    {
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)   // {zenw}
        pushlightuserdata(L, &current_context)
        setfield(L, -2, "context")

        pop(L, 1)
    }

    s = auto_cast pcall(L, 0, 0, 0)
    
    // TODO: Yield handling

    // Unset context
    {
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)   // {zenw}

        pushlightuserdata(L, nil)
        setfield(L, -2, "context")
    }

    if s != .OK {
        log.error("Workspace call failed:", s)
        return
    }

}


dumplua :: proc(L: ^lua.State) {
    using lua
    log.info("Lua stack [")
    top := gettop(L)
    for i in 1..=top {
        pushinteger(L, auto_cast i)
        pushvalue(L, i)
        outpair(L, 1)
        fmt.println()
        lua.pop(L, 2)
    }
    fmt.println("]")

    log.info("Dumping lua registry...")
    fmt.print("REGISTRY = ")
    dumptable(L, REGISTRYINDEX, 0)
    fmt.println()

    printindent :: proc(indent: int) {
        // str := fmt.tprint(indent)
        // fmt.print(str)
        for i in 0..<indent {
            fmt.print("  ")
        }
    }

    outpair :: proc(L: ^lua.State, indent: int) {
        using lua
        key: any
        #partial switch type(L, -2) {
        case .NUMBER:
            if isinteger(L, -2) {
                key = tointeger(L, -2)
            } else {
                key = tonumber(L, -2)
            }
        case .STRING:
            key = tostring(L, -2)
        }
        assert(key != nil, "Failed to print registry")

        valtype := type(L, -1)
        printindent(indent)
        fmt.printf("{} = ", key)
        #partial switch valtype {
        case .NONE: fmt.print("none")
        case .BOOLEAN: fmt.print(toboolean(L, -1))
        case .NUMBER: fmt.print(tonumber(L, -1))
        case .STRING: fmt.print(tostring(L, -1))
        case .NIL: fmt.print("nil")
        case .TABLE: dumptable(L, -1, indent)
        case: fmt.print(topointer(L, -1))
        }

    }

    dumptable :: proc(L: ^lua.State, index: i32, indent: int) {
        using lua
        
        pushvalue(L, index)
        pushnil(L)
        fmt.print("{")
        nonempty: bool
        for next(L, -2) != 0 {
            fmt.println()
            outpair(L, indent + 1)
            lua.pop(L, 1)
            nonempty = true
        }
        
        if nonempty {
            fmt.println()
            printindent(indent)
        }

        fmt.print("}")
        lua.pop(L, 1)
    }
}


l_include :: proc "c" (L: ^lua.State) -> i32 {


    return 0
}



