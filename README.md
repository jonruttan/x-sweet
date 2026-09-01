# x-sweet — sweet-expressions on x-lang

[SRFI-105](https://srfi.schemers.org/srfi-105/) curly infix and
[SRFI-110](https://srfi.schemers.org/srfi-110/) indentation grouping, as a
reader riding on [x-lang](https://github.com/jonruttan/x-lang).

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

x-sweet is a **lang**: a different surface language loaded over an x-lang
dialect. Where x-lang and sweet spell something the same way, sweet is free to
mean something different by it — and here that happens in the *reader* rather
than the vocabulary, before anything is evaluated. The terms are in x-lang's
[lang contract](https://github.com/jonruttan/x-lang/blob/main/docs/lang-contract.md).

## Status

**32 specs, all green** against x-lang **v0.9.0**, and green on every engine
pin since the one carrying the
[#528](https://github.com/jonruttan/x-lang/issues/528) fix.

The floor beneath that pairing is x-lang v0.7.0: `sweet/ws.x` imports
`x/reader/indent`, the shared indentation stack, which exists in no earlier
release. This bundle carried its own copy of that algorithm until then, and the
two disagreed about what a tab is worth.

Second of the five 2024-era langs to come back, after
[x-krn](https://github.com/jonruttan/x-krn). It was chosen next because it is the one that stands on the
*reader* seam rather than the vocabulary — the part of the lang contract
with no coverage and, until this port, no evidence.

## Install

Nothing cloned, from any directory:

```bash
x --install-lang https://github.com/jonruttan/x-sweet/releases/latest/download/lang.pin.xon
x -l sweet
```

x fetches the published pin, then the tarball it names, verifies the digest,
and installs to `<share>/langs/sweet` — where `x -l` looks. A failed upgrade
leaves the working install untouched.

From a clone, if you have one:

```bash
make install                      # into the x on your PATH
PREFIX=$HOME/.local make install  # or a particular prefix
```

`make uninstall` removes it either way. An installed x searches
`<share>/langs/*/lang.xon`, so a lang is installed when its files are there —
no registry, no database.

**One trap, and it is the one you will hit.** `x` decides where to look for
langs from the directory you run it *in*. Inside an **x-lang checkout** it
searches `deps/langs/` and an installed lang is invisible, however correctly it
was installed:

```
$ cd path/to/x-lang && x -l sweet
Error: no library, app or lang named 'sweet'
  searched lib/sweet.x, apps/sweet/run.x
      and deps/langs/*/lang.xon
```

Run it from anywhere else, or name the bundles explicitly — `X_LANG_DIR` wins
in both modes:

```bash
X_LANG_DIR=$HOME/.local/share/x/langs/ x -l sweet   # the installed one
X_LANG_DIR=/path/to/x-sweet/.. x -l sweet           # a checkout, uninstalled
```


## Pin it instead, for a project

An install is unversioned and machine-wide. When it matters *which* version a
project builds against, pin it: `Pin bundle` fetches the release tarball and
verifies it against a digest before unpacking. In the project's
`lang.pin.xon`:

```x
(lang "sweet")
(release "v0.1.2")
(bundle "sha256:…" "https://github.com/jonruttan/x-sweet/releases/download/v0.1.2/x-sweet-v0.1.2.tar.gz")
(source "https://github.com/jonruttan/x-sweet.git")
```

Each release publishes its own digest, and the release notes carry this block
ready to paste. Then:

```x-repl
> (import x/tool/pin)
> (Pin bundle "deps/langs")
"deps/langs/sweet-v0.1.2"
```

`deps/langs/` is where `x -l` looks in a checkout. `X_LANG_DIR` overrides it.

**Which to use.** Install when you just want `x -l sweet` to work. Pin when a
build depends on it — the digest is what makes the version reproducible, and
an install has none.

## Running it

```bash
x -l sweet                    # interactive
x -l sweet -f program.sweet   # batch
```

x-lang boots the dialect `lang.xon` declares, arms this bundle's module root,
and loads `run.x` on top — which is why nothing here needs to know a path.

**Mind the arm.** Everything structural has to be defined *before*
`(%sweet-arm!)` and merely called after it — see
[the rule this lang adds](#the-rule-this-lang-adds), which is the one thing
that will bite you silently.

## Development

Run the specs against any x-lang checkout or install:

```bash
X=/path/to/x-lang/x.sh make test   # the suite
make bundle                        # roll a release tarball and print its pin
```

**Pass `X` explicitly.** Without it the suite takes the `x` on your PATH, and an
installed x that trails the checkout reports failures the platform has already
fixed.

**Do not `make install` into an x-lang checkout.** The Makefile asks
`$(X) --share-dir` where to put the bundle, and a checkout answers with its own
root — so the files land in `<checkout>/langs/NAME`, which is not one of the
three paths `-l` searches there. It reports success and the lang stays
invisible. Install into a real `<share>` tree, or use `X_LANG_DIR`.


This suite runs in the runner's **direct mode**, and it is the only bundle that
does: the standard mode wraps each snippet in `(begin …)`, and parentheses
override indentation, so SRFI-110 cannot be tested through it.
`tests/gen-harness.sh` writes the generated harness that shims it — see
[Upstream notes](#upstream-notes).

The release tarball is byte-reproducible: it is built from the tag with
`git archive` and a timestamp-free gzip, so two people rolling one tag get one
digest. Pushing a `v*` tag runs the suite and, only if it is green, publishes
the tarball, its `.sha256` and `lang.pin.xon` as a GitHub release. CI runs the
declared release *and* x-lang `main`, so a platform that moves underneath this
bundle shows up as a red build rather than a surprise later.

## Layout

```
lang.xon     what this bundle is: name, dialect, release pairing
run.x               the entry -- and it knows no paths at all
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
lang of the five depend on the two largest — neither of them ported.
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

## The rule this lang adds

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

Two of them, both in machinery that exists specifically for this lang:

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

## Background

Sweet-expressions come from David A. Wheeler's *Readable Lisp S-expressions
Project*: the claim that Lisp can keep homoiconicity while losing the
parentheses people bounce off. The discipline that makes it more than
syntax-flavouring is that every notation is a strict generalization of
s-expressions — any ordinary s-expression is still read unchanged, and the new
forms only add meaning where none existed. Both notations were standardized as
Scheme SRFIs by Wheeler and Alan Manuel K. Gloria: curly infix in 2012,
indentation grouping in 2013.

- [Readable Lisp S-expressions Project](https://readable.sourceforge.io/) — rationale, tutorials, history
- [SRFI-105](https://srfi.schemers.org/srfi-105/) — curly-infix-expressions (2012)
- [SRFI-110](https://srfi.schemers.org/srfi-110/) — sweet-expressions (2013)

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
