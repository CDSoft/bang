local target = "x86_64-linux-musl"

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
