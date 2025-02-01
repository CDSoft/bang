generator(false)

rule "foo" { command = true }
rule "bar" { command = true }

build "bar" { "foo" }
build "baz" { "foo" }
build "bar" { "foo" } -- same definition
build "bar" { "bar" } -- [test/test-err-multiple_build.lua:7] ERROR: build bar: multiple definition
