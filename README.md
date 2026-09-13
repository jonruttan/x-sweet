# x-sweet — sweet-expressions on x-lang

<p align="center"><img src="docs/bitwise-banner.svg" alt="x-sweet, with Bitwise the owl" width="100%"></p>

[SRFI-105](https://srfi.schemers.org/srfi-105/) curly infix and
[SRFI-110](https://srfi.schemers.org/srfi-110/) indentation grouping,
implemented as a reader for [x-lang](https://github.com/jonruttan/x-lang).

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

x-sweet is a **lang**: a surface syntax loaded over an x-lang dialect, so a
spelling shared with x-lang can mean something different here. The terms are
in x-lang's
[lang contract](https://github.com/jonruttan/x-lang/blob/main/docs/lang-contract.md).

## Status

34 specs, all green against x-lang **v0.13.0**, the release `lang.xon`
declares. x-lang v0.7.0 or later is required: `sweet/ws.x` imports
`x/reader/indent`, which exists in no earlier release.

## Install

From any directory, nothing cloned:

```bash
x --install-lang https://github.com/jonruttan/x-sweet/releases/latest/download/lang.pin.xon
x -l sweet
```

x fetches the published pin, then the tarball it names, verifies the digest,
and installs to `<share>/langs/sweet`, where `x -l` looks. A failed upgrade
leaves the working install untouched.

From a clone:

```bash
make install                      # into the x on your PATH
PREFIX=$HOME/.local make install  # or a particular prefix
```

`make uninstall` removes it either way. An installed x searches
`<share>/langs/*/lang.xon`; a lang is installed when its files are there.
There is no registry.

`x` resolves langs relative to the directory it runs in. Inside an x-lang
checkout it searches `deps/langs/` only, so an installed lang is not found
there:

```
$ cd path/to/x-lang && x -l sweet
Error: no library, app or lang named 'sweet'
  searched lib/sweet.x, apps/sweet/run.x
      and deps/langs/*/lang.xon
```

Run `x` from another directory, or set `X_LANG_DIR`, which takes precedence in
both cases:

```bash
X_LANG_DIR=$HOME/.local/share/x/langs/ x -l sweet   # the installed one
X_LANG_DIR=/path/to/x-sweet/.. x -l sweet           # a checkout, uninstalled
```

## Pin it for a project

An install is unversioned and machine-wide. When a project must build against
a specific version, pin it: `Pin bundle` fetches the release tarball and
verifies it against a digest before unpacking. In the project's
`lang.pin.xon`:

```x
(lang "sweet")
(release "v0.1.5")
(bundle "sha256:…" "https://github.com/jonruttan/x-sweet/releases/download/v0.1.5/x-sweet-v0.1.5.tar.gz")
(source "https://github.com/jonruttan/x-sweet.git")
```

Each release's notes carry this block with its digest, ready to paste. Then:

```x-repl
> (import x/tool/pin)
> (Pin bundle "deps/langs")
"deps/langs/sweet-v0.1.5"
```

`deps/langs/` is where `x -l` looks in a checkout; `X_LANG_DIR` overrides it.

Install when you just want `x -l sweet` to work. Pin when a build depends on
it: the digest is what makes the version reproducible.

## Running it

```bash
x -l sweet                    # interactive
x -l sweet -f program.sweet   # batch
```

x-lang boots the dialect `lang.xon` declares, arms this bundle's module root,
and loads `run.x` on top.

## Development

Run the specs against an x-lang checkout or install:

```bash
X=/path/to/x-lang/x.sh make test   # the suite
make bundle                        # roll a release tarball and print its pin
```

Pass `X` explicitly: without it the suite takes the `x` on your PATH, and an
installed x that trails the checkout reports failures the platform has already
fixed.

Do not `make install` into an x-lang checkout. The Makefile asks
`$(X) --share-dir` where to put the bundle, and a checkout answers with its own
root, so the files land in `<checkout>/langs/sweet`, which `-l` does not
search there. The install reports success and the lang is still not found.
Install into a real `<share>` tree, or use `X_LANG_DIR`.

The suite runs in the spec runner's direct mode: the standard mode wraps each
snippet in `(begin …)`, and parentheses override indentation, so SRFI-110
cannot be tested through it. `tests/gen-harness.sh` writes the generated
harness.

The release tarball is byte-reproducible: it is built from the tag with
`git archive` and a timestamp-free gzip, so the same tag always yields the same
digest. Pushing a `v*` tag runs the suite and, only if it is green, publishes
the tarball, its `.sha256` and `lang.pin.xon` as a GitHub release. CI runs the
declared release and x-lang `main`, so a platform change that breaks this
bundle shows up as a red build.

## Layout

```
lang.xon            name, dialect, and the x-lang release this pairs with
run.x               the entry point
sweet/ws.x          the whitespace token both SRFIs build on
sweet/curly.x       SRFI-105
sweet/indent.x      SRFI-110
sweet/printer.x     Scheme-style `write`
sweet/scheme.x      the eight Scheme bindings the specs need (placeholder)
sweet/base.x        assembles the parts; the loop and the include seam
```

## Background

Sweet-expressions come from David A. Wheeler's *Readable Lisp S-expressions
Project*. Every notation is a strict generalization of s-expressions: any
ordinary s-expression is still read unchanged, and the new forms only add
meaning where none existed. Both were standardized as Scheme SRFIs by Wheeler
and Alan Manuel K. Gloria: curly infix in 2012, indentation grouping in 2013.

- [Readable Lisp S-expressions Project](https://readable.sourceforge.io/) — rationale, tutorials, history
- [SRFI-105](https://srfi.schemers.org/srfi-105/) — curly-infix-expressions (2012)
- [SRFI-110](https://srfi.schemers.org/srfi-110/) — sweet-expressions (2013)

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).

<p align="center"><img src="docs/bitwise-mark.svg" alt="Bitwise" width="96"></p>
