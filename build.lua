section [[
This file is part of bang.

bang is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

bang is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with bang.  If not, see <https://www.gnu.org/licenses/>.

For further information about bang you can visit
https://cdelord.fr/bang
]]

local F = require "F"
local sys = require "sys"

help.name "Bang"
help.description [[Ninja file for building $name]]
help.epilog [[Without any arguments, Ninja will compile and test $name.]]

local target, args = target(arg)
if #args > 0 then
    F.error_without_stack_trace(args:unwords()..": unexpected arguments")
end

---------------------------------------------------------------------
-- Build directories
---------------------------------------------------------------------

section "Build directories"

var "builddir" (".build"/(target and target.name))

var "bin"  "$builddir"
var "test" "$builddir/test"

clean "$builddir"

---------------------------------------------------------------------
-- Compilation of ninja with Zig
---------------------------------------------------------------------

local ninja_bin = Nil

if target then

section "Ninja compilation"

var "zig_version" "0.13.0"
local home, zig_path = F.unpack(F.case(sys.os) {
    windows = { "LOCALAPPDATA", "zig" / "$zig_version" },
    [F.Nil] = { "HOME", ".local" / "opt" / "zig" / "$zig_version" },
})

var "archive" ("zig-"..sys.os.."-"..sys.arch.."-$zig_version.tar.xz")
var "url" ("https://ziglang.org/download/$zig_version/$archive")
var "zig_path" (os.getenv(home) / zig_path)
var "zig" ("$zig_path"/"zig"..sys.exe)

build "$zig" {
    description = "install $out",
    command = {
        "test -x $zig",
        "||",
        "( curl -fsSL $url -o $builddir/$archive && tar xJf $builddir/$archive -C $zig_path --strip-components 1 )",
    },
}

local target_name = {"-target", F{target.arch, target.os, target.libc}:str"-"}

local cpp = build.C:new "zig"
    : set "implicit_in" "$zig"
    : set "cc" { "$zig c++", target_name }
    : set "ar" "$zig ar"
    : set "ld" { "$zig c++", target_name }
    : set "c_exts" { ".cc" }
    : add "cflags" {
        "-Wno-deprecated",
        "-fno-rtti",
        "-fno-exceptions",
        "-std=c++11",
        "-pipe",
        "-O2",
        "-fdiagnostics-color",
        "-fvisibility=hidden",
        "-DNDEBUG",
        case (target.os) {
            linux = {
                "-DUSE_PPOLL",
            },
            macos = {},
            windows = {
                "-D__USE_MINGW_ANSI_STDIO=1",
                "-DUSE_PPOLL",
            },
        }
    }
    : add "ldflags" {
        "-pipe",
        "-s",
    }

local win_sources   = ls "ext/ninja/src/*-win32.cc"
local posix_sources = ls "ext/ninja/src/*-posix.cc"
local ninja_sources = ls "ext/ninja/src/*.cc"
    : difference(posix_sources..win_sources)
    : filter(function(name)
        return  not name:match "test%.cc$"
            and not name:match "bench%.cc$"
            and not name:match "browse%.cc$"
            and not name:match "%.in%.cc$"
    end)

ninja_bin = cpp:executable("$bin/ninja"..target.exe) {
    ninja_sources,
    case (target.os) {
        linux = posix_sources,
        macos = posix_sources,
        windows = win_sources,
    },
}

end

---------------------------------------------------------------------
-- Compilation
---------------------------------------------------------------------

section "Compilation"

local sources = {
    ls "src/*.lua",
    build "$builddir/version" {
        description = "GIT version",
        command = "echo -n `git describe --tags` > $out",
        implicit_in = ".git/refs/tags",
    },
}

build.luax.add_global "flags" "-q"

local binaries = {
    build.luax[target and target.name or "native"]("$bin/bang"..(target or sys).exe) { sources },
    build.luax.lua "$bin/bang.lua" { sources },
    ninja_bin,
}

-- used by LuaX only
local bang_luax = build.luax.luax "$bin/bang.luax" { sources }

phony "compile" { binaries, bang_luax }
default "compile"
help "compile" ("compile $name"..(target and " for "..target.name or ""))

install "bin" { binaries }

generator {
    implicit_in = sources,
}

phony "all" { "compile", "test" }

---------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------

if not target then

section "Tests"

rule "diff" {
    description = "DIFF $in",
    command = "diff $in > $out || (cat $out && false)",
}

rule "run_test" {
    description = "BANG $in",
    command = {
        "rm -f $test_dir/new_file.txt;",
        "$bang -g $bang -q $in -o $out -- arg1 arg2 -x=y",
    },
}

rule "run_test-future-version" {
    description = "BANG $in",
    command = "$bang -g $bang -q $in -o $out",
}

