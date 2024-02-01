package main


import lua "vendor:lua/5.4"

import "core:os"
import str "core:strings"
import "core:log"
import "core:runtime"
import path "core:path/filepath"


Args :: struct {
    task: [dynamic]string,
}

main :: proc() {
    context.logger = log.create_console_logger(
        lowest = .Info,
        opt = log.Options {
            .Level,
        },
    )
    
    run: Args
    for arg in os.args[1:] {
        if arg[0] != '-' {
            append(&run.task, arg)
            continue
        }

        // TODO: Defer logging (flags may set logger settings)
        log.error("Unknown flag:", arg)
    }

    L := lua.L_newstate()
    defer lua.close(L)

    init(L)

    workDir := os.args[0]

    sfile: cstring = "zenw.lua"

    if !os.exists(auto_cast sfile) {
        log.error("No workspace at current location:", sfile)
        return
    }

    log.info("Run file:", sfile)
    dofile(L, sfile)
}

