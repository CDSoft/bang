generator(false)

rule "foo" {}

build "bar" { "foo" }
build "baz" { "foo" }
build "bar" { "foo" } -- [test/test-err-multiple_build.lua:7] ERROR: build bar: multiple definition
