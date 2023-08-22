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

local run = require "run"
local log = require "log"

local function parse_args()
    local parser = require "argparse"()
        : name "bang"
        : description "Ninja file generator"
        : epilog "For more information, see https://github.com/CDSoft/bang"

    parser : flag "-q"
        : description "Quiet mode (no output on stdout)"

    parser : option "-o"
        : description "Output file (default: build.ninja)"
        : argname "output"
        : target "output"

    parser : argument "input"
        : description "Lua script (default: build.lua)"
        : args "0-1"

    return F.merge{
        { input="build.lua", output="build.ninja" },
        parser:parse(),
    }
end

local args = parse_args()
log.quiet(args)
local ninja = run(args)
log.info("write ", args.output)
fs.write(args.output, ninja)
