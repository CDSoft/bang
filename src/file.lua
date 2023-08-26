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

local atexit = require "atexit"
local fs = require "fs"
local F = require "F"

local file_mt = {__index = {}}

function file_mt.__index:write(...)
    self.chunks[#self.chunks+1] = {...}
end

function file_mt.__index:close()
    fs.mkdirs(fs.dirname(self.name))
    local f = assert(io.open(self.name, "w"))
    f:write(self.chunks:flatten():unpack())
    f:close()
end

local function file(name)
    local f = setmetatable({name=name, chunks = F{}}, file_mt)
    atexit(function() f:close() end)
    return f
end

return file
