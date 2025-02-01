generator(false)

pool "bar" { depth=12 }
pool "baz" { depth=12 }
pool "bar" { depth=12 } -- same definition
pool "bar" { depth=42 } -- [test/test-err-multiple_pool.lua:5] ERROR: pool bar: multiple definition
