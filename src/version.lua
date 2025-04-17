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
-- https://codeberg.org/cdsoft/bang

--@LOAD

local F = require "F"
local sh = require "sh"
local term = require "term"
local fs = require "fs"

local function version(tag)
    local warning = nil
    local git_tag = fs.stat ".git" and fs.findpath "git" and sh "git describe --tags" : trim()
    if git_tag then
        if tag ~= git_tag then
            local i = F.I {
                build_file = bang.input,
                tag = tag,
                git_tag = git_tag,
            }
            warning = i[[
+---------------------------
| WARNING: version mismatch
|
| Version       : $(tag)
| Latest Git tag: $(git_tag)
|
| Please add a new git tag or fix the version before the next release.
+----------------------------------------------------------------------
]] : trim()
        end
    end
    if warning then
        comment(warning)
        local red = term.isatty(io.stdout)
            and (term.color.white + term.color.onred + term.color.bright)
            or F.id
        print(red(warning))
    end
    var "version" { tag }
    return function(date)
        var "date" { date }
    end
end

return version
