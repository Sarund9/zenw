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
Key in the ZENW registry table {
    / pointer to odin context, set before calling lua
    context = *
    / metatable to the global table of all modules
    STD = {
        __index, include,
        System, Log, Format,
    }
    / Loaded modules (Globals of executed script files)
    MOD_CACHE = {

    }
    / Meta info about the current executing module
    MOD = {
        fullpath / complete filepath to the module
    }
}
*/
REGISTRY_KEY    :: "ZENW"
CONTEXT         :: "context"
STD             :: "STD"
WORKSPACES      :: "WORKSPACES"


init :: proc(L: State) {
    using lua

    settop(L, 0)

    // Create ZENW registry table
    {
        newtable(L)
        setfield(L, REGISTRYINDEX, REGISTRY_KEY)
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)
    }

    // Sets ZENW["context"] to null
    pushlightuserdata(L, nil)
    setfield(L, -2, CONTEXT)

    // Create the STD table
    {
        newtable(L)
        setfield(L, -2, STD)
        getfield(L, -1, STD) // {zenw} {std}
    
        mod_interop(L)
        mod_log(L)  // 

        // Create 

        defun(L, "__index", stdindex)

        // Set the global table's metatable to STD
        pushglobaltable(L)  // {zenw} {std} {glob}
        insert(L, -2)       // {zenw} {glob} {std}
        setmetatable(L, -2) // glob[@] = std
        pop(L, 1) // Pops the global table from the stack

        // Standart Indexer
        stdindex :: proc "c" (L: ^lua.State) -> i32 {
            using lua
            context = startfunc(L)
            
            key_type := type(L, 2)
            if key_type == .NUMBER {
                return 0 // Will not index STD by fields
            }

            key := tostring(L, 2) // get the string key

            // Get the ZENW registry table
            getfield(L, REGISTRYINDEX, REGISTRY_KEY)
            getfield(L, -1, STD) // Get the STD table

            // Getting field
            index_type := cast(lua.Type) getfield(L, -1, key)
            
            // Move wherever we found to the beggining of the stack
            insert(L, 1)
            settop(L, 1) // Return only that singular value
            return 1
        }
    }

    // dumpstack(L)

    // Loaded Modules and ModInfo tables
    newtable(L)
    setfield(L, -2, WORKSPACES)
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

    s = auto_cast pcall(L, 0, 0, 0)
    
    // TODO: Yield handling

    if s != .OK {
        log.error("Workspace call failed:", s)
        dumpstack(L)
        return
    }
    // log.info("Workspace call success:")
    // dumpstack(L)
}

startfunc :: proc "c" (L: State) -> runtime.Context {
    using lua
    getfield(L, REGISTRYINDEX, REGISTRY_KEY)
    getfield(L, -1, CONTEXT)
    ctx_type := type(L, -1)
    if ctx_type != .LIGHTUSERDATA {
        context = runtime.default_context()
        panic("Invalid context")
    }
    
    ptr := touserdata(L, -1)

    if ptr == nil {
        context = runtime.default_context()
        panic("Invalid context")
    }

    // Pop both values from the stack
    pop(L, 2)
    return (cast(^runtime.Context) ptr)^
}

// Expects at table from the stack, sets a CFunction
defun :: proc(L: State, name: cstring, func: Func) {
    using lua
    pushcfunction(L, func)
    setfield(L, -2, name)
}


throw :: proc { throw_lit, throw_raw }

throw_lit :: proc(L: State, err: cstring) -> ! {
    using lua
    pushliteral(L, err)
    error(L)
    unreachable()
}

throw_raw :: proc(L: State) -> ! {
    using lua
    error(L)
    unreachable()
}

