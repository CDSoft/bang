section [[
Dummy project showing bang capabilities
and many other features enabled by LuaX.

The src directory contains one C source per executable (and per architecture).

The lib directory is a library of sources common to all architectures.

The arch directory contains one sub directory par architecture
and header files defining a common API to all architectures.
]]

local F = require "F"
local fs = require "fs"

var "builddir" ".build"

local cflags = F{
    "-O3",
    "-Wall",
    "-Werror",
    "-Ilib", "-Iarch",
}

local ldflags = F{
}

fs.write("compile_flags.txt", cflags:unlines())

section "Common compilation options"

var "cflags" (cflags)
var "ldflags" (ldflags)

local architectures = fs.dir "arch"
    : filter(function(arch_name) return fs.is_dir(fs.join("arch", arch_name)) end)
    : sort()
    : map(function(arch_name)
        section(arch_name)

        local arch = require(fs.join("arch", arch_name, "config"))
        arch.name = arch_name

        var("cflags_"..arch_name)(arch.cflags)
        var("ldflags_"..arch_name)(arch.ldflags)

        rule("cc_"..arch_name) {
            description = "["..arch_name.."] CC $out",
            command = {arch.cc, "-c", "$cflags $cflags_"..arch_name, "-MD -MF $out.d", " $in -o $out"},
            depfile = "$out.d",
        }

        rule("ar_"..arch_name) {
            description = "["..arch_name.."] AR $out",
            command = {arch.ar, "-crs", "$out $in"},
        }

        rule("ld_"..arch_name) {
            description = "["..arch_name.."] LD $out",
            command = {arch.ld, "$ldflags $ldflags_"..arch_name, "-o $out $in"},
        }

        local arch_lib = fs.walk(fs.join("arch", arch_name))
            : filter(function(source) return fs.ext(source) == ".c" end)
            : sort()
            : map(function(source)
                local object = fs.join("$builddir", fs.splitext(source)..".o")
                build(object) { "cc_"..arch_name, source }
                return object
            end)

        arch.archive_file = fs.join("$builddir", "arch", arch_name, "arch.a")
        build(arch.archive_file) { "ar_"..arch_name, arch_lib }

        return arch
    end)

architectures : foreach(function(arch)
    arch.libraries = fs.dir "lib"
        : filter(function(lib_name) return fs.is_dir(fs.join("lib", lib_name)) end)
        : sort()
        : map(function(lib_name)
            section(lib_name.." for "..arch.name)
            local lib_objects = fs.walk(fs.join("lib", lib_name))
                : filter(function(source) return fs.ext(source) == ".c" end)
                : sort()
                : map(function(source)
                    local object = fs.join("$builddir", arch.name, (source:gsub("%.c$", ".o")))
                    build(object) { "cc_"..arch.name, source }
                    return object
                end)
            local lib_filename = fs.join("$builddir", arch.name, "lib", lib_name, lib_name..".a")
            build(lib_filename) { "ar_"..arch.name, lib_objects }
            return lib_filename
        end)
end)

architectures : foreach(function(arch)
    fs.dir "bin"
    : filter(function(bin_name) return fs.ext(bin_name) == ".c" and fs.is_file(fs.join("bin", bin_name)) end)
    : sort()
    : foreach(function(bin_name)
        section(fs.splitext(bin_name).." for "..arch.name)
        local object = fs.join("$builddir", arch.name, "bin", fs.splitext(bin_name)..".o")
        build(object) { "cc_"..arch.name, fs.join("bin", bin_name) }
        local bin_filename = fs.join("$builddir", arch.name, "bin", fs.splitext(bin_name)..arch.ext)
        build(bin_filename) { "ld_"..arch.name, object, arch.libraries, arch.archive_file }
    end)
end)

section "Project structure"

rule "graph" {
    description = "GRAPH $out",
    command = "ninja -t graph | doc/rename_random_ids.lua | dot -Tsvg -o$out",
}

build "doc/graph.svg" {"graph", "build.ninja"}
