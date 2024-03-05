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
StateRef :: State
CFunc  :: lua.CFunction

Exp :: lua.L_Reg


// Not defined in "vendor:lua" for some reason
upvalueindex :: proc "c" (index: i32) -> i32 {
    return lua.REGISTRYINDEX - index
}

// Expects at table from the stack, sets a CFunction
defun :: proc "c" (L: State, name: cstring, func: CFunc, upvalues := i32(0)) {
    using lua
    pushcclosure(L, func, upvalues)
    setfield(L, -2, name)
}

throw :: proc { throw_lit, throw_raw }

throw_lit :: proc "c" (L: State, err: cstring) -> ! {
    using lua
    pushliteral(L, err)
    error(L)
    unreachable()
}

throw_raw :: proc "c" (L: State) -> ! {
    using lua
    error(L)
    unreachable()
}

Variant :: union {
    bool,
    int, f64,
    cstring,

}

var_getfield :: proc(L: State, idx: i32, key: cstring) -> Variant {
    using lua
    t := cast(Type) getfield(L, idx, key)

    defer pop(L, 1)

    switch t {
    case .NIL: return nil
    case .BOOLEAN: return cast(bool) toboolean(L, -1)
    case .NUMBER:
        if isinteger(L, -1) {
            return cast(int) tointeger(L, -1)
        } else {
            return cast(f64) tonumber(L, -1)
        }
    case .STRING: return tostring(L, -1)
    case .THREAD, .FUNCTION, .LIGHTUSERDATA, .NONE, .TABLE, .USERDATA:
        log.panic("Unsupported type:", type)
    }

    defer panic("Unreachable")
    return nil
}

var_assert_native :: proc(var: Variant, $T: typeid, loc := #caller_location) -> T {
    value, ok := var.(T)
    assert(ok, "Could not cast variant to " + T, loc)
    return value
}

var_assert :: proc(L: State, var: Variant, $T: typeid, errmsg: cstring) -> T {
    value, ok := var.(T)
    if !ok {
        lua.throw(L, errmsg)
    }
    return value
}

subtable :: proc(L: State, idx: i32, name: cstring) -> bool {
    using lua
    t := cast(Type) getfield(L, idx, name)
    if t == .NIL {
        pop(L, 1)
        return false
    }
    return true
}
