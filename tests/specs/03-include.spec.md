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
