## include path import

### multi-line defs in an imported module bind their values

```scheme
import x/codec/hex
Hex encode "hi"
```
---
    "6869"

## include path resume

### indentation and curly still group after an import

```scheme
import x/codec/hex
define y
  + 40 {1 + 1}
y
```
---
    42

## include by path

### a file included at the prompt binds its names there

```scheme
include (%module-resolve-file "tests/fixtures/include-plain.x")
include-plain-sum
```
---
    42
