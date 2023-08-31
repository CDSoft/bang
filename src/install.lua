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

local prefix = "$$HOME/.local"
local targets = F{}

local install = {}
local mt = {__index={}}

function install.prefix(dir)
    prefix = dir
end

function mt.__call(_, name)
    return function(sources)
        targets[#targets+1] = F{name=name, sources=sources}
    end
end

function mt.__index:gen()
    if targets:null() then
        return
    end

    section "Installation"

    help "install" ("install $name in $PREFIX or "..(prefix:gsub("^~", "$HOME"):gsub("%$%$", "$")))

    var "prefix" (prefix)

    local rule_names = targets
    : sort(function(a, b) return a.name < b.name end)
    : group(function(a, b) return a.name == b.name end)
    : map(function(target_group)
        local target_name = target_group[1].name
        local rule_name = "install-"..(target_name:gsub("[$/\\%.]+", "_"))
        return build(rule_name) { target_group:map(function(target) return target.sources end),
            description = "INSTALL $in to "..target_name,
            command = { "install -v -D -t", fs.join("$${PREFIX:-$prefix}", target_name), "$in" },
        }
    end)

    phony "install" {rule_names}

end

return setmetatable(install, mt)
