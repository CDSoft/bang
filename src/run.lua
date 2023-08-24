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

local log = require "log"

local tokens = F{
    "# Ninja file generated by bang (https://cdelord.fr/bang)\n",
}

local nbnl = 0

function emit(...)
    tokens[#tokens+1] = {...}
    nbnl = 0
end

function comment(txt)
    emit(txt
        : lines()
        : map(F.prefix "# ")
        : map(string.rtrim) ---@diagnostic disable-line: undefined-field
        : unlines())
end

function nl()
    if nbnl < 1 then
        emit "\n"
    end
    nbnl = nbnl + 1
end

function section(...)
    nl()
    emit(F"#":rep(70), "\n")
    comment(...)
    emit(F"#":rep(70), "\n")
    nl()
end

local function stringify(value)
    return F.flatten{value}:map(tostring):unwords()
end

local nbvars = 0

function var(name)
    return function(value)
        emit(name, " = ", stringify(value), "\n")
        nbvars = nbvars + 1
    end
end

local rule_special_variables = F{
    "description",
    "command",
    "in",
    "in_newline",
    "out",
    "depfile",
    "deps",
    "dyndep",
    "msvc_deps_prefix",
    "generator",
    "restat",
    "rspfile",
    "rspfile_content",
}

local function emit_block_variables(block_variables, opt)
    local is_block_variable = block_variables:from_set(F.const(true))
    block_variables:foreach(function(varname)
        local value = opt[varname]
        if value ~= nil then
            emit("  ", varname, " = ", stringify(value), "\n")
        end
    end)
    F.foreachk(opt, function(varname, value)
        if not is_block_variable[varname] then
            emit("  ", varname, " = ", stringify(value), "\n")
        end
    end)
end

local nbrules = 0

function rule(name)
    return function(opt)
        nl()
        emit("rule ", name, "\n")
        emit_block_variables(rule_special_variables, opt)
        nl()
        nbrules = nbrules + 1
    end
end

local build_special_bang_variables = F{
    "implicit_in",
    "implicit_out",
    "order_only_deps",
}

local nbbuilds = 0

function build(outputs)
    return function(inputs)
        local opt = F.filterk(function(k, _) return type(k) == "string" end, inputs)
        emit("build ",
            stringify(outputs),
            opt.implicit_out and {" | ", stringify(opt.implicit_out)} or {},
            ": ",
            stringify(inputs),
            opt.implicit_in and {" | ", stringify(opt.implicit_in)} or {},
            opt.order_only_deps and {" || ", stringify(opt.order_only_deps)} or {},
            "\n"
        )
        emit_block_variables(F{}, F.without_keys(opt, build_special_bang_variables))
        nbbuilds = nbbuilds + 1
    end
end

function default(targets)
    nl()
    emit("default ", stringify(targets), "\n")
    nl()
end

local function run(args)
    log.info("load ", args.input)
    if not fs.is_file(args.input) then
        log.error(args.input, ": file not found")
    end
    assert(loadfile(args.input, "t"))()
    local ninja = tokens
        : flatten()
        : str()
        : lines()
        : map(string.rtrim)     ---@diagnostic disable-line: undefined-field
        : unlines()
    log.info(nbvars, " variables")
    log.info(nbrules, " rules")
    log.info(nbbuilds, " build statements")
    log.info(#ninja:lines(), " lines")
    log.info(#ninja, " bytes")
    return ninja
end

return run
