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

--@LIB

local F = require "F"
local fs = require "fs"
local atexit = require "atexit"

local log = require "log"
local ident = require "ident"
local flatten = require "flatten"

local pairs = pairs
local tostring = tostring
local type = type

local words = string.words

local clone = F.clone
local difference = F.difference
local filterk = F.filterk
local foreach = F.foreach
local foreachk = F.foreachk
local keys = F.keys
local map = F.map
local restrict_keys = F.restrict_keys
local unwords = F.unwords
local values = F.values
local without_keys = F.without_keys

local ninja_required_version_for_bang = F"1.11.1"

local help_token = {}
local install_token = {}
local command_line_token = {}

local tokens = F{
    "# Ninja file generated by bang (https://github.com/cdsoft/bang)\n",
    command_line_token,
    "\n",
    help_token,
    install_token,
}

local nbnl = 1
local nb_tokens = #tokens

function emit(x)
    nb_tokens = nb_tokens + 1
    tokens[nb_tokens] = x
    nbnl = 0
end

local function comment_line(line)
    if #line == 0 then return "#" end
    return "# "..line
end

function comment(txt)
    emit(txt
        : lines()
        : map(comment_line)
        : unlines())
end

function nl()
    if nbnl < 1 then
        emit "\n"
    end
    nbnl = nbnl + 1
end

local token_separator = F"#":rep(70).."\n"

function section(txt)
    nl()
    emit(token_separator)
    comment(txt)
    emit(token_separator)
    nl()
end

local function stringify(value)
    return unwords(map(tostring, flatten{value}))
end

local nbvars = 0

local vars = {}
local function expand(s)
    if type(s) == "string" then
        for _ in pairs(vars) do
            local s1 = s:gsub("%$([%w_%-]+)", vars)
            if s1 == s then break end
            s = s1
        end
        return s
    end
    if type(s) == "table" then
        return map(expand, s)
    end
    log.error("vars.expand expects a string or a list of strings")
end

_G.vars = setmetatable(vars, { __index = {expand = expand} })

function var(name)
    return function(value)
        if vars[name] then
            log.error("var "..name..": multiple definition")
        end
        value = stringify(value)
        emit(name.." = "..value.."\n")
        vars[name] = value
        nbvars = nbvars + 1
        return "$"..name
    end
end

local ninja_required_version_token = { ninja_required_version_for_bang }

nl()
emit { "ninja_required_version = ", ninja_required_version_token, "\n" }
nl()

function ninja_required_version(required_version)
    local current = ninja_required_version_token[1] : split "%." : map(tonumber)
    local new = required_version : split "%." : map(tonumber)
    for i = 1, #new do
        current[i] = current[i] or 0
        if new[i] > current[i] then ninja_required_version_token[1] = required_version; return end
        if new[i] < current[i] then return end
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

