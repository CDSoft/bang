section [[
Ninja file for bang
This file is generated by running bootstrap.sh
]]

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

help.name "Bang"
help.description [[Ninja file for building $name]]
help.epilog [[Without any arguments, Ninja will compile and test $name.]]

---------------------------------------------------------------------
-- Build directories
---------------------------------------------------------------------

section "Build directories"

var "builddir" ".build"

F"bin test doc" : words() : foreach(function(dir)
    var (dir) ("$builddir" / dir)
end)

clean "$builddir"

---------------------------------------------------------------------
-- Compilation
---------------------------------------------------------------------

section "Compilation"

local sources = {
    ls "src/*.lua",
    ls "lib/*.lua",
    build "$builddir/version" {
        description = "GIT version",
        command = "echo -n `git describe --tags` > $out",
        implicit_in = ".git/refs/tags .git/index",
    },
}

rule "luax" {
    description = "LUAX $out",
    command = "luax $arg -q -o $out $in",
}

local binaries = {
    build "$bin/bang"     { "luax", sources },
    build "$bin/bang.lua" { "luax", sources, arg="-t lua" },
}

phony "compile" { binaries }
default "compile"
help "compile" "compile $name"

install "bin" { binaries }

---------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------

section "Tests"

rule "diff" {
    description = "DIFF $in",
    command = "diff $in > $out || (cat $out && false)",
}

rule "run_test" {
    description = "BANG $in",
    command = {
        "rm -f $test_dir/new_file.txt;",
        "$bang -q $in -o $out -- arg1 arg2 -x=y",
    },
}

rule "run_test-future-version" {
    description = "BANG $in",
    command = "$bang -q $in -o $out",
}

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
            build(test_dir/"test-future-version-1.ninja") { "run_test-future-version", "test/test-future-version-1.lua",
                bang = bang,
                implicit_in = bang,
                validations = build(test_dir/"test-future-version-1.diff") {"diff", {test_dir/"test-future-version-1.ninja", "test/test-future-version-1-"..interpreter..".ninja"}},
            },
            build(test_dir/"test-future-version-2.ninja") { "run_test-future-version", "test/test-future-version-2.lua",
                bang = bang,
                implicit_in = bang,
                validations = build(test_dir/"test-future-version-2.diff") {"diff", {test_dir/"test-future-version-2.ninja", "test/test-future-version-2-"..interpreter..".ninja"}},
            },
            build(test_dir/"test-future-version-3.ninja") { "run_test-future-version", "test/test-future-version-3.lua",
                bang = bang,
                implicit_in = bang,
                validations = build(test_dir/"test-future-version-3.diff") {"diff", {test_dir/"test-future-version-3.ninja", "test/test-future-version-3-"..interpreter..".ninja"}},
            },
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
