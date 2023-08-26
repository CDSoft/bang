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

local registered_functions = {}

return setmetatable({}, {
    __call = function(_, f)
        if type(f) ~= "function" then error(tostring(f).." is not a function", 2) end
        table.insert(registered_functions, f)
    end,
    __index = {
        run = function()
            while #registered_functions > 0 do
                table.remove(registered_functions, 1)()
            end
        end,
    },
})
