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

var "var1" "string"                 assert(vars.var1 == "string")
var "var2" (42)                     assert(vars.var2 == "42")
var "var3" (true)                   assert(vars.var3 == "true")

section "Compound variables"

var "var4" {
    "string",
    42,
    true,
    {
        "foo",
        { },
        "bar",
    },
}
assert(vars.var4 == "string 42 true foo bar")

section "Rules"

rule "cc" {
    command = "gcc $cflags -c $in -o $out",
    another_variable = {"foo", {"bar", {}, 42}},
}

section "Build statements"

build "foo1.o" {"cc", {"foo1.c", "foo.h"}}

build "foo2.o" {"cc", {"foo2.c", "foo.h"},
    implicit_in = {"a.dat", "b.dat"},
    implicit_out = {"a.log", "b.log"},
    order_only_deps = {"x.dat"},
    myvar = "myval",
}

phony "all" { "foo1.c", "foo2.c" }

section "ls test"
ls "test" : foreach(function(name) comment(name) end)

section "ls test/*"
ls "test/*.*" : foreach(function(name) comment(name) end)

section "ls test/*.lua"
ls "test/*.lua" : foreach(function(name) comment(name) end)

section "ls test/**"
ls "test/**" : foreach(function(name) comment(name) end)

section "ls test/**.c"
ls "test/**.c" : foreach(function(name) comment(name) end)

section "ls test/**.lua"
ls "test/**.lua" : foreach(function(name) comment(name) end)

section "additional file"
local f = file ".build/test/tmp/new_file.txt"
f:write("Line", " ", 1, "\n")
f:write("Line", " ", 2, "\n")
comment ".build/test/tmp/new_file.txt should be created"

section "Command line arguments"
comment("The command line arguments are: "..F.show(arg))
