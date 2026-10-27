## define from a nested frame

### binds the top-level name from inside a lambda's frame

```scheme
define %sweet-dg-set
  lambda ()
    define %sweet-dg-probe 7
(%sweet-dg-set)
%sweet-dg-probe
```
---
    7

### and through a frame interposed above it

```scheme
define %sweet-dg-inner
  lambda ()
    define %sweet-dg-deep 9
define %sweet-dg-outer
  lambda ()
    (%sweet-dg-inner)
(%sweet-dg-outer)
%sweet-dg-deep
```
---
    9

### a redefinition at depth updates the top-level cell in place

```scheme
define %sweet-dg-twice 1
define %sweet-dg-again
  lambda ()
    define %sweet-dg-twice 2
(%sweet-dg-again)
%sweet-dg-twice
```
---
    2
