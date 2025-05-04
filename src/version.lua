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

local function git_warning(tag)
    if not fs.stat ".git" then return end
    if not fs.findpath "git" then return end
    local git_tag = sh "git describe --tags"
    if not git_tag then return end
    git_tag = git_tag : trim()
    if tag == git_tag then return end
    return F.I { tag=tag, git_tag=git_tag } [[
+----------------------------------------------------------------------+
| WARNING: version mismatch                                            |
|                                                                      |
| Version : $(tag:ljust(58)                                          ) |
| Git tag : $(git_tag:ljust(58)                                      ) |
|                                                                      |
| Please add a new git tag or fix the version before the next release. |
+----------------------------------------------------------------------+
]] : trim()
end

local function version(tag)
    local warning = git_warning(tag)
    if warning then
        comment(warning)
        local red = term.isatty(io.stdout)
            and (term.color.white + term.color.onred + term.color.bright)
            or F.id
        print(warning:lines():map(red):unlines())
    end
    var "version" { tag }
    return function(date)
        var "date" { date }
    end
end

return version
