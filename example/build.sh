#!/bin/bash

set -e

echo "Recompile bang"
cd "$(dirname "$0")" || exit 1
( cd .. && ./boot.lua && ninja ) # just ensure bang is uptodate
echo ""

echo "Compile the Bang example"
../.build/bang
ninja #-d explain
