local target = "x86_64-macos-none"

return {
    cc = {"zig cc", "-target", target},
    cflags = {
        "-DTARGET=\""..target.."\"",
    },
    ar = {"zig ar"},
    ld = {"zig cc", "-target", target},
    ldflags = {},
    ext = "",
}
