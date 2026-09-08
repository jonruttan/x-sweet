#!/bin/sh
# # x-sweet -- the Sweet personality for x-lang
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

# --share-dir answers from ANY cwd as of x-lang 990c4a35.  It did not at first:
# mode detection is cwd-based, so a checkout's x.sh asked from outside took the
# installed branch and computed a share/x no checkout has.  This runner used to
# cd to the wrapper's own directory before asking -- the guessing the flag
# exists to end.  Reported, fixed upstream, dance removed.
X_ROOT="$("$X" --share-dir)"
# X_BIN is env-overridable, the way tests/x/spec-runner.sh makes it -- so the
# same runner can drive a variant or patched engine without moving anything.
X_BIN="${X_BIN:-$("$X" --engine-path)}"

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

# THE SUITE BOOTS FROM A STATE IMAGE OF THE HARNESS, when the platform can
# write one.  tools/dev/image-build.sh images a child that loaded the harness
# and keys that image on everything it depends on -- the harness, the
# platform's lib/, its engine, and sweet/ (the KEY-PATH) -- so an edit to any of
# them rewrites it, and a current one is skipped.  Each spec file then loads
# the image instead of booting the platform from source.
#  THE WRITER IS A CHECKOUT TOOL.  An installed tree has no image-build.sh,
# and a library holding words no image can carry is refused; both say so on
# stderr and the suite boots from source exactly as it did before.
#  AND A PROBE FOR THE FIX, NOT FOR A VERSION.  A platform whose Ansi.install
# moves a REPL printer it does not own takes this bundle's %repl-print away
# when the image loads (x-lang#655) -- a few specs then differ in how a value
# prints, or, worse, none do and the suite passes on the platform's printer.
# The fix carries `Ansi repl-own`; ask the platform for it rather than for a
# version, and boot from source on one that answers no.
#  IMG=0 IS THE CONTROL -- the same suite from source, for when the image is
# the suspect.  One file per process there too, so the boot is the only thing
# that differs between the two runs.
if [ "${IMG:-1}" = 0 ]; then
	SPEC_BATCH="${SPEC_BATCH:-1}"; export SPEC_BATCH
else
	_builder="$X_ROOT/tools/dev/image-build.sh"
	_probe="${TMPDIR:-/tmp}/x-imgprobe.$$.x"
	printf '(Ansi repl-own)\n' > "$_probe"
	_keeps_printer=0
	"$X" -f "$_probe" >/dev/null 2>&1 && _keeps_printer=1
	rm -f "$_probe"
	if [ ! -f "$_builder" ]; then
		echo "x-sweet: no image writer at $_builder (not a checkout) -- the suite boots from source" >&2
	elif [ "$_keeps_printer" = 0 ]; then
		echo "x-sweet: the platform moves a REPL printer it does not own (x-lang#655) -- the suite boots from source" >&2
	elif X_BIN="$X_BIN" sh "$_builder" "$LANG_LIB" "$BUNDLE/tests/lib/.images" "$BUNDLE/sweet"; then
		X_IMG_DIR="$BUNDLE/tests/lib/.images"; export X_IMG_DIR
	else
		echo "x-sweet: no state image -- the suite boots from source" >&2
	fi
fi

# READ ONE UNIT THE SWEET WAY.  A "unit" here is an indented block, not an
# s-expression, so the whole point of the lang is in the reader.  READ_FN has
# been in tests/spec-runner.awk since the format was written, and it is why a
# lang with its own reader can share the platform's runner at all.
READ_FN="sweet-read"; export READ_FN

# DIRECT MODE.  The standard mode wraps every snippet as `(begin ... )`, and
# parentheses override indentation in SRFI-110 -- so the wrapper silently
# flattens exactly what this suite tests.  REPL_CMD=" " selects the branch the
# platform's awk added for this lang; the harness supplies its own loop in
# exchange.  See tests/gen-harness.sh.
REPL_CMD=" "; export REPL_CMD

. "$X_ROOT/tests/spec-runner.sh"