local is_build_special_bang_variable = build_special_bang_variables
    : map2t(function(name) return name, true end)

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
    return function(opt)
        if rules[name] then
            log.error("rule "..name..": multiple definition")
        end
        if opt.command == nil then
            log.error("rule "..name..": expected 'command' attribute")
        end

        new_rule(name)
        nbrules = nbrules + 1

        nl()

        emit("rule "..name.."\n")

        -- list of variables belonging to the rule definition
        rule_variables : foreach(function(varname)
            local value = opt[varname]
            if value ~= nil then emit("  "..varname.." = "..stringify(value).."\n") end
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
    local prefix = name.."-"
    local i = 0
    while rules[rule_name] do
        i = i + 1
        rule_name = prefix..i
    end
    return rule_name
end

local function defined(x)
    return x and #x>0
end

local builds = {}

local default_build_statements = {}
local custom_default_statement = false

local nbbuilds = 0

local function build_decorator(build)
    local self = {}
    local mt = {
        __call = build,
        __index = {},
    }
    local archivers = require "archivers"
    mt.__index.archivers = archivers
    F.foreachk(archivers, function(name, archiver) mt.__index[name] = archiver end)
    local C = require "C"
    mt.__index.C = C
    F.foreachk(C, function(name, compiler) mt.__index[name] = compiler end)
    mt.__index.luax = require "luax"
    local builders = require "builders"
    F.foreachk(builders, function(name, builder) mt.__index[name] = builder end)
    mt.__index.new = function(...) return builders:new(...) end
    mt.__index.files = function(predicate)
        local p
        if type(predicate) == "string" then
            p = function(name, rule)
                return name:has_prefix(predicate) and rule ~= "phony"
            end
        elseif type(predicate) == "function" then
            p = function(name, rule)
                return predicate(name, rule) and rule ~= "phony"
            end
        elseif type(predicate) == "nil" then
            p = function(_, rule) return rule ~= "phony" end
        else
            log.error("build.files expects a string or a function")
        end
        return F.filterk(p, builds) : keys()
    end
    return setmetatable(self, mt)
end

build = build_decorator(function(_, outputs)
    outputs = stringify(outputs)
    return function(inputs)
        -- variables defined in the current build statement
        local build_opt = filterk(function(k, _) return type(k) == "string" and not k:has_prefix"$" end, inputs)
        local no_default = inputs["$no_default"]

        if build_opt.command then
            -- the build statement contains its own rule
            -- => create a new rule for this build statement only
            local rule_name = unique_rule_name(ident(outputs))
            local rule_opt = restrict_keys(build_opt, rule_variables)
            rule(rule_name)(rule_opt)
            build_opt = without_keys(build_opt, rule_variables)

            -- add the rule name to the actuel build statement
            inputs = {rule_name, inputs}
        end

        -- variables defined at the rule level and inherited by this statement
        local rule_name = flatten{inputs}:head():words():head()
        if not rules[rule_name] then
            log.error(rule_name..": unknown rule")
        end
        local rule_opt = rules[rule_name].inherited_variables

        -- merge both variable sets
        local opt = clone(rule_opt)
        foreachk(build_opt, function(varname, value)
            opt[varname] = opt[varname]~=nil and {opt[varname], value} or value
        end)

        emit("build "
            ..outputs
            ..(defined(opt.implicit_out) and " | "..stringify(opt.implicit_out) or "")
            ..": "
            ..stringify(inputs)
            ..(defined(opt.implicit_in) and " | "..stringify(opt.implicit_in) or "")
            ..(defined(opt.order_only_deps) and " || "..stringify(opt.order_only_deps) or "")
            ..(defined(opt.validations) and " |@ "..stringify(opt.validations) or "")
            .."\n"
        )

        foreachk(opt, function(varname, value)
            if not is_build_special_bang_variable[varname] then
                emit("  "..varname.." = "..stringify(value).."\n")
            end
        end)

        nbbuilds = nbbuilds + 1

        local output_list = words(outputs)
        foreach(output_list, function(output)
            if builds[output] then
                log.error("build "..output..": multiple definition")
            end
            builds[output] = rule_name
        end)
        if not no_default then
            default_build_statements[#default_build_statements+1] = output_list
        end
        return #output_list ~= 1 and output_list or output_list[1]
    end
end)

local pool_variables = F{
    "depth",
}

local pools = {}

function pool(name)
    return function(opt)
        if pools[name] then
            log.error("pool "..name..": multiple definition")
        end
        pools[name] = true
        emit("pool "..name.."\n")
        foreach(pool_variables, function(varname)
            local value = opt[varname]
            if value ~= nil then emit("  "..varname.." = "..stringify(value).."\n") end
        end)
        local unknown_variables = difference(keys(opt), pool_variables)
        if #unknown_variables > 0 then
            log.error("pool "..name..": unknown variables: "..unknown_variables:str", ")
        end
        return name
    end
end

function default(targets)
    local default_targets = stringify(targets)
    if default_targets ~= "" then
        custom_default_statement = true
        nl()
        emit("default "..default_targets.."\n")
        nl()
    end
end

local function generate_default()
    if custom_default_statement then return end
    if require"clean".default_target_needed()
    or require"help".default_target_needed()
    or require"install".default_target_needed()
    then
        section "Default targets"
        default(default_build_statements)
    end
end

function phony(outputs)
    return function(inputs)
        return build(outputs) {"phony", inputs,
            ["$no_default"] = inputs["$no_default"],
        }
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

    local bang_cmd = args.gen_cmd or
        filterk(function(k)
            return math.type(k) == "integer" and k <= 0
        end, args.cli_args) : values() : unwords()

    local command_line = F{
        bang_cmd,
        args.quiet and "-q" or {},
        "$in -o $out",
        #_G.arg > 0 and {"--", _G.arg} or {},
    }

    local bang = rule(unique_rule_name "bang") {
        command = command_line,
        generator = true,
    }

    local deps = values(package.modpath)
    if not deps:null() then
        generator_flag.implicit_in = flatten{ generator_flag.implicit_in or {}, deps }
            : nub()
            : difference { args.input }
    end

    acc(command_line_token) {
        "# "..flatten(command_line):unwords()
            : gsub("%$in", args.input)
            : gsub("%$out", args.output),
        "\n",
    }

    build(args.output) (F.merge{
        { ["$no_default"] = true },
        { bang, args.input },
        generator_flag,
    })
end

local function size(x)
    local s = #x
    if s > 1024*1024 then return s//(1024*1024), " MB" end
    if s > 1024 then return s//1024, " kB" end
    return s, " bytes"
end

return function(args)
    log.info("load ", args.input)
    if not fs.is_file(args.input) then
        log.error(args.input, ": file not found")
    end
    _G.bang = F.clone(args)
    assert(loadfile(args.input, "t"))()
    atexit.run()
    install:gen(install_token)
    clean:gen()
    help:gen(help_token) -- help shall be generated after clean and install
    generator_rule(args)
    generate_default()
    local ninja = flatten(tokens) : str()
    log.info(nbvars, " variables")
    log.info(nbrules, " rules")
    log.info(nbbuilds, " build statements")
    log.info(size(ninja))
    return ninja
end
