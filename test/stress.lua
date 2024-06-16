-- Stress test for Bang/ninja

local fs = require "fs"

local root = arg[1]
assert(fs.is_dir(root))

var "builddir" (root/".build")

build.C : set "cvalid" {
    build.new "clang-tidy"
    : set "cmd" "clang-tidy"
    : set "flags" "--quiet --warnings-as-errors=*"
    : set "args" "$in > $out 2>/dev/null"
}

build.C:executable "$builddir/stress" {
    build.C:compile "$builddir/main.o" { root/"main.c" },
    ls(root/"*")
    : filter(fs.is_dir)
    : map(function(lib)
        return build.C:static_lib("$builddir"/lib..".a") { ls(lib/"**.c") }
    end)
}
