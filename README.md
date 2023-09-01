Bang
====

Bang is a [Ninja](https://ninja-build.org) file generator scriptable in [LuaX](https://cdelord.fr/luax).

Installation
============

Bang is written in LuaX.
It can be compiled with [Ninja](https://ninja-build.org) and [LuaX](https://github.com/CDSoft/luax).

## LuaX

``` sh
$ git clone https://github.com/CDSoft/luax
$ cd luax
$ make install  # this should install LuaX to ~/.local/bin
```

## Bang

``` sh
$ git clone https://github.com/CDSoft/bang
$ cd bang
$ ninja install  # this should compile bang with Ninja and install it to ~/.local/bin
```

or set `$PREFIX` to install `bang` to a custom directory (`$PREFIX/bin`):

``` sh
$ PREFIX=/path ninja install # installs bang to /path/bin
```

Usage
=====

```
$ bang -h
Usage: bang [-h] [-v] [-q] [-o output] [<input>]

Ninja file generator

Arguments after "--" are given to the input script

Arguments:
   input                 Lua script (default: build.lua)

Options:
   -h, --help            Show this help message and exit.
   -v                    Print Bang version
   -q                    Quiet mode (no output on stdout)
   -o output             Output file (default: build.ninja)

For more information, see https://github.com/CDSoft/bang
```

* `bang` reads `build.lua` and produces `build.ninja`.
* `bang input.lua -o output.ninja` reads `input.lua` and produces `output.ninja`.

## Ninja functions

### Comments

`bang` can add comments to the Ninja file:

``` lua
comment "This is a comment added to the Ninja file"
```

`section` adds comments separated by horizontal lines:

``` lua
section [[
A large title
that can run on several lines
]]
```

### Variables

`var` adds a new variable definition:

``` lua
var "varname" "string value"
var "varname" (number)
var "varname" {"word_1", "word_2", ...} -- will produce `varname = word_1 word_2 ...`
```

The global variable `vars` is a table containing a copy of all the Ninja variables defined by the `var` function.

`var` returns the name of the variable (preffixed with `"$"`).

### Rules

`rule` adds a new rule definition:

``` lua
rule "rule_name" {
    description = "...",
    command = "...",
    -- ...
}
```

Variable values can be strings or lists of strings.
Lists of strings are flattened and concatenated (separated with spaces).

Rules can defined variables (see [Rule variables](https://ninja-build.org/manual.html#ref_rule)).

Bang allows some build statement variables to be defined at the rule level:

- `implicit_in`: list of implicit inputs common to all build statements
- `implicit_out`: list of implicit outputs common to all build statements
- `order_only_deps`: list of order-only dependencies common to all build statements

These variables are added at the beginning of the corresponding variables
in the build statements that use this rule.

The `rule` function returns the name of the rule (`"rule_name"`).

### Build statements

`build` adds a new build statement:

``` lua
build "outputs" { "rule_name", "inputs" }
```

generates the build statement `build outputs: rule_name inputs`.
The first word of the input list (`rule_name`) shall be the rule name applied by the build statement.

The build statement can be added some variable definitions in the `inputs` table:

``` lua
build "outputs" { "rule_name", "inputs",
    varname = "value",
    -- ...
}
```

There are reserved variable names for bang to specify implicit inputs and outputs and dependency orders:

``` lua
build "outputs" { "rule_name", "inputs",
    implicit_out = "implicit outputs",
    implicit_in = "implicit inputs",
    order_only_deps = "order-only dependencies",
    -- ...
}
```

The `build` function returns the outputs (`"outputs"`),
as a string if `outputs` contains a single output
or a list of string otherwise.

### Rules embedded in build statements

Some rules are specific to a single output and are used once.
This leads to write pairs of rules and build statements.

Bang can merge rules and build statements into a single build statement
containing the definition of the associated rule.

A build statement with a `command` variable is split into two parts:

1. a rule with all rule variables found in the build statement definition
2. a build statement with the remaining variables

In this case, the build statement definition does not contain any rule name.

E.g.:

``` lua
build "outputs" { "inputs",
    command = "...",
}
```

is internally translated into:

``` lua
rule "embedded_rule_XXX" {
    command = "...",
}

build "outputs" { "embedded_rule_XXX", "inputs" }
```

Note: `XXX` is a hash computed from the original build statement.

### Default targets

`default` adds targets to the default target:

``` lua
default "target1"
default {"target2", "target3"}
```

### Phony targets

`phony` is a shortcut to `build` that uses the `phony` rule:

``` lua
phony "all" {"target1", "target2"}
-- same as
build "all" {"phony", "target1", "target2"}
```

## Bang functions

### Accumulations

Bang can accumulate names (rules, targets, ...) in a list
that can later be used to define other rules or build statements.

A standard way to do this in Lua would use a Lua table and `table.concat` or the `list[#list+1]` pattern.
Bang provides a simple function to simplify this usage:

``` lua
my_list = {}
-- ...
acc(my_list) "item1"
acc(my_list) {"item2", "item3"}
--...
my_list -- contains {"item1", "item2", "item3"}
```

### File listing

The `ls` function lists files in a directory.
It returns a list of filenames,
with the metatable of [LuaX F lists](https://github.com/CDSoft/luax/blob/master/doc/F.md).

- `ls "path"`: list of file names in `path`
- `ls "path/*.c"`: list of file names matching the "`*.c`" pattern in `path`
- `ls "path/**"`: recursive list of file names in `path`
- `ls "path/**.c"`: recursive list of file names matching the "`*.c`" pattern in `path`

E.g.:

``` lua
ls "doc/*.md"
: foreach(function(doc)
    build (fs.splitext(doc)..".pdf") { "md_to_pdf", doc }
end)
-- where md_to_pdf is a rule to convert Markdown file to PDF
```

### Dynamic file creation

The `file` function creates new files.
It returns an object with a `write` method to add text to a file.
The file is actually written when bang exits successfully.

``` lua
f = file "name" : write("content")
```

The file can be generated incrementally by calling `write` several times:

``` lua
f = file "name"
-- ...
f:write "Line 1"
-- ...
f:write "Line 2"
-- ...
```

### Clean

Bang can generate targets to clean the generated files.
The `clean` function takes a directory name that shall be deleted by `ninja clean`.

``` lua
clean "$builddir"   -- `ninja clean` cleans $builddir
clean "tmp/foo"     -- `ninja clean` cleans /tmp/foo
```

`clean` defines the target `clean` (run by `ninja clean`)
and a line in the help message (see `ninja help`).

In the same vein, `clean.mrproper` takes directories to clean with `ninja mrproper`.

### Install

Bang can generate targets to install files outside the build directories.
The `install` function adds targets to be installed with `ninja install`

The default installation prefix can be set by `install.prefix`:

``` lua
install.prefix "$$HOME/foo/bar"     -- `ninja install` installs to ~/foo/bar
```

The default prefix in `~/.local`.

It can be overridden by the `PREFIX` environment variable when calling Ninja. E.g.:

``` bash
$ PREFIX=~/bar/foo ninja install
```

Artifacts are added to the list of files to be installed by the function `install`.
This function takes the name of the destination directory, relative to the prefix and the file to be installed.

``` lua
install "bin" "$builddir/bang" -- installs bang to $prefix/bin/
```

`install` defines the target `install` (run by `ninja install`)
and a line in the help message (see `ninja help`).

### Help

Bang can generate an help message (stored in a file next to the Ninja file) displayed by `ninja help`.

The help message is composed of three parts:

- a description of the Ninja file
- a list of targets with their descriptions
- an epilog

The description and epilog are defined by the `help.description` and `help.epilog` functions.
Targets can be added by the `help` function. It takes the name of a target and its description.

``` lua
help.description "A super useful Ninja file"
help.epilog "See https://cdelord.fr/bang"
-- ...
help "compile" "Compile every thing"
-- ...
```

Note: the `clean` and `install` target are automatically documented
by the `clean` and `install` functions.

Examples
========

The Ninja file of bang ([`build.ninja`](build.ninja)) is generated by `bang` from [`build.lua`](build.lua).

The [`example`](example) directory contains a larger example:

- source files discovering
- multi-target compilation
- multiple libraries
- multiple executables

License
=======

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

