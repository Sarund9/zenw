package main


import lua "vendor:lua/5.4"

import "core:os"
import str "core:strings"
import "core:log"
import "base:runtime"
import path "core:path/filepath"


appState: struct {
    // Memory arena
    arena: runtime.Arena,

    // Root directory to launch the program from
    loadstack: [dynamic]Script,
}

Script :: struct {
    fullpath: string,
    exports: map[string]string,
}


test :: proc() {
    using appState
    // s: Script
    // s.exports = make(map[string]string)
    // s.exports["foo"] = "path/name"
    export_script("foo")

    s := loadstack[0]
    log.info(loadstack)
    check(s.exports, "foo")

}


init_workspace :: proc() {
/*

Program launch..
Current dir is checked as a valid Workspace:
    Must have a valid zenw.lua file
    If not present, exit 1

Workspace data structure is created

Subdirectories are checked for extra zenw.lua files

First file is added to the loadstack

*/
    using appState

    context.allocator = runtime.arena_allocator(&arena)

    current_dir := os.get_current_directory(context.temp_allocator)

    root_file_path := path.join({ current_dir, "zenw.lua" })
    
    loadstack = make([dynamic]Script)

    append(&loadstack, Script {
        fullpath = root_file_path,
        exports = make(map[string]string),
    })
    // loadstack[0].exports.allocator = context.allocator

    log.info(loadstack[0])
}

deinit_workspace :: proc() {
    using appState

    for s in loadstack {
        // TODO: Delete
    }
    delete(loadstack)

    runtime.arena_free_all(&arena)
}

push_workspace :: proc(fullpath: string) {
    using appState
    context.allocator = runtime.arena_allocator(&arena)

    append(&loadstack, Script {
        fullpath = fullpath,
        exports = make(map[string]string),
    })
}

pop_workspace :: proc() {
    using appState
    context.allocator = runtime.arena_allocator(&arena)

    pop(&loadstack)
}

/**/
export_script :: proc(name: string) -> bool {
    using appState
    context.allocator = runtime.arena_allocator(&arena)
    
    // key := str.clone(name)
    // script := loadstack[len(loadstack) - 1]
    // log.info("LEN:", len(loadstack))
    // script.exports[key] = "path/name"
    // return true
    join :: path.join
    concat :: str.concatenate
    dir :: path.dir

    script := &loadstack[len(loadstack) - 1]
    dirpath := dir(script.fullpath, context.temp_allocator)
    lit := join({ dirpath, name }, context.temp_allocator)
    fpath := concat({ lit, ".lua" }, context.temp_allocator)

    if os.exists(fpath) {
        key := str.clone(name)
        // TODO: Key names
        
        log.info("Set", key, "==", fpath)
        script.exports[key] = fpath

        return true
    }
    
    log.error("File not found", fpath)
    log.error(loadstack[0].fullpath)

    return false
}

/**/
import_script :: proc(name: string) -> Maybe(string) {
    using appState
    
    for i := len(loadstack)-1; i >= 0; i -= 1 {
        script := &loadstack[i]
        
        filepath, ok := script.exports[name]
        if ok {
            return filepath
        }
    }
    
    return nil
}


check :: proc(table: map[string]string, key: string) {
    value, ok := table[key]
    if ok {
        log.warn("Key found")
    } else {
        for k, v in table {
            if k == key {
                log.warn("What the actual fuck???")
            }
        }
        log.warn("Did not find:", key, "->", value)
    }
}