// Expects a table (STD) at the stack, sets global functions
mod_glob :: proc(L: State) {
    
    @static LOADING: u8
    /*
    after include and using find a valid file to load, and that it wasn't loaded, they call this function.
    it will load and execute the file.
    it expects to be called from lua (does not set the odin context)
    the loaded module is added to ZENW.WORKSPACES, and pushed to the stack.
    If loading the module yields an error, the function will return false
    */
    exec_file :: proc(L: State, filepath: cstring) -> bool {
        using lua
        

        pushlightuserdata(L, &LOADING)
        setfield(L, -2, filepath)       // work[filepath] = nil
        // -> {zenw} {work}

        loadStatus := lua.L_loadfile(L, filepath)
        if loadStatus != .OK {
            /* %s lua string %f lua number %I lua integer %p pointer
            %d c.int %c c.int one byte %U c.long as UTF-8 */
            // TODO: Wrap Errors
            lua.pushfstring(L, "Cannot load file %s", filepath)
            return false
        }

        getfield(L, REGISTRYINDEX, REGISTRY_KEY) // .. bin {zenw}
        getfield(L, -1, STD)        // .. bin {zenw} {std}
        newtable(L)                 // .. bin {zenw} {std} {env}
        
        insert(L, -2)               // .. bin {zenw} {env} {std}
        setmetatable(L, -2)         // .. bin {zenw} {env(std)}
        
        insert(L, -3)               // .. {env} bin {zenw}
        pop(L, 1)                   // .. {env} bin
        
        pushvalue(L, -2)            // .. {env} chunk {env}
        setupvalue(L, -2, 1)        // .. {env} chunk
        
        runStatus := cast(lua.Status) pcall(L, 0, 0, 0)

        // TODO: Yield handling

        if runStatus != .OK {
            // log.error("SubExec call failed:", runStatus)
            // dumpstack(L)
            // msg := fmt.ctprintf("SubExec call failed: {}", runStatus)
            // lua.pushstring(L, msg)
            // TODO: Wrap Errors
            return false
        }

        // Add the module to ZENW.WORKSPACES
        //             from before: // {zenw} {work} <- {env}
        pushvalue(L, -1)            // {zenw} {work} {env} {env}
        setfield(L, -3, filepath)   // {zenw} {work} {env}

        return true
    }
    
    // Runs a lua file
    defun(L, "include", proc "c" (L: State) -> i32 {
        context = startfunc(L)
        using lua, appState
        
        strlen: uint
        arg := L_checkstring(L, 1, &strlen)
        /* path should be relative to the current workspace or file
           it should be inside the current workspace
        */
        literalpath := str.concatenate({string(arg), ".lua"}, context.temp_allocator)

        


        assert(false, "Not Implemented")

        fullpath := path.join({ "", string(arg) }, context.temp_allocator)
        fullpath_c := str.clone_to_cstring(fullpath, context.temp_allocator)

        if !os.exists(fullpath) {
            lua.pushfstring(L, "Cannot include file '%s', as", arg)
            throw(L)
        }

        // TODO: Ensure that 'fullpath' is contained in workspace

        // path.dir()

        // check that fullpath is not the workspace file
        filename := path.base(auto_cast arg)
        if filename == "zenw.lua" {
            lua.pushfstring(L, "Cannot include ", arg)
            throw(L)
        }

        // 
        {

        }
        
        getfield(L, REGISTRYINDEX, REGISTRY_KEY)    // .. {zenw}
        getfield(L, -1, WORKSPACES)     // .. {zenw} {work}

        // Check that the Workspace is not already loaded
        {
            ftype := getfield(L, -1, fullpath_c)     // .. {zenw} {work}
            #partial switch Type(ftype) {
            case .TABLE:
                pushfstring(L, "Error: repeated include: %s", fullpath_c)
                throw(L)
            case .NIL: // 
                pop(L, 1)       // Pops nil from the stack
                ok := exec_file(L, fullpath_c)
                insert(L, -4)   // Insert result back to the beginning
                pop(L, 3)       // Pop all other elements from the stack
        
                if !ok {
                    throw(L)
                }
                return 1
            case .LIGHTUSERDATA:

                pushfstring(L, "Error: cyclic dependency on include: %s", fullpath_c)
                throw(L)
            case:
                panic("Something has gone wrong...")
            }
            
        }
        
        ok := exec_file(L, fullpath_c)
        if !ok {
            throw(L)
        }
        return 1
    })
    
    defun(L, "using", proc "c" (L: State) -> i32 {
        context = startfunc(L)
        using lua
        strlen: uint
        cstr := L_checkstring(L, 1, &strlen)
    
        return 0
    })
}

