#!/usr/bin/env luax

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
local fs = require "fs"

local ninja = require "ninja"
local log = require "log"
local _, version = pcall(require, "version")

local function parse_args()
    local parser = require "argparse"()
        : name "bang"
        : description(F.unlines {
            "Ninja file generator",
            "",
            "Arguments after \"--\" are given to the input script",
        } : rtrim())
        : epilog "For more information, see https://github.com/CDSoft/bang"

    parser : flag "-v"
        : description(('Print Bang version ("%s")'):format(version))
        : action(function() print(version); os.exit() end)

    parser : flag "-q"
        : description "Quiet mode (no output on stdout)"
        : target "quiet"

    parser : option "-g"
        : description "Set a custom command for the generator rule"
        : argname "cmd"
        : target "gen_cmd"

    parser : option "-o"
        : description "Output file (default: build.ninja)"
        : argname "output"
        : target "output"

    parser : argument "input"
        : description "Lua script (default: build.lua)"
        : args "0-1"

    local bang_arg, script_arg = F.break_(F.partial(F.op.eq, "--"), arg)
    local args = F.merge{
        { cli_args = arg },
        { input="build.lua", output="build.ninja" },
        parser:parse(bang_arg),
    }

    _G.arg = script_arg : drop(1)
    _G.arg[0] = args.input

    return args
end

local args = parse_args()
log.config(args)
package.path = package.path..";"..args.input:dirname().."/?.lua"
local ninja_file = ninja(args)
log.info("write ", args.output)
require "file" : flush()
fs.write(args.output, ninja_file)
