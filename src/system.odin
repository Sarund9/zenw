package main



when ODIN_OS == .Windows {
    EXT_RUN :: ".exe"
} else when ODIN_OS == .Linux {
    EXT_RUN :: ".bin"
} else when ODIN_OS == .Darwin {
    EXT_RUN :: ".app"
}

when ODIN_OS == .Windows {
    EXT_SHARED :: ".dll"
} else when ODIN_OS == .Linux {
    EXT_SHARED :: ".so"
} else when ODIN_OS == .Darwin {
    EXT_SHARED :: ".so"
}


// TODO: Compile errors
