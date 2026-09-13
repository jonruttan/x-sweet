#!/bin/sh
# # x-sweet -- the Sweet lang for x-lang
#
# ## tests/spec-runner.sh -- the bundle's runner
#
# @description Sources the platform's spec runner; vendors nothing.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# No path reaches into an x-lang source tree; everything comes from x itself.
# --share-dir gives the tree x reads from (repo root in a checkout, share/x
# when installed) and --engine-path gives the engine location after the
# wrapper's discovery order.
#
# Set X to point at a particular x; otherwise the one on PATH is used.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-sweet: no x on PATH.  Set X=/path/to/x.sh and retry." >&2
	exit 1
}

# --share-dir answers from any cwd.
X_ROOT="$("$X" --share-dir)"
# X_BIN is env-overridable, the way tests/x/spec-runner.sh makes it -- so the
# same runner can drive a variant or patched engine without moving anything.
X_BIN="${X_BIN:-$("$X" --engine-path)}"

# The platform runner locates its awk harness relative to the engine binary,
# which sits beside tests/ in a checkout but under libexec/x in an install; a
# sourced script cannot portably find its own path, so the caller sets this.
SPEC_RUNNER_DIR="$X_ROOT/tests"
export SPEC_RUNNER_DIR

# The harness is generated, never committed: it embeds two absolute paths
# that are facts of this machine, not of the bundle.
sh "$BUNDLE/tests/gen-harness.sh" "$X_ROOT" "$BUNDLE"

LANG_LIB="$BUNDLE/tests/lib/harness.gen.x"
# SPEC_PATH is env-overridable so a single spec file can be run in isolation
# while diagnosing, without moving anything into the suite.
SPEC_PATH="${SPEC_PATH:-$BUNDLE/tests/specs}"

# The suite boots from a state image of the harness when the platform can
# write one. tools/dev/image-build.sh images a child that loaded the harness,
# keyed on everything it depends on (the harness, the platform's lib/, its
# engine, and sweet/), so an edit to any of them rewrites the image and a
# current one is reused. Each spec file then loads the image instead of
# booting from source.
#
# The image writer is a checkout tool: an installed tree has none, and a
# library holding words no image can carry is refused; either way the suite
# boots from source and says so on stderr.
#
# The `Ansi repl-own` probe checks for a specific platform fix rather than a
# version: a platform whose Ansi.install moves a REPL printer it does not own
# takes this bundle's %repl-print away when the image loads (x-lang#655), and
# specs then run on the wrong printer. Boot from source on a platform that
# answers no.
#
# IMG=0 runs the same suite from source, one file per process, for when the
# image is the suspect.
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

# A unit here is an indented block, not an s-expression, so the runner reads
# with the lang's own reader (READ_FN, a seam in tests/spec-runner.awk).
READ_FN="sweet-read"; export READ_FN

# Direct mode. The standard mode wraps every snippet as `(begin ... )`, and
# parentheses override indentation in SRFI-110, so it would flatten exactly
# what this suite tests. REPL_CMD=" " selects direct mode; the harness supplies
# its own loop (see tests/gen-harness.sh).
REPL_CMD=" "; export REPL_CMD

. "$X_ROOT/tests/spec-runner.sh"
