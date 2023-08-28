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

local product_name = ""
local description = F{}
local epilog = F{}
local targets = F{}

local help = {}
local mt = {__index={}}

local function i(s)
    return s : gsub("%$name", product_name)
end

function help.name(txt)
    product_name = txt
end

function help.description(txt)
    description[#description+1] = i(txt:rtrim())
end

function help.epilog(txt)
    epilog[#epilog+1] = i(txt:rtrim())
end

function help.target(name)
    return function(txt)
        targets[#targets+1] = F{name=name, txt=i(txt)}
    end
end

function mt.__call(_, ...)
    return help.target(...)
end

function mt.__index:gen(args)
    if description:null() and epilog:null() and targets:null() then
        return
    end

    local help_filename = fs.splitext(fs.basename(args.output))..".hlp"
    local help_dir = fs.dirname(args.output)

    local f = file(fs.join(help_dir, help_filename))
    if not description:null() then
        f:write(description:unlines())
        if not targets:null() or not epilog:null() then
            f:write("\n")
        end
    end
    if not targets:null() then
        table.insert(targets, 1, {name="help", txt="show this help message"})
        local w = targets:map(function(t) return #t.name end):maximum()
        local function justify(s) return s..(" "):rep(w-#s) end
        f:write("Targets:\n")
        targets:foreach(function(target)
            f:write(("  %s   %s\n"):format(justify(target.name), target.txt))
        end)
        if not epilog:null() then
            f:write("\n")
        end
    end
    if not epilog:null() then
        f:write(epilog:unlines())
    end

    section "Help"

    rule "help" {
        description = "$in",
        command = "cat $in",
    }

    build "help" { "help", help_filename }

end

return setmetatable(help, mt)
