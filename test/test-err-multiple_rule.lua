generator(false)

rule "foo" {}
rule "bar" {}
rule "baz" {}
rule "foo" {} -- [test/test-err-multiple_rule.lua:6] ERROR: rule foo: multiple definition
