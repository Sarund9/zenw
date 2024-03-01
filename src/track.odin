package main

/* Lua object to track file changes
Usage:

local shaders = zenw.track('shaders')
shaders.cache = 'shader_cache.cache'

--new: a self-metatable
--evaluates to true if any files were changed
--evaluates to false if any 



class track {
    dir: string
    files: {
        @ = {
            
        }
    }
    
    struct File {
        path: string
        filetime: os.time
        size: u64
        hashcode: u64
    }

    save(self, path) {
        assert(valid(path))

        writer := Writer.to(path)
        for file in files_in(dir) {
            writer.write_strlen(file)
            writer.write_utf8(file)
            writer.write(os.time(file)) // file time the file was writen in
        }
    }

    load(self, path) {

        for file in files_in(dir) {
            files.add {

            }
        }
        
    }

    new(self) {

    }
        
    
}

*/
import lua "vendor:lua/5.4"

import "core:os"
import "core:builtin"
import "core:fmt"
import str "core:strings"
import "core:log"
import "base:runtime"
import path "core:path/filepath"




class_track :: proc "c" (L: State) {
    using lua
    newtable(L)
    defer setfield(L, -2, "Track")
    
}

track_ctor :: proc "c" (L: State) -> i32 {
    using lua

    cstr := L_checkstring(L, 1)
    context = runtime.default_context()

    if !os.exists(auto_cast cstr) || !os.is_dir(auto_cast cstr) {
        pushfstring(L, "Cannot track directory, not found: %s", cstr)
        throw(L)
    }

    // newtable(L)     // {dir} {zenw}
    // insert(L, -2)   // {zenw} {dir}
    // setfield(L, -2) // 

    return 1
}

// iterator of all 'new' (changed) files
track_new :: proc "c" (L: State) -> i32 {
    using lua

    return 0
}

