-- Stress test for Bang/ninja

local fs = require "fs"

local root = arg[1]
assert(fs.is_dir(root))

var "builddir" (root/".build")

rule "cc" { description = "CC $in",  command = "cc -MD -MF $depfile -c $in -o $out", depfile = "$out.d" }
rule "ar" { description = "AR $out", command = "ar -crs $out $in" }
rule "ld" { description = "LD $out", command = "cc $in -o $out" }

rule "clangtidy" {
    description = "CK $in",
    command = "clang-tidy --quiet --warnings-as-errors=* $in > $out 2>/dev/null",
}

build("$builddir/stress") { "ld",

    build("$builddir/main.o") { "cc", root/"main.c",
        validations = {
            build("$builddir/main.ok") { "clangtidy", root/"main.c" },
        }
    },

    ls(root/"*")
    : filter(function(lib) return fs.is_dir(lib) end)
    : map(function(lib)
        return build("$builddir"/lib..".a") { "ar",
            ls (lib/"**.c")
            : map(function(src)
                local obj = "$builddir"/src:splitext()..".o"
                return build(obj) { "cc", src,
                    validations = {
                        build(obj:splitext()..".ok") { "clangtidy", src },
                    }
                }
            end)
        }
    end),

}
