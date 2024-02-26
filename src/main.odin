package main


import lua "vendor:lua/5.4"

import "core:os"
import str "core:strings"
import "core:log"
import "core:runtime"




Args :: struct {
    task: [dynamic]string,
}

main :: proc() {
    context.logger = log.create_console_logger(
        lowest = .Info,
        opt = log.Options {
            .Level, .Terminal_Color,
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

    sfile: cstring = "zenw.lua"

    if !os.exists(auto_cast sfile) {
        log.error("No workspace at current location:", sfile)
        return
    }


    // Container :: struct {
    //     table: map[string]string,
    // }

    // list: [dynamic]Container

    // list = make([dynamic]Container, 0, 16)

    // append(&list, Container {
    //     table = make(map[string]string),
    // })

    // list[0].table["foo"] = "value"

    // log.info(list)

    // check(list[0].table, "foo")

    init_workspace()
    defer deinit_workspace()

    dofile(L, sfile)
    
    // export_script("zenw_test")
    // test()

    // log.info("Exportables:", appState.loadstack[0].exports)

    // check(appState.loadstack[0].exports, "zenw_test")

}

