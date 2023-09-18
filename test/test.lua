-- This file is part of bang.
--
-- bang is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- bang is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with bang.  If not, see <https://www.gnu.org/licenses/>.
--
-- For further information about bang you can visit
-- https://cdelord.fr/bang

local F = require "F"

section [[
This file is generated by bang for test purpose.
Section comments can have multiple lines.
]]

section "Atomic variables"

local v1 = var "var1" "string"
local v2 = var "var2" (42)
local v3 = var "var3" (true)

comment("v1        = "..v1)
comment("vars.var1 = "..vars.var1)
comment("v2        = "..v2)
comment("vars.var2 = "..vars.var2)
comment("v3        = "..v3)
comment("vars.var3 = "..vars.var3)

section "Compound variables"

local v4 = var "var4" {
    "string",
    42,
    true,
    {
        " foo  ",
        { },
        "  bar ",
    },
}
comment("v4        = "..v4)
comment("vars.var4 = "..vars.var4)

section "Rules"

local cc = rule "cc" {
    description = "CC $out",
    command = {
        "gcc",
        "$cflags",
        "-c",
        "$in -o $out",
    },
}

comment("cc = "..F.show(cc))

section "Build statements"

local o1 = build "foo1.o" {"cc", {"foo1.c", "foo.h"}}

local o2 = build "foo2.o" {"cc", {"foo2.c", "foo.h"},
    implicit_in = {"a.dat", "b.dat"},
    implicit_out = {"a.log", "b.log"},
    order_only_deps = {"x.dat"},
    myvar = "myval",
}

comment("o1 = "..F.show(o1))
comment("o2 = "..F.show(o2))

phony "all" { "foo1.c", "foo2.c" }

local o3 = build {"foo3.o", "foo4.o foo5.o"} {"cc", {"foo3.c"}}

comment("o3 = "..F.show(o3))

section "Inheritance"

rule "r1" {
    command = "cmd1",
    -- this variable shall be moved to the build statements that use this rule
    implicit_in = {"i1", "i2"},
}

build "b1" { "r1",
    implicit_in = {"i3"},
    implicit_out = {"o1"},
}

rule "r2" {
    command = "cmd2",
    -- this variable shall be moved to the build statements that use this rule
    implicit_in = {"i4", "i5"},
}

build "b2" { "r2",
    implicit_out = {"o2"},
}

section "Embedded rules"

build "special_target.txt" { "file1.txt", "file2.txt",
    description = "a rule embedded inside a build statement",
    command = "cat $in > $out",
    implicit_in = "hidden_input",
    implicit_out = "hidden_output",
    depfile = "$out.d",
}

section "Pools"

rule "link" {
    pool = pool "link_pool" { depth=4 },
}

build "link1" { "link" }
build "link2" { "link",
    pool = "",
}

section "Accumulations"

local xs = {}
acc(xs) "item1"
acc(xs) {"item2", "item3"}
acc(xs) {}
comment("xs = "..F.show(xs))

section "ls test"
ls "test" : foreach(comment)

section "ls test/*"
ls "test/*.*" : foreach(comment)

section "ls test/*.lua"
ls "test/*.lua" : foreach(comment)

section "ls test/**"
ls "test/**" : foreach(comment)

section "ls test/**.c"
ls "test/**.c" : foreach(comment)

section "ls test/**.lua"
ls "test/**.lua" : foreach(comment)

section "additional file"
local f = file ".build/test/tmp/new_file.txt"
f:write("Line", " ", 1, "\n")
f:write("Line", " ", 2, "\n")
comment ".build/test/tmp/new_file.txt should be created"

section "Command line arguments"
comment("The command line arguments are: "..F.show(arg))

-- clean test
clean "$builddir"
clean "$builddir/foo"
clean "foo/bar"

-- install test
install.prefix "~/.local/pub/bang_test"
install "bin" "foo1.bin"
install "lib" "foo1.lib"
install "bin" { "foo2.bin", "foo3.bin" }

-- help test
help.name "Bang test"
help.description "A short description of the Ninja file for building $name"
help.epilog "More information at https://cdelord.fr/bang"
help "target1" "description of target1"
help "target2" "description of target2"
help "target3-with-a-longer-name" "description of target3"
help "target4" "description of target4"
