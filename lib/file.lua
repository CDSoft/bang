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

local fs = require "fs"
local F = require "F"

local file_mt = {__index = {}}

function file_mt.__call(self, ...)
    self.chunks[#self.chunks+1] = {...}
end

-- TODO: remove the write method at the next major release
function file_mt.__index:write(...)
    local log = require "log"
    log.warning("file:write(...) is deprecated, please use file(...) instead")
    self(...)
end

function file_mt.__index:close()
    local new_content = self.chunks:flatten():str()
    local old_content = fs.read(self.name)
    if old_content == new_content then
        return -- keep the old file untouched
    end
    fs.mkdirs(self.name:dirname())
    fs.write(self.name, new_content)
end

local flush_functions = F{}

local function file(name)
    local f = setmetatable({name=name, chunks=F{}}, file_mt)
    flush_functions[#flush_functions+1] = function() f:close() end
    return f
end

return setmetatable({}, {
    __call = function(_, name) return file(name) end,
    __index = {
        flush = function() flush_functions:foreach(F.call) end,
    },
})
