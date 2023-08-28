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
local help = require "help"

local clean = {}
local mt = {__index={}}

local directories_to_clean = F{}

local builddir = "$builddir"

function mt.__call(_, dir)
    if #directories_to_clean == 0 then
        help "clean" "clean generated files"
    end
    directories_to_clean[#directories_to_clean+1] = dir
end

function mt.__index:gen()

    if #directories_to_clean > 0 then

        section("Clean")

        local targets = directories_to_clean : map(function(dir)
            local rule_name = "clean-"..(dir:gsub("[$/\\%.]+", "_"))

            rule(rule_name) {
                description = {"CLEAN ", dir},
                command = {"rm -rf ", dir..(dir==builddir and "/*" or "")},
            }

            build(rule_name) { rule_name }

            return rule_name
        end)

        phony "clean" (targets)

    end

end

return setmetatable(clean, mt)
