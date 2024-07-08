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
local sys = require "sys"

local tmp = require "tmp"

local default_options = {
    builddir = "$builddir/tmp",
    cc = "cc", cflags = {"-c", "-MD -MF $depfile"}, cargs = "$in -o $out",
    depfile = "$out.d",
    cvalid = {},
    ar = "ar", aflags = "-crs", aargs = "$out $in",
    so = "cc", soflags = "-shared", soargs = "-o $out $in",
    ld = "cc", ldflags = {}, ldargs = "-o $out $in",
    c_exts = { ".c" },
    o_ext = ".o",
    a_ext = ".a",
    so_ext = sys.so,
    exe_ext = sys.exe,
    implicit_in = Nil,
}

local rules = setmetatable({}, {
    __index = function(self, compiler)
        local cc = F{compiler.name, "cc"}:flatten():str"-"
        local ar = F{compiler.name, "ar"}:flatten():str"-"
        local so = F{compiler.name, "so"}:flatten():str"-"
        local ld = F{compiler.name, "ld"}:flatten():str"-"
        local new_rules = {
            cc = rule(cc) {
                description = {compiler.name, "$out"},
                command = { compiler.cc, compiler.cflags, compiler.cargs },
                depfile = compiler.depfile,
                implicit_in = compiler.implicit_in,
            },
            ar = rule(ar) {
                description = {compiler.name, "$out"},
                command = { compiler.ar, compiler.aflags, compiler.aargs },
                implicit_in = compiler.implicit_in,
            },
            so = rule(so) {
                description = {compiler.name, "$out"},
                command = { compiler.so, compiler.soflags, compiler.soargs },
                implicit_in = compiler.implicit_in,
            },
            ld = rule(ld) {
                description = {compiler.name, "$out"},
                command = { compiler.ld, compiler.ldflags, compiler.ldargs },
                implicit_in = compiler.implicit_in,
            },
        }
        rawset(self, compiler, new_rules)
        return new_rules
    end
})

local function compile(self, output)
    local cc = rules[self].cc
    return function(inputs)
        local validations = F.flatten{self.cvalid}:map(function(valid)
            local valid_output = output.."-"..(valid.name or valid)..".check"
            if valid.name then
                return valid(valid_output) { inputs }
            else
                return build(valid_output) { valid, inputs }
            end
        end)
        return build(output) { cc, inputs,
            validations = validations,
        }
    end
end

local function static_lib(self, output)
    local ar = rules[self].ar
    return function(inputs)
        return build(output) { ar,
            F.flatten(inputs):map(function(input)
                if F.elem(input:ext(), self.c_exts) then
                    return self:compile(tmp(self.builddir, output, input)..self.o_ext) { input }
                else
                    return input
                end
            end)
        }
    end
end

local function dynamic_lib(self, output)
    local so = rules[self].so
    return function(inputs)
        return build(output) { so,
            F.flatten(inputs):map(function(input)
                if F.elem(input:ext(), self.c_exts) then
                    return self:compile(tmp(self.builddir, output, input)..self.o_ext) { input }
                else
                    return input
                end
            end)
        }
    end
end

local function executable(self, output)
    local ld = rules[self].ld
    return function(inputs)
        return build(output) { ld,
            F.flatten(inputs):map(function(input)
                if F.elem(input:ext(), self.c_exts) then
                    return self:compile(tmp(self.builddir, output, input)..self.o_ext) { input }
                else
                    return input
                end
            end)
        }
    end
end

local compiler_mt

local compilers = {}

local function new(compiler, name)
    if compilers[name] then
        error(name..": compiler redefinition")
    end
    local self = F.merge { compiler, {name=name} }
    compilers[name] = self
    return setmetatable(self, compiler_mt)
end

local function check_opt(name)
    assert(default_options[name], name..": Unknown compiler option")
end

compiler_mt = {
    __call = executable,

    __index = {
        new = new,

        compile = compile,
        static_lib = static_lib,
        dynamic_lib = dynamic_lib,
        executable = executable,

        set = function(self, name)
            check_opt(name)
            return function(value) self[name] = value; return self end
        end,
        add = function(self, name)
            check_opt(name)
            return function(value) self[name] = {self[name], value}; return self end
        end,
    },
}

return new(default_options, "C")
