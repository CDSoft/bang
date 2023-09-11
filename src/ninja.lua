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

--@LIB

local F = require "F"
local fs = require "fs"
local atexit = require "atexit"
local crypt = require "crypt"

local log = require "log"
local ident = require "ident"

local tokens = F{
    "# Ninja file generated by bang (https://cdelord.fr/bang)\n",
    "\n",
}

local nbnl = 1

function emit(...)
    tokens[#tokens+1] = {...}
    nbnl = 0
end

function comment(txt)
    emit(txt
        : lines()
        : map(F.prefix "# ")
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
    return F.flatten{value}
    : map(tostring)
    : map(string.trim) ---@diagnostic disable-line: undefined-field
    : unwords()
end

local nbvars = 0

vars = {}

function var(name)
    return function(value)
        value = stringify(value)
        emit(name, " = ", value, "\n")
        vars[name] = value
        nbvars = nbvars + 1
        return "$"..name
    end
end

local rule_variables = F{
    "description",
    "command",
    "in",
    "in_newline",
    "out",
    "depfile",
    "deps",
    "dyndep",
    "pool",
    "msvc_deps_prefix",
    "generator",
    "restat",
    "rspfile",
    "rspfile_content",
}

local build_special_bang_variables = F{
    "implicit_in",
    "implicit_out",
    "order_only_deps",
}

-- { "rule_name" = {implicit_in=..., implicit_out=...}, ...}
local inherited_variables = {
    phony = {},
}

local nbrules = 0

function rule(name)
    return function(opt)
        nl()

        emit("rule ", name, "\n")

        -- list of variables belonging to the rule definition
        rule_variables : foreach(function(varname)
            local value = opt[varname]
            if value ~= nil then emit("  ", varname, " = ", stringify(value), "\n") end
        end)

        -- list of variables belonging to the associated build statements
        inherited_variables[name] = {}
        build_special_bang_variables : foreach(function(varname)
            inherited_variables[name][varname] = opt[varname]
        end)

        -- other variables are unknown
        local unknown_variables = F.keys(opt)
            : difference(rule_variables)
            : difference(build_special_bang_variables)
        if #unknown_variables > 0 then
            error("rule "..name..": unknown variables: "..unknown_variables:str", ")
        end

        nl()
        nbrules = nbrules + 1

        return name
    end
end

local nbbuilds = 0

function build(outputs)
    return function(inputs)
        -- variables defined in the current build statement
        local build_opt = F.filterk(function(k, _) return type(k) == "string" end, inputs)

        if build_opt.command then
            -- the build statement contains its own rule
            -- => create a new rule for this build statement only
            local rule_name = ident(stringify(outputs)) .. "-" .. crypt.hash(F.show{outputs, inputs})
            local rule_opt = F.restrict_keys(build_opt, rule_variables)
            rule(rule_name)(rule_opt)
            build_opt = F.without_keys(build_opt, rule_variables)

            -- add the rule name to the actuel build statement
            inputs = {rule_name, inputs}
        end

        -- variables defined at the rule level and inherited by this statement
        local rule_name = F{inputs}:flatten():head():words():head()
        local rule_opt = inherited_variables[rule_name]
        if not rule_opt then
            log.error(rule_name..": unknown rule")
        end

        -- merge both variable sets
        local opt = F.clone(rule_opt)
        build_opt:foreachk(function(varname, value)
            opt[varname] = opt[varname] and {opt[varname], value} or value
        end)

        emit("build ",
            stringify(outputs),
            opt.implicit_out and {" | ", stringify(opt.implicit_out)} or {},
            ": ",
            stringify(inputs),
            opt.implicit_in and {" | ", stringify(opt.implicit_in)} or {},
            opt.order_only_deps and {" || ", stringify(opt.order_only_deps)} or {},
            "\n"
        )

        F.without_keys(opt, build_special_bang_variables)
        : foreachk(function(varname, value)
            emit("  ", varname, " = ", stringify(value), "\n")
        end)

        nbbuilds = nbbuilds + 1

        outputs = stringify(outputs):words()
        return #outputs ~= 1 and outputs or outputs[1]
    end
end

local pool_variables = F{
    "depth",
}

function pool(name)
    return function(opt)
        emit("pool ", name, "\n")
        pool_variables : foreach(function(varname)
            local value = opt[varname]
            if value ~= nil then emit("  ", varname, " = ", stringify(value), "\n") end
        end)
        local unknown_variables = F.keys(opt) : difference(pool_variables)
        if #unknown_variables > 0 then
            error("pool "..name..": unknown variables: "..unknown_variables:str", ")
        end
        return name
    end
end

function default(targets)
    nl()
    emit("default ", stringify(targets), "\n")
    nl()
end

function phony(outputs)
    return function(inputs)
        return build(outputs) {"phony", inputs}
    end
end

return function(args)
    log.info("load ", args.input)
    if not fs.is_file(args.input) then
        log.error(args.input, ": file not found")
    end
    assert(loadfile(args.input, "t"))()
    install:gen()
    clean:gen()
    help:gen() -- help shall be generated after clean and install
    atexit.run()
    local ninja = tokens
        : flatten()
        : str()
        : lines()
        : map(string.rtrim) ---@diagnostic disable-line: undefined-field
        : drop_while_end(string.null) ---@diagnostic disable-line: undefined-field
        : unlines()
    log.info(nbvars, " variables")
    log.info(nbrules, " rules")
    log.info(nbbuilds, " build statements")
    log.info(#ninja:lines(), " lines")
    log.info(#ninja, " bytes")
    return ninja
end