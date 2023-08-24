#!/usr/bin/env lua

-- Ninja generates ids that looks like random arbitrary addresses
-- which produces a different graph even when the ninja file is unchanged.
-- This script replaces these addresses with deterministic ids.

local graph = io.stdin:read "a"
local ids = {}
graph:gsub('"0x[0-9a-f]+"', function(id) ids[#ids+1] = id end)
for i, id in ipairs(ids) do
    graph = graph:gsub(id, tostring(i))
end
io.stdout:write(graph)
