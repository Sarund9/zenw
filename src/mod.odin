package main

import lua "vendor:lua/5.4"

import "base:runtime"
import "core:log"
import "core:os"
import "core:fmt"
import "core:c/libc"
import str "core:strings"
import fpath "core:path/filepath"
import "core:text/match"
import "core:time"

gZenwModules := map[cstring]CFunc {
    "odin" = odin_load,
    "filetrack" = filetrack_load,
}

odin_load :: proc "c" (L: State) -> i32 {
    lua.newtable(L)

    begin :: proc() -> str.Builder {
        b := str.builder_make()
        str.write_string(&b, "odin")
        return b
    }
    
    execute :: proc(b: ^str.Builder) -> i32 {
        str.write_rune(b, '\x00')
        cstr_cmd := str.unsafe_string_to_cstring(str.to_string(b^))
        log.info("Running:", cstr_cmd)
        code := libc.system(cstr_cmd)
        str.builder_destroy(b)
        
        return code
    }

    /*
    Arguments:

    dir: required string
    out: required string
    mode: optional string
    
    Errors:

    zenw odin.build: missing argument 'dir'

    OLD lua code:

    if args.out then
        cmd = cmd .. ' -out:' .. args.out
    else
        error 'Missing argument 'out''
    end

    if args.mode then
        local code = buildModes[args.mode]
        if code == nil then
            error('odin: Invalid build mode: ' .. args.mode)
        end
        if code == 1 then
            cmd = cmd .. zenw.ext_run .. " -build-mode:exe"
        elseif code == 2 then
            cmd = cmd .. zenw.ext_shared .. " -build-mode:dll"
        end
    else
        cmd = cmd .. zenw.ext_run
    end
    */
    defun(L, "build", proc "c" (L: State) -> i32 {
        using lua
        
        L_checktype(L, 1, auto_cast Type.TABLE)
        context = startfunc(L)

        cmd := begin()
        str.write_string(&cmd, " build")

        // dir
        dir: cstring; {
            t := cast(Type) getfield(L, -1, "dir")
            if t == .NIL {
                throw(L, "Missing build argument: dir")
            }
            if t != .STRING {
                throw(L, "Build argument 'dir' must be a string")
            }

            dir := tostring(L, -1); pop(L, 1)
            if !os.is_dir(auto_cast dir) {
                log.error("Cannot find:", dir)
                throw(L, "Build argument 'dir' must be a valid directory")
            }

            str.write_rune(&cmd, ' ')
            str.write_string(&cmd, auto_cast dir)
        }
        
        // out
        out: cstring; {
            t := cast(Type) getfield(L, -1, "out")
            if t == .NIL {
                throw(L, "Missing build argument: out")
            }
            if t != .STRING {
                throw(L, "Build argument 'out' must be a string")
            }

            out := tostring(L, -1); pop(L, 1)

            if !os.is_dir(fpath.dir(auto_cast out, context.temp_allocator)) {
                pushfstring(L, "Can't output to %s, no valid directory")
                throw(L)
            }
            
            str.write_string(&cmd, " -out:")
            str.write_string(&cmd, auto_cast out)
        }

        // mode
        mode: enum {
            Executable, Shared,
        }
        for {
            t := cast(Type) getfield(L, -1, "mode")
            if t == .NIL {
                mode = .Executable
                pop(L, 1)
                break
            }
            if t != .STRING {
                throw(L, "Build argument 'mode' must be a string")
            }
            val := tostring(L, -1); pop(L, 1)
            switch val {
            case "exe": mode = .Executable
            case "dll": mode = .Shared
            case:
                pushfstring(L, "Invalid build mode: %s", val)
                throw(L)
            }

            break
        }

        switch mode {
        case .Executable:
            str.write_string(&cmd, EXT_RUN)
        case .Shared:
            str.write_string(&cmd, EXT_SHARED)
        }


        // log.warn(str.to_string(cmd))
        // str.builder_destroy(&cmd)
        exitcode := execute(&cmd)

        return 0
    })

    return 1
}

