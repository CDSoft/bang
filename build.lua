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
local fs = require "fs"

help.name "Bang"
help.description [[Ninja file for building $name]]
help.epilog [[Without any arguments, Ninja will compile and test $name.]]

---------------------------------------------------------------------
-- Build directories
---------------------------------------------------------------------

section "Build directories"

var "builddir" ".build"

F"bin test doc" : words() : foreach(function(dir)
    var (dir) (fs.join("$builddir", dir))
end)

clean "$builddir"

---------------------------------------------------------------------
-- Compilation
---------------------------------------------------------------------

section "Compilation"

rule "luax" {
    description = "LUAX $out",
    command = "luax -q -o $out $in",
}

rule "version" {
    description = "GIT $version",
    command = "echo -n `git describe --tags` > $out",
}

build "$bin/bang" {"luax", ls "src/*.lua", "$builddir/version"}
build "$builddir/version" {"version",
    implicit_in = ".git/refs/tags .git/index",
}
phony "compile" { "$bin/bang" }
default "compile"
help "compile" "compile $name"

install "bin" "$bin/bang"

---------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------

section "Tests"

rule "run_test" {
    description = "BANG $in",
    command = "$bin/bang -q $in -o $out -- arg1 arg2 -x=y",
}

rule "diff" {
    description = "DIFF $in",
    command = "diff $in && touch $out",
}

build "$test/test.ninja" {"run_test", "test/test.lua",
    implicit_in = "$bin/bang",
    implicit_out = { "$test/tmp/new_file.txt", "$test/help.txt" },
}
build "$test/test.ok" {"diff", {"$test/test.ninja", "test/test.ninja"}}
build "$test/new_file.ok" {"diff", {"$test/tmp/new_file.txt", "test/new_file.txt"}}
build "$test/help.txt.ok" {"diff", {"$test/help.txt", "test/help.txt"}}

phony "test" {"$test/test.ok", "$test/new_file.ok", "$test/help.txt"}
default "test"
help "test" "test $name"
