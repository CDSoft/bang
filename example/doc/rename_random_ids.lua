#!/usr/bin/env lua

local graph = io.stdin:read "a"
local ids = {}
graph:gsub('"0x[0-9a-f]+"', function(id) ids[#ids+1] = id end)
for i, id in ipairs(ids) do
    graph = graph:gsub(id, "n"..i)
end
io.stdout:write(graph)
