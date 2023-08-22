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

# Install bang to ~/.local (or $1)

DIRECTORIES="bin"

ninja

PREFIX="$1"
test -d "$PREFIX" || PREFIX="$HOME/.local"

if ! [ -d "$PREFIX" ]
then
    echo "\$PREFIX not defined or missing directory"
    exit 1
fi

for dir in $DIRECTORIES
do
    install --verbose --compare -D --target-directory="$PREFIX"/$dir .build/$dir/*
done
