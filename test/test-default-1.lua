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
-- https://github.com/cdsoft/bang

var "$builddir" ".build"

help "all" "Build all"
install "bin"
clean "$builddir"
clean.mrproper "$builddir"

rule "cp" { command = "cp $in $out" }
build "bar" { "cp", "foo" }
build "baz" { "cp", "foo" }

phony "all" { "bar", "baz" }

section "Default target test"

comment "no default target => default shall build bar, baz and all"
comment "but not help, install and clean"
