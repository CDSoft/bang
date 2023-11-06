#!/bin/bash

# This file is part of bang.
#
# bang is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# bang is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with bang.  If not, see <https://www.gnu.org/licenses/>.
#
# For further information about bang you can visit
# https://cdelord.fr/bang

# Use the Lua sources of bang to generate the build.ninja file
# that will be used to compile and test bang...

set -e

# set LUA search path to load modules that will later live in the bang executable
export LUA_PATH="src/?.lua;lib/?.lua"

# Load bang libraries that would be automatically loaded by LuaX
declare -a LOAD_LIBS=()
declare -a LIBS=(lib/*.lua)
for lib in "${LIBS[@]}"
do
    lib=${lib%.lua} # remove the .lua extension
    lib=${lib##*/}  # remove the path name
    LOAD_LIBS+=("-l" "$lib")
done

# Call LuaX to run bang as if it were already compiled
luax "${LOAD_LIBS[@]}" src/bang.lua build.lua -o build.ninja

# Finally run ninja on the newly created ninja file
ninja -f build.ninja