filetrack_load :: proc "c" (L: State) -> i32 {
    
    Tracker :: struct {
        pattern, cachefile: string,
        matcher: match.Matcher,
        files: [dynamic]File,
    }

    File :: struct {
        fullpath: string,
        filetime, size,
        hashcode: u64,
    }

    using lua
    context = startfunc(L)

    // Registry
    newtable(L) // track
    
    // Metatable
    {
        newtable(L) 
        defer setmetatable(L, -2)

        // Constructor
        defun(L, "__call", proc "c" (L: StateRef) -> i32 {
            using lua
            context = startfunc(L)

            pattern := L_checkstring(L, 2)
            file := L_checkstring(L, 3)

            // Validate cache filepath
            fullpath, ok := fpath.abs(auto_cast file, context.allocator)
            if !ok {
                pushfstring(L, "filetrack: invalid cache path: %s", file)
                throw(L)
            }
            
            log.warn("filetrack to", fullpath)

            // Return userdata
            data := newuserdatauv(L, size_of(Tracker), 0)
            getfield(L, 1, "Tracker")
            setmetatable(L, -2)

            t := transmute(^Tracker) data
            t.cachefile = fullpath
            {
                ptrn, err := str.clone_from_cstring(pattern)
                if err != .None {
                    throw(L, fmt.ctprintf("filetrack: failed to clone pattern string: {}", err))
                }
                t.pattern = ptrn
            }
            

            return 1
        })
    }

    // Class
    {
        newtable(L) 
        defer setfield(L, -2, "Tracker")
        /* Userdata class indexing:
        methods:
            returns lua function
        properties:
            calls function
            A property is a table that contains:
                __get or __set
                expects
                pushes value

        Tracker:
        any => len(files) > 0
        new() {

            return () {

            }
        }
        */

        pushvalue(L, -1) // Capture the class as an upvalue
        defun(L, "__index", proc "c" (L: StateRef) -> i32 {
            using lua
            context = startfunc(L)
            /* stack contains:
               - Userdata
               - String
            */

            L_checktype(L, 1, auto_cast Type.USERDATA)
            key := L_checkstring(L, 2)
            
            log.warn("Indexing:", key)

            class := upvalueindex(1)
            
            // Properties (getters)
            if subtable(L, class, "__getters") {
                t := cast(Type) getfield(L, -1, key)
                if t == .FUNCTION {
                    pushvalue(L, 1) // 1: Object Instance
                    call(L, 1, 1) // Pops function and 1 from the stack, pushes result
                    return 1    // Return result
                }
                pop(L, 1) // Pop '__getters' if not found
            }

            t := cast(Type) getfield(L, class, key)
            // Methods
            if t == .FUNCTION {
                pushvalue(L, -1) // Upvalue 1: wrapping function
                pushvalue(L, 1) // Upvalue 2: object instance

                pushcclosure(L, proc "c" (L: StateRef) -> i32 {
                    using lua
                    argc := gettop(L)
                    funcid := upvalueindex(1)
                    pushvalue(L, funcid)
                    insert(L, 1)

                    selfid := upvalueindex(2)
                    pushvalue(L, selfid)
                    insert(L, 1)

                    // Call the function, do not care about number of results
                    top := gettop(L)
                    call(L, argc + 1, MULTRET)
                    return gettop(L) - top
                }, 2)
            }

            // No members
            pushfstring(L, "class Tracker: no member '%s'", key)
            throw(L)
            
        }, 1)

        // Getters
        {
            newtable(L)
            defer setfield(L, -2, "__getters")
            pushvalue(L, -2) // Capture the class as an upvalue
            defun(L, "any", proc "c" (L: StateRef) -> i32 {
                using lua
                context = startfunc(L)
                /* 1: Object instance */

                // TODO: implement
                log.error("Tracker.any not implemented")

                pushboolean(L, false)
                return 1
            }, 1)
        }

        
        
        // TODO: Finalizer
    }
    

    return 1
}
/*
track = {
    @ = {
        __call(self, pattern, cachefile) {
            / validate cachefile as valid file for the cache
            / validate 
            return userdata(track) {
                ...
            }
        }
    }
    class = {
        __index[class](self, value) {
            return class[value]
        }
        save(self) {
            data := parse_userdata()
        }
        any(self) {
            return len(self.files) > 0
        }
    }
    class_file = {
        __index(self, value) {
            @static offsets: map[cstring](uint, Type)
            if value in offsets {
                pushat(self[])
            } else {
                error ""
            }
        }
    }
}
*/

