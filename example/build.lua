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

section [[
Targets
]]

local arch = F{}

local cflags = F{
    "-O3",
    "-Wall",
    "-Werror",
    "-Ilib", "-Iarch",
}

local ldflags = F{
}

fs.write("compile_flags.txt", cflags:unlines())

var "cflags" (cflags)
var "ldflags" (ldflags)

fs.dir "arch"
: filter(function(name) return fs.is_dir(fs.join("arch", name)) end)
: sort()
: foreach(function(name)
    section(name)

    local cfg = require(fs.join("arch", name, "config"))
    arch[name] = cfg

    var("cflags_"..name)(cfg.cflags)
    var("ldflags_"..name)(cfg.ldflags)

    rule("cc_"..name) {
        description = "CC "..name..": $out",
        command = {cfg.cc, "-c", "$cflags $cflags_"..name, "-MD -MF $out.d", " $in -o $out"},
        depfile = "$out.d",
    }

    rule("ar_"..name) {
        description = "AR "..name..": $out",
        command = {cfg.ar, "-crs", "$out $in"},
    }

    rule("ld_"..name) {
        description = "LD "..name..": $out",
        command = {cfg.ld, "$ldflags $ldflags_"..name, "-o $out $in"},
    }

    local lib = {}

    fs.walk(fs.join("arch", name))
    : filter(function(source) return fs.ext(source) == ".c" end)
    : sort()
    : foreach(function(source)
        local object = fs.join("$builddir", fs.splitext(source)..".o")
        build(object) { "cc_"..name, source }
        lib[#lib+1] = object
    end)

    local archive = fs.join("$builddir", "arch", name, "arch.a")
    build(archive) { "ar_"..name, lib }

end)

local libs = F{}

arch : foreachk(function(arch_name, cfg)
    libs[arch_name] = {}
    fs.dir "lib"
    : filter(function(name) return fs.is_dir(fs.join("lib", name)) end)
    : sort()
    : foreach(function(name)
        section(name.." for "..arch_name)
        local lib = F{}
        fs.walk(fs.join("lib", name))
        : filter(function(source) return fs.ext(source) == ".c" end)
        : sort()
        : foreach(function(source)
            local dest_o = fs.join("$builddir", arch_name, (source:gsub("%.c$", ".o")))
            build(dest_o) { "cc_"..arch_name, source }
            lib[#lib+1] = dest_o
        end)
        local lib_name = fs.join("$builddir", arch_name, "lib", name, name..".a")
        build(lib_name) { "ar_"..arch_name, lib }
        libs[arch_name][#libs[arch_name]+1] = lib_name
    end)
end)

arch : foreachk(function(arch_name, cfg)
    fs.dir "bin"
    : filter(function(name) return fs.ext(name) == ".c" and fs.is_file(fs.join("bin", name)) end)
    : sort()
    : foreach(function(name)
        section(fs.splitext(name).." for "..arch_name)
        local dest_o = fs.join("$builddir", arch_name, "bin", fs.splitext(name)..".o")
        build(dest_o) { "cc_"..arch_name, fs.join("bin", name) }
        local bin_name = fs.join("$builddir", arch_name, "bin", (fs.splitext(name)))
        local lib_arch = fs.join("$builddir", "arch", arch_name, "arch.a")
        build(bin_name) { "ld_"..arch_name, dest_o, libs[arch_name], lib_arch }
    end)
end)

section "Project structure"

rule "graph" {
    description = "GRAPH $out",
    command = "ninja -t graph | doc/rename_random_ids.lua | dot -Tsvg -o$out",
}

build "doc/graph.svg" {"graph", "build.ninja"}
