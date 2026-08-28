# x-sweet — sweet-expressions on x-lang

[SRFI-105](https://srfi.schemers.org/srfi-105/) curly infix and
[SRFI-110](https://srfi.schemers.org/srfi-110/) indentation grouping, as a
reader riding on x-lang.

```
$ x -l sweet
define factorial
  lambda (n)
    if {n <= 1}
      1
      {n * (factorial {n - 1})}

factorial 5
120
```

Both notations are reader-level: `{a + b}` reads as `(+ a b)`, and a line
indented under another becomes its child. Nothing is rewritten at eval time.

## Status

31 specs, all green against x-lang **0.5.2** / x-engine-c **v0.1.2**, and
still green on the engine carrying the
[#528](https://github.com/jonruttan/x-lang/issues/528) fix.

Second of the five 2024-era personalities to come back, after
[x-krn](../x-krn). It was chosen next because it is the one that stands on the
*reader* seam rather than the vocabulary — the part of the personality contract
with no coverage and, until this port, no evidence.

## Running it

The spec suite needs nothing but an `x` it can find:

```bash
X=/path/to/x-lang/x.sh sh tests/spec-runner.sh
```

A prompt needs the same bridge x-krn does, for the same reason
([x-lang#519](https://github.com/jonruttan/x-lang/issues/519)): `-l` has no
personality-root step yet, so point the platform at this bundle —

```bash
ln -s "$PWD" /path/to/x-lang/apps/sweet
```

— and run from the x-lang repo root:

```bash
./x.sh -l sweet                    # interactive
./x.sh -l sweet -f program.sweet   # batch
```

## Layout

```
personality.xon     what this bundle is: name, dialect, release pairing
run.x               THE entry -- the only file that may know a path
sweet/ws.x          the whitespace token both SRFIs stand on
sweet/curly.x       SRFI-105
sweet/indent.x      SRFI-110
sweet/printer.x     Scheme's `write`, which is not x's
sweet/scheme.x      the eight Scheme names the specs use -- a placeholder
sweet/base.x        assembles the parts, and holds the loop
```

## What porting it actually cost

Far more than x-krn, and almost none of it where the contract predicts.

**The compiler dependency turned out to be optional.** The 2024 reader compiled
its tokenizer callbacks to native code through `compile-batch`, which forced
every state cell to be a hand-declared GC root (`heap-mark-root!`).
`compile-batch` is gone; `heap-mark-root!` only moved, to `(Heap mark-root!)`.
But `lib/x/num/float.x` is a live worked
example of a reader type written in plain closures — its `analyse` returns
further closures to advance a state machine — and a whitespace scanner is
cheaper than a float parser. Dropping the compilation dropped the root problem
with it: ordinary bindings are traced. Reach for `compile` again when a
measurement asks, not before.

**`first-chars` was removed, not renamed.** The tokenizer now iterates every
registered type and scores its `analyse` hook, so the leading-character
prefilter has no equivalent — you just omit it. `make-type` is
`(prim-ref 'type 'make)`.

**The R7RS dependency was a dependency on eight names.** `sweet-base.x` opened
with `(include "lang/r7rs/lib/r7rs-base.x")`, which made the smallest
personality of the five depend on the two largest — neither of them ported.
What it actually needed was `define`, `lambda`, `begin`, `car`/`cdr`/`cons`,
`else` and `equal?`. `sweet/scheme.x` is those, and is meant to be deleted:
when x-r5rs lands as a bundle, it becomes `(import r5rs/base)`. A placeholder
that says it is one beats a blocked port, and beats rewriting the specs into x
— which would have changed what the suite tests.

**Three bugs were mine, and they are the interesting ones.**

*The sentinel has to be both unique and self-evaluating.* Once a whitespace
type is registered it fires everywhere, including inside `(...)`, and whatever
its reader returns lands in the list being built. The 2024 reader returned
`#t`, "self-evaluating, so the C eval loop handles it harmlessly" — true
between top-level forms, and not true inside a list, where it cannot be told
from a `#t` the program wrote. That file already carried a `%ws-mark` sentinel
and a `strip-ws` to remove it; nothing ever returned the mark, so the stripper
had no work and the `#t` stayed. But a *pair* sentinel is worse, not better: it
leaks to the top-level eval between arming and the loop and dies as
`Unbound SYMBOL`. A fresh **string** is both — x compares strings by identity,
so it cannot be forged, and it evaluates to itself, so a leak is inert.

*The signal is the value, not a flag.* This was the hardest one. The 2024
design set a "whitespace fired" flag and had the grouping loop test it after
every read. A whitespace run *inside* a `(...)` sets that flag too — the C
reader reads that list's elements itself — so the grouping loop would see an
ordinary token with the flag up, conclude a line had ended, and silently
discard the form:

```scheme
(define x
  42)
x        ; => Unbound SYMBOL 'x
```

The returned sentinel has no such problem: it belongs to the read that produced
it. A nested run returns its mark into the list the C reader is building, where
the stripper removes it, and the outer loop never sees it.

*`%set-cell-int!` on an ordinary pair corrupts the heap.* The obvious modern
spelling of 2024's `atom-val`/`atom-set!` is `%cell-int`/`%set-cell-int!`.
They write a raw machine word into an object's first slot — fine on the
C-created cells every platform caller uses them on, fatal on a `(list 0)`,
whose slot 0 the collector traces as a pointer. Filed as
[x-lang#522](https://github.com/jonruttan/x-lang/issues/522); the fix here is
`%set-first!`, which is traced, with small integers as immediates so the
arithmetic still allocates nothing.

## The rule this personality adds

**After `(%sweet-arm!)`, the stream may contain only single-line forms.**

Arming changes how the very next character is tokenized. A multi-line form read
after that point has sentinels injected among its elements. In a body sequence
that is invisible — the sentinel is self-evaluating. In an arity-sensitive form
it is silent and fatal:

```scheme
(if (null? %r) () (%seq ...))       ; becomes
(if "mark" (null? %r) "mark" () "mark" (%seq ...))
```

which takes the wrong branch and prints nothing at all. No error, no output, a
suite that fails every test with an empty result. Everything structural —
including the read-eval-print loop — is therefore defined *before* the arm and
merely called after it.

## Upstream notes

Two beyond the [x-krn set](../x-krn/README.md#three-things-upstream-should-know),
both in machinery that exists specifically for this personality:

**The runner's direct mode has been dead since a rename**
([x-lang#523](https://github.com/jonruttan/x-lang/issues/523)).
`tests/spec-runner.awk` has a branch whose comment reads "Used by Sweet where
indentation-based grouping must see raw newlines/tokens" — it is the only way
to run this bundle's suite, because the standard mode wraps every snippet in
`(begin ... )` and parentheses override indentation. That branch emits
`(heap-collect)` between snippets, and the bare global was renamed to the
`Heap` class without the awk being updated, so it raises `Unbound SYMBOL` on
every snippet boundary. `tests/gen-harness.sh` shims it.

**`READ_FN` and `REPL_CMD` are the seam that makes this bundle testable at
all**, and neither is in the contract's seam table — the same gap as
`%repl-print` and `%repl-read`
([x-lang#518](https://github.com/jonruttan/x-lang/issues/518)).

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
