#!/bin/sh
# # x-sweet -- sweet-expressions for x-lang
#
# ## tests/spec-runner.sh -- the bundle's runner
#
# @description Sources the PLATFORM's spec runner; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# NOT ONE PATH INTO THE X-LANG SOURCE TREE.  The 2024 runner reached the
# platform as "$SCRIPT_DIR/../../../tests/spec-runner.sh" and both that and
# its X_BIN dangled the moment the personality left the repo -- the failure
# x-lang docs/personality-contract.md calls "addressing, not sharing".
# Everything here comes from x itself: --share-dir says which tree x reads
# from (repo root in a checkout, share/x installed) and --engine-path says
# where the engine is after the wrapper's full discovery order.
#
# Set X to point at a particular x; otherwise the one on PATH is used.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-sweet: no x on PATH.  Set X=/path/to/x.sh and retry." >&2
	exit 1
}

# ASKED FROM THE WRAPPER'S OWN DIRECTORY, and that is not a stylistic choice.
# x.sh detects repo mode by testing for lib/x.x under the CWD, so --share-dir
# answers with `pwd` in a checkout -- correct only when the caller already
# stands in the x-lang repo, which a bundle by definition does not.  Asked
# from anywhere else a checkout's wrapper reports
#   Error: install root does not exist: .../x-lang/../share/x
# and the flag whose own comment says it exists "so a tool outside this
# repository can ASK instead of guessing" cannot be asked from outside.
#
# cd'ing to the wrapper's directory first makes the detection true for both
# modes: a checkout's x.sh sits beside lib/x.x, and an installed x sits in
# bin/ where lib/x.x is absent, so the install branch runs as designed.
# Reported upstream; remove this dance once --share-dir answers from any cwd.
_x_dir="$(cd "$(dirname "$(command -v "$X")")" && pwd)"
X_ROOT="$(cd "$_x_dir" && "$X" --share-dir)"
# X_BIN is env-overridable, the way tests/x/spec-runner.sh makes it -- so the
# same runner can drive a variant or patched engine without moving anything.
X_BIN="${X_BIN:-$(cd "$_x_dir" && "$X" --engine-path)}"

# REQUIRED FROM AN INSTALLED TREE.  The runner finds its awk harness from the
# directory holding the ENGINE -- true in a checkout, where the binary sits
# beside tests/, and false in an install, where the engine is under libexec/x.
# A sourced script cannot portably find its own path, so the caller says.
SPEC_RUNNER_DIR="$X_ROOT/tests"
export SPEC_RUNNER_DIR

# The harness is GENERATED, never committed: it embeds two absolute paths
# that are facts of this machine, not of the bundle.
sh "$BUNDLE/tests/gen-harness.sh" "$X_ROOT" "$BUNDLE"

LANG_LIB="$BUNDLE/tests/lib/harness.gen.x"
# SPEC_PATH is env-overridable so a single spec file can be run in isolation
# while diagnosing, without moving anything into the suite.
SPEC_PATH="${SPEC_PATH:-$BUNDLE/tests/specs}"

# READ ONE UNIT THE SWEET WAY.  The platform runner reads each spec's input
# with `Io read` by default; for this bundle a "unit" is an indented block,
# not an s-expression, so the whole point of the personality is in the reader.
# READ_FN is the seam that makes that expressible -- it has been in
# tests/spec-runner.awk since the format was written, and it is why a
# personality with its own reader can share the platform's runner at all.
#
# The 2024 runner set READ_FN=%test-read, a helper that skipped whitespace
# tokens and returned raw ones.  That exercised the curly layer and could not
# have exercised the indentation layer at all -- with no grouping, `define x`
# over an indented `42` is three separate reads.  sweet-read is the real entry.
READ_FN="sweet-read"; export READ_FN

# DIRECT MODE.  The platform's runner wraps every snippet as `(begin ... )` in
# its standard mode, and parentheses override indentation -- so the wrapper
# silently flattens exactly what this bundle exists to test.  REPL_CMD=" "
# selects the branch tests/spec-runner.awk added for this personality; the
# harness supplies its own loop in exchange.  See tests/gen-harness.sh.
REPL_CMD=" "; export REPL_CMD

. "$X_ROOT/tests/spec-runner.sh"