// Generates the global import/export/include functions
mod_interop :: proc(L: State) {
    
    // Standart 'export'
    defun(L, "export", proc "c" (L: ^lua.State) -> i32 {
        context = startfunc(L)
        using lua
        
        strlen: uint
        cstr := L_checkstring(L, 1, &strlen)
        // TODO: Discard extra arguments ??
        pop(L, 1)

        ok := export_script(str.clone_from_cstring(cstr, context.temp_allocator))
        if !ok {
            pushfstring(L, "Cannot export '%s', file not found", cstr)
            throw(L)
        }

        return 0
    })

    @static LOADING: u8

    exec_file :: proc(L: State, filepath: cstring) -> bool {
        using lua
        

        pushlightuserdata(L, &LOADING)
        setfield(L, -2, filepath)       // work[filepath] = nil
        // -> {zenw} {work}

        loadStatus := lua.L_loadfile(L, filepath)
        if loadStatus != .OK {
            /* %s lua string %f lua number %I lua integer %p pointer
            %d c.int %c c.int one byte %U c.long as UTF-8 */
            // TODO: Wrap Errors
            lua.pushfstring(L, "Cannot load file %s", filepath)
            return false
        }

        getfield(L, REGISTRYINDEX, REGISTRY_KEY) // .. bin {zenw}
        getfield(L, -1, STD)        // .. bin {zenw} {std}
        newtable(L)                 // .. bin {zenw} {std} {env}
        
        insert(L, -2)               // .. bin {zenw} {env} {std}
        setmetatable(L, -2)         // .. bin {zenw} {env(std)}
        
        insert(L, -3)               // .. {env} bin {zenw}
        pop(L, 1)                   // .. {env} bin
        
        pushvalue(L, -2)            // .. {env} chunk {env}
        setupvalue(L, -2, 1)        // .. {env} chunk
        
        runStatus := cast(lua.Status) pcall(L, 0, 0, 0)

        // TODO: Yield handling

        if runStatus != .OK {
            // log.error("SubExec call failed:", runStatus)
            // dumpstack(L)
            // msg := fmt.ctprintf("SubExec call failed: {}", runStatus)
            // lua.pushstring(L, msg)
            // TODO: Wrap Errors
            return false
        }

        // Add the module to ZENW.WORKSPACES
        //             from before: // {zenw} {work} <- {env}
        pushvalue(L, -1)            // {zenw} {work} {env} {env}
        setfield(L, -3, filepath)   // {zenw} {work} {env}

        return true
    }

    // Standart 'import'
    defun(L, "import", proc "c" (L: ^lua.State) -> i32 {
        context = startfunc(L)
        using lua
        strlen: uint
        cstr := L_checkstring(L, 1, &strlen)
        // TODO: Discard extra arguments ??
        // pop(L, 1)

        fullpath := import_script(str.clone_from_cstring(cstr, context.temp_allocator))
        if fullpath == nil {
            pushfstring(L, "Error: unknown import: %s", cstr)
            throw(L)
        }

        fullpath_c := str.clone_to_cstring(fullpath.(string), context.temp_allocator)

        getfield(L, REGISTRYINDEX, REGISTRY_KEY)    // .. {zenw}
        getfield(L, -1, WORKSPACES)     // .. {zenw} {work}
        // Check that the Workspace is not already loaded
        {
            ftype := getfield(L, -1, fullpath_c)     // .. {zenw} {work}
            #partial switch Type(ftype) {
            case .TABLE:
                pushfstring(L, "Error: repeated include: %s", fullpath_c)
                throw(L)
            case .NIL: // 
                pop(L, 1)       // Pops nil from the stack
                ok := exec_file(L, fullpath_c)
                insert(L, -4)   // Insert result back to the beginning
                pop(L, 3)       // Pop all other elements from the stack

                if !ok {
                    throw(L)
                }
                return 1
            case .LIGHTUSERDATA:

                pushfstring(L, "Error: cyclic dependency on include: %s", fullpath_c)
                throw(L)
            case:
                panic("Something has gone wrong...")
            }
            
        }


        dumpstack(L)
        assert(false, "IMPORT")
        return 0
    })

    // TODO: include for simplicity
}

// Generates the Log module.
mod_log :: proc(L: State) {
    using lua
    
    common :: proc "c" (L: ^lua.State) -> (string, runtime.Context) {
        using lua
        context = startfunc(L)
        top := gettop(L)
        if top == 0 {
            throw(L, "Log.info: no arguments passed")
        }
        if top > 1 {
            throw(L, "Log.info: too many arguments passed")
        }

        strl: uint
        cstr := L_checkstring(L, 1, &strl)
        ostr := str.string_from_ptr(auto_cast cstr, auto_cast strl)
        
        settop(L, 0)
        return ostr, context
    }

    newtable(L)
    defer setfield(L, -2, "Log")

    defun(L, "info", proc "c" (L: ^lua.State) -> i32 {
        message: string
        message, context = common(L)
        log.info(message)
        return 0
    })

    
    
}
