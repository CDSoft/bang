#!/usr/bin/env luax

local fs = require "fs"

local depth = 2
local N = 10
local Nlibs = 100

local main = assert(arg[1], "Missing argument")
local root = fs.dirname(main)

local function gen(base, level)
    if level == 0 then
        for i = 1, N do
            local h = base/tostring(i)..".h"
            local c = base/tostring(i)..".c"
            local k = "k_" .. c : sub(#root+2, -1) : splitext() : gsub("[/.-]+", "_")
            assert(fs.write(h, "extern const int "..k..";\n"))
            assert(fs.write(c, "#include \""..h:basename().."\"\nconst int "..k.." = 42;\n"))
        end
    else
        for i = 1, N do
            local d = base/tostring(i)
            fs.mkdir(d)
            gen(d, level-1)
        end
    end
end

for i = 1, Nlibs do
    fs.mkdir(root/"lib-"..tostring(i))
    gen(root/"lib-"..tostring(i), depth)
end

assert(fs.write(root/"main.c", [[
int main(void) {
    return 0;
}
]]))
