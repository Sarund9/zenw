package main

import lua "vendor:lua/5.4"

import "base:runtime"
import "core:log"
import "core:os"
import "core:fmt"
import "core:c/libc"
import str "core:strings"
import fpath "core:path/filepath"

gZenwModules := map[cstring]CFunc {
    "odin" = odin_load,
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

