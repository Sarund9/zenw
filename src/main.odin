package main


import lua "vendor:lua/5.4"

import "base:runtime"
import "core:log"
import "core:os"
import "base:builtin"
import str "core:strings"


main :: proc() {
    using lua
    context.logger = log.create_console_logger(
        lowest = .Info,
        opt = log.Options {
            .Level, .Terminal_Color,
        },
    )

    L := L_newstate()
    defer close(L)
    L_openlibs(L)
    init(L)

    // Set odin context
    current_context := context
    {
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)   // {zenw}
        pushlightuserdata(L, &current_context)
        setfield(L, -2, CONTEXT)

        pop(L, 1)
    }
    // Unset context
    defer {
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)   // {zenw}

        pushlightuserdata(L, nil)
        setfield(L, -2, CONTEXT)
        pop(L, 1)
    }

    if !os.exists("zenw.lua") {
        log.error("No workspace file in current directory")
        os.exit(1)
    }

    dofile(L, "zenw.lua")

    // Post build execution
    if builtin.len(os.args) > 1 {
        using lua
        
        pushglobaltable(L) // {g}
        argcount: int
        idx := gettop(L) // top of the stack
        funcname: string

        for arg in os.args[1:] {
            if !str.has_prefix(arg, "-") {
                identifier := str.clone_to_cstring(arg)
                getfield(L, idx, identifier)
                if argcount == 0 do funcname = arg
                argcount += 1
                continue
            }
            // TODO: Args
            /*
            Arg types: bool, number, string, func, table
            `-flag`     flag = true
            `-foo:354`  foo = 354
            `-name:a`   
            `-loglevel:info`
            -- arguments used by all
            Args.flag = false
            Args.foo = 0
            Args.name = ""
            
            function build()

            end


            */
        }

        if argcount > 0 {
            fnt := type(L, idx + 1)
            
            log.info("Running Task:", funcname)
            // dumpstack(L, idx + 1)
            nargs := gettop(L) - (idx + 1)
            res := cast(Status) pcall(L, nargs, 0, 0)

            if res != .OK {
                log.errorf("Task failed to run ({}):", res)
                dumpstack(L, idx + 1)
            }
        }
    }
}

setconsts :: proc "c" (L: State) {
    using lua
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
