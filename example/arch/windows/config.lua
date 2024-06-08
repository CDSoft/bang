local target = "x86_64-windows-gnu"

return {
    -- level 0: hand written compile rules
    cc = {"zig cc", "-target", target},
    cflags = {
        "-DTARGET=\""..target.."\"",
    },
    ar = {"zig ar"},
    ld = {"zig cc", "-target", target},
    ldflags = {},
    ext = ".exe",

    -- level 1: C compilation feature provided by bang
    compiler = require "C" : new(target)
        : set "cc"     { "zig cc", "-target", target }
        : add "cflags" { "-DTARGET=\""..target.."\"" }
        : set "ar"     { "zig ar" }
        : set "ld"     { "zig cc", "-target", target }
        : set "exe_ext" ".exe",
}
