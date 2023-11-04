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
local where = require "where"

local log = require "log"
local ident = require "ident"

local tokens = F{
    "# Ninja file generated by bang (https://cdelord.fr/bang)\n",
    "\n",
}

local nbnl = 1

function emit(x)
    tokens[#tokens+1] = x
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
    emit { F"#":rep(70), "\n" }
    comment(...)
    emit { F"#":rep(70), "\n" }
    nl()
end

local trim_word = F.compose {
    string.trim, ---@diagnostic disable-line: undefined-field
    tostring,
}

local function stringify(value)
    return F.flatten{value}
    : map(trim_word)
    : unwords()
end

local function check_at_exit(predicate, error_message)
    local loc = where()
    atexit(function()
        if not predicate() then
            log.error_at(loc, error_message)
        end
    end)
end

local nbvars = 0

vars = {}

function var(name)
    check_at_exit(function() return vars[name] ~= nil end, "var "..name..": incomplete definition")
    return function(value)
        if vars[name] then
            log.error("var "..name..": multiple definition")
        end
        value = stringify(value)
        emit { name, " = ", value, "\n" }
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
    "validations",
}

local rules = {
--  "rule_name" = {
--      inherited_variables = {implicit_in=..., implicit_out=...}
--  }
}

local function new_rule(name)
    rules[name] = { inherited_variables = {} }
end

new_rule "phony"

local nbrules = 0

function rule(name)
    check_at_exit(function() return rules[name] ~= nil end, "rule "..name..": incomplete definition")
    return function(opt)
        if rules[name] then
            log.error("rule "..name..": multiple definition")
        end

        new_rule(name)
        nbrules = nbrules + 1

        nl()

        emit { "rule ", name, "\n" }

        -- list of variables belonging to the rule definition
        rule_variables : foreach(function(varname)
            local value = opt[varname]
            if value ~= nil then emit { "  ", varname, " = ", stringify(value), "\n" } end
        end)

        -- list of variables belonging to the associated build statements
        build_special_bang_variables : foreach(function(varname)
            rules[name].inherited_variables[varname] = opt[varname]
        end)

        -- other variables are unknown
        local unknown_variables = F.keys(opt)
            : difference(rule_variables)
            : difference(build_special_bang_variables)
        if #unknown_variables > 0 then
            log.error("rule "..name..": unknown variables: "..unknown_variables:str", ")
        end

        nl()

        return name
    end
end

local function unique_rule_name(name)
    local rule_name = name
    local i = 0
    while rules[rule_name] do
        i = i + 1
        rule_name = F{name, i}:str"-"
    end
    return rule_name
end

local builds = {}

local nbbuilds = 0

function build(outputs)
    outputs = stringify(outputs)
    check_at_exit(function()
        return F(outputs):words():all(function(output) return builds[output] ~= nil end)
    end, "build "..outputs..": incomplete definition")
    return function(inputs)
        -- variables defined in the current build statement
        local build_opt = F.filterk(function(k, _) return type(k) == "string" end, inputs)

        if build_opt.command then
            -- the build statement contains its own rule
            -- => create a new rule for this build statement only
            local rule_name = unique_rule_name(ident(outputs))
            local rule_opt = F.restrict_keys(build_opt, rule_variables)
            rule(rule_name)(rule_opt)
            build_opt = F.without_keys(build_opt, rule_variables)

            -- add the rule name to the actuel build statement
            inputs = {rule_name, inputs}
        end

        -- variables defined at the rule level and inherited by this statement
        local rule_name = F{inputs}:flatten():head():words():head()
        if not rules[rule_name] then
            log.error(rule_name..": unknown rule")
        end
        local rule_opt = rules[rule_name].inherited_variables

        -- merge both variable sets
        local opt = F.clone(rule_opt)
        build_opt:foreachk(function(varname, value)
            opt[varname] = opt[varname]~=nil and {opt[varname], value} or value
        end)

        emit { "build ",
            outputs,
            opt.implicit_out and {" | ", stringify(opt.implicit_out)} or {},
            ": ",
            stringify(inputs),
            opt.implicit_in and {" | ", stringify(opt.implicit_in)} or {},
            opt.order_only_deps and {" || ", stringify(opt.order_only_deps)} or {},
            opt.validations and {" |@ ", stringify(opt.validations)} or {},
            "\n",
        }

        F.without_keys(opt, build_special_bang_variables)
        : foreachk(function(varname, value)
            emit { "  ", varname, " = ", stringify(value), "\n" }
        end)

        nbbuilds = nbbuilds + 1

        local output_list = outputs:words()
        output_list : foreach(function(output)
            if builds[output] then
                log.error("build "..output..": multiple definition")
            end
            builds[output] = true
        end)
        return #output_list ~= 1 and output_list or output_list[1]
    end
end

local pool_variables = F{
    "depth",
}

local pools = {}

function pool(name)
    check_at_exit(function() return pools[name] ~= nil end, "pool "..name..": incomplete definition")
    return function(opt)
        if pools[name] then
            log.error("pool "..name..": multiple definition")
        end
        pools[name] = true
        emit { "pool ", name, "\n" }
        pool_variables : foreach(function(varname)
            local value = opt[varname]
            if value ~= nil then emit { "  ", varname, " = ", stringify(value), "\n" } end
        end)
        local unknown_variables = F.keys(opt) : difference(pool_variables)
        if #unknown_variables > 0 then
            log.error("pool "..name..": unknown variables: "..unknown_variables:str", ")
        end
        return name
    end
end

function default(targets)
    nl()
    emit { "default ", stringify(targets), "\n" }
    nl()
end

function phony(outputs)
    return function(inputs)
        return build(outputs) {"phony", inputs}
    end
end

local generator_flag = {}
local generator_called = false

function generator(flag)
    if generator_called then
        log.error("generator: multiple call")
    end
    generator_called = true

    if flag == nil or flag == true then
        flag = {}
    end

    if type(flag) ~= "boolean" and type(flag) ~= "table" then
        log.error("generator: boolean or table expected")
    end

    generator_flag = flag
end

local function generator_rule(args)
    if not generator_flag then return end

    section(("Regenerate %s when %s changes"):format(args.output, args.input))

    local bang = rule(unique_rule_name "bang") {
        command = "bang $quiet $in -o $out -- $args",
        generator = true,
    }

    build(args.output) (F.merge{
        { bang, args.input,
            quiet = args.quiet and "-q" or nil,
            args = #_G.arg > 0 and _G.arg or nil,
        },
        generator_flag,
    })
end

return function(args)
    log.info("load ", args.input)
    if not fs.is_file(args.input) then
        log.error(args.input, ": file not found")
    end
    _G.bang = F.clone(args)
    assert(loadfile(args.input, "t"))()
    install:gen()
    clean:gen()
    help:gen() -- help shall be generated after clean and install
    generator_rule(args)
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
