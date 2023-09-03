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
local fs = require "fs"

local function ls(dir)
    local base = fs.basename(dir)
    local path = fs.dirname(dir)
    local recursive = base:match"%*%*"
    local pattern = base:match"%*" and base:gsub("%.", "%%."):gsub("%*%*", "*"):gsub("%*", ".*")

    if recursive then
        return fs.walk(path)
            : filter(function(name) return fs.basename(name):match("^"..pattern.."$") end)
            : sort()
    elseif pattern then
        return fs.dir(path)
            : filter(function(name) return name:match("^"..pattern.."$") end)
            : map(F.partial(fs.join, path))
            : sort()
    else
        return fs.dir(dir)
            : map(F.partial(fs.join, dir))
            : sort()
    end
end

return ls
