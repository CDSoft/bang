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

--@LOAD

local F = require "F"
local targets = require "targets"
    : map(function(t) return {t.name, t} end)
    : from_list()

local function target(target_spec)
    if type(target_spec) == "string" then target_spec = {target_spec} end
    if type(target_spec) == "table" then
        local names, other_args = F.partition(function(name) return targets[name] end, target_spec)
        if #names == 1 then return targets[names:head()], other_args end
        if #names > 1 then F.error_without_stack_trace("multiple target definition", 1) end
        return nil, F(target_spec)
    end
    F.error_without_stack_trace("target() expects a string or a list of strings", 1)
end

return target
