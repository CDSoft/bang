-- Stress test for Bang/ninja

local fs = require "fs"

local root = arg[1]
assert(fs.is_dir(root))

var "builddir" (root)

rule "cc" { description = "CC $in",  command = "cc -MD -MF $depfile -c $in -o $out", depfile = "$out.d" }
rule "ar" { description = "AR $out", command = "ar -crs $out $in" }
rule "ld" { description = "LD $out", command = "cc $in -o $out" }

build(root/"stress") { "ld",

    build(root/"main.o") { "cc", root/"main.c" },

    fs.dir(root)
    : filter(function(lib) return fs.is_dir(root/lib) end)
    : map(function(lib)
        return build(root/lib/lib..".a") { "ar",
            ls (root/lib/"**.c")
            : map(function(src)
                local obj = src:splitext()..".o"
                return build(obj) { "cc", src }
            end)
        }
    end),

}

default(root/"stress")
