package main


import lua "vendor:lua/5.4"
import "core:fmt"


dumpstack :: proc(L: ^lua.State, from: i32 = 1) {
    using lua
    watchdog := 1000
    top := gettop(L)
    for i in from..=top {
        pushinteger(L, auto_cast i)
        pushvalue(L, i)
        dumppair(L, 1, &watchdog)
        fmt.println()
        lua.pop(L, 2)
    }
}

dumpregistry :: proc(L: ^lua.State) {
    using lua
    watchdog := 1000
    dumptable(L, REGISTRYINDEX, 0, &watchdog)
    fmt.println()
}

dumpglobals :: proc(L: ^lua.State) {
    using lua

    watchdog := 1000
    pushglobaltable(L)
    defer pop(L, 1)
    dumptable(L, -1, 0, &watchdog)
    fmt.println()
}

printindent :: proc(indent: int) {
    // str := fmt.tprint(indent)
    // fmt.print(str)
    for i in 0..<indent {
        fmt.print("  ")
    }
}

/* Expected Stack (... key value)
*/
dumppair :: proc(L: ^lua.State, indent: int, watchdog: ^int) {
    watchdog^ -= 1
    assert(watchdog^ > 0, "Dumppair stack exception")
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
    case .TABLE:
        if indent >= 5 {
            fmt.print("{ ... }")
        } else {
            dumptable(L, -1, indent, watchdog)
        }
    case: fmt.printf("{} ({})", topointer(L, -1), type(L, -1))
    }

}

dumptable_top :: proc(L: ^lua.State) {
    using lua
    watchdog := 1000
    dumptable(L, -1, 0, &watchdog)
    fmt.println()
}

dumptable :: proc(L: ^lua.State, index: i32, indent: int, watchdog: ^int) {
    using lua
    watchdog^ -= 1
    assert(watchdog^ > 0, "Dumppair stack exception")

    pushvalue(L, index)
    pushnil(L)
    fmt.print("{")

    nonempty: bool
    // Dump meta table
    if getmetatable(L, -2) > 0 {
        fmt.println()
        printindent(indent + 1)
        fmt.print("@ = { ... }")
        pop(L, 1)
        nonempty = true
    }

    for next(L, -2) != 0 {
        nonempty = true
        fmt.println()
        defer lua.pop(L, 1)
        
        // Skip _G
        if type(L, -2) == Type.STRING && tostring(L, -2) == "_G" {
            printindent(indent + 1)
            fmt.print("_G = { ... }")
            // panic("GLOBAL")
            continue
        }

        dumppair(L, indent + 1, watchdog)
    }
    
    if nonempty {
        fmt.println()
        printindent(indent)
    }

    fmt.print("}")
    lua.pop(L, 1)
}