rule "run_test-default" {
    description = "BANG $in",
    command = "$bang -g $bang -q $in -o $out",
}

rule "run_test-error" {
    description = "BANG $in",
    command = "$bang -g $bang -q $in -o $ninja_file 2> $out; test $$? -ne 0",
}

rule "missing" {
    description = "TEST $missing",
    command = "test ! -f $missing_file > $out",
}

rule "run_test-error-unknown_file" {
    description = "BANG $in",
    command = "$bang -g $bang -q $unknown_input -o $ninja_file 2> $out; test $$? -ne 0",
}

section "Functional tests"

phony "test" {

    F{
        { "$bin/bang",     "$test/luax" },
        { "$bin/bang.lua", "$test/lua"  },
    }
    : map(function(bang_test_dir)
        local bang, test_dir = F.unpack(bang_test_dir)
        local interpreter = test_dir:basename()
        section("Test of the "..interpreter.." interpreter")
        return {

            -- Nominal tests
            build(test_dir/"test.ninja") { "run_test", "test/test.lua",
                bang = bang,
                test_dir = test_dir,
                implicit_in = bang,
                implicit_out = test_dir/"new_file.txt",
                validations = {
                    build(test_dir/"test.diff")     {"diff", {test_dir/"test.ninja",   "test/test-"..interpreter..".ninja"}},
                    build(test_dir/"new_file.diff") {"diff", {test_dir/"new_file.txt", "test/new_file.txt"}},
                },
            },

            -- ninja_required_version
            ls "test/test-future-version-*.lua"
            : map(function(src)
                local ninja     = test_dir/src:basename():chext".ninja"
                local diff_res  = test_dir/src:basename():chext".diff"
                local ninja_ref = src:chext".ninja"
                return build(ninja) { "run_test-future-version", src,
                    bang = bang,
                    implicit_in = bang,
                    validations = build(diff_res) { "diff", ninja, ninja_ref },
                }
            end),

            -- default targets
            ls "test/test-default-*.lua"
            : map(function(src)
                local ninja     = test_dir/src:basename():chext".ninja"
                local diff_res  = test_dir/src:basename():chext".diff"
                local ninja_ref = src:splitext().."-"..interpreter..".ninja"
                return build(ninja) { "run_test-default", src,
                    bang = bang,
                    implicit_in = bang,
                    validations = build(diff_res) { "diff", ninja, ninja_ref },
                }
            end),

            -- errors
            ls "test/test-err-*.lua"
            : map(function(src)
                local ninja         = test_dir/src:basename():chext".ninja"
                local ninja_missing = test_dir/src:basename():chext".ninja-missing"
                local diff_res      = test_dir/src:basename():chext".diff"
                local stderr        = test_dir/src:basename():chext".stderr"
                local stderr_ref    = src:chext".stderr"
                return build(stderr) { "run_test-error", src,
                    bang = bang,
                    implicit_in = bang,
                    ninja_file = ninja,
                    validations = {
                        build(diff_res)      { "diff", stderr, stderr_ref },
                        build(ninja_missing) { "missing", stderr, missing_file=ninja },
                    },
                }
            end),

            -- unknown file
            F{ "test/unknown_file.lua" }
            : map(function(src)
                local ninja         = test_dir/src:basename():chext".ninja"
                local ninja_missing = test_dir/src:basename():chext".ninja-missing"
                local diff_res      = test_dir/src:basename():chext".diff"
                local stderr        = test_dir/src:basename():chext".stderr"
                local stderr_ref    = src:chext".stderr"
                return build(stderr) { "run_test-error-unknown_file",
                    bang = bang,
                    implicit_in = bang,
                    ninja_file = ninja,
                    unknown_input = src,
                    validations = {
                        build(diff_res)      { "diff", stderr, stderr_ref },
                        build(ninja_missing) { "missing", stderr, missing_file=ninja },
                    },
                }
            end),

        }
    end),

}

section "Stress tests"

phony "stress" {
    build "$test/stress/main.c" { "test/stress-gen.lua",
        description = "[stress test] Generate a HUGE C project",
        command = "$in $out",
        pool = "console",
    },
    build "$test/stress.ninja" { "test/stress.lua",
        description = "[stress test] BANG $in",
        command = "time $bin/bang $in -o $out -- $test/stress",
        pool = "console",
        implicit_in = {
            "$bin/bang",
            "$test/stress/main.c",
        },
    },
    build "$test/stress.done" { "$test/stress.ninja",
        description = "[stress test] NINJA $in",
        command = "time ninja -f $in && touch $out",
        pool = "console",
        implicit_in = "$test/stress.ninja",
    },
}

default "test"
help "test" "test $name"

end
