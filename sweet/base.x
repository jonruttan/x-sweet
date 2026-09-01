; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/base.x -- the language, assembled
;
; @description SRFI-105 (curly infix) and SRFI-110 (indentation) over a thin
;   Scheme surface.  Loads the parts and arms the readers.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; No path literals and no dialect boot here: run.x owns both.  The 2024
; sweet-base.x ended with a bare (sweet-repl) call, so merely LOADING the
; language started a session -- which is why its own spec harness could not
; load it without one, and why the file could never be imported by anything
; else.  A launcher is an entry's job.

(import sweet/printer)
(import sweet/scheme)
(import sweet/ws)
(import sweet/curly)
(import sweet/indent)

(provide sweet/base sweet-read sweet-version %sweet-arm! %sweet-repl-print
  %sweet-run)

(def sweet-version "0.1.0")

; ARMING IS A VERB.  Registering a reader type changes how every subsequent
; character of input is tokenized, including the rest of the file doing the
; registering.  Making that an explicit call rather than a load side effect is
; what lets a harness import the grouping logic without the reader underneath
; it changing -- and it is the difference between a bundle that can be tested
; and one that can only be run.
(def %sweet-arm!
  (fn (_)
    (%sweet-curly-register!)
    (%sweet-ws-register!)
    (%sweet-ws-reset!)
    ()))

; --- The include seam --------------------------------------------------------
; INCLUDED FILES ARE PLAIN X, AND THE READER MUST KNOW IT.  Once armed, the
; sweet types fire on every buffer -- including the module files `include`
; hands to the C loader, which reads and evaluates forms itself: no
; sweet-read, no %sweet-strip-ws, nobody to clean up.  A top-level sentinel
; there is inert (self-evaluating, same as the stream case above), but one
; INSIDE a multi-line form is not: (import x/tool/profile) read
; (def %prof-kv\n  (fn ...)) as (def %prof-kv <mark> (fn ...)), bound the name
; to the sentinel string, and evaluating the mangled neighbors segfaulted the
; engine (2026-09-01).  Single-line defs in the same file read fine, which is
; what made it look like anything but the reader.
;
; So: front `include` with a wrapper that suspends both sweet types for the
; duration of the load.  `import`, include-once and import-version all funnel
; through the `include` BINDING (see lib/x/boot/module.x -- set! mutates the
; slot every resolution path reads, which is also why set! and not def), so
; one seam covers every module load.  The -f program and the launcher never
; pass through here: x.sh cats both onto stdin, where sweet-read strips.
;
; ONCE, GUARDED THE WAY module.x GUARDS ITS OWN WRAPPER: a second capture
; would make %sweet-include-raw the wrapper itself, and include would then
; recurse forever -- module.x:160 documents that exact segfault.  The flag is
; an x-side catalog value, which the ISA manifest check deliberately ignores.
;
; The guard re-raises: an error mid-load must still reach the session's
; handler, but with the depth restored first -- a permanently suspended
; reader turns every later multi-line entry into an EOF-length read.
(if (null? (prim-ref (lit module) (lit sweet-include-wrapped)))
  (do
    (prim-reg! (lit module) (lit sweet-include-wrapped) (pair () ()))
    (def %sweet-include-raw include)
    (set! include
      (fn (_ path)
        (%sweet-suspend!)
        (guard (err (%sweet-resume!) (error err))
          (def %sweet-include-result (%sweet-include-raw path))
          (%sweet-resume!)
          %sweet-include-result))))
  ())

; SCHEME'S `write`, INSTALLED.  sweet/printer.x explains why a personality
; rebinds it; here is the one line that makes it the surface's meaning.  Done
; at load, not at arm time: it is a vocabulary decision, not a reader one.
(def write %sweet-write)

; --- The loop ----------------------------------------------------------------
; DEFINED HERE, WHICH IS TO SAY BEFORE ANYTHING IS ARMED, and that ordering is
; a correctness requirement rather than a preference.
;
; Once SWEET-WS is registered it fires on every whitespace run containing a
; newline, INCLUDING the runs inside a multi-line `(...)` form.  The C reader
; builds that list without knowing about our type, so each such run leaves a
; sentinel among the elements.  sweet/ws.x's stripper cleans the forms this
; personality reads -- but nothing cleans the forms the PLATFORM's top-level
; loop reads out of the same stream.
;
; In a body sequence the damage is invisible: the sentinel is a self-evaluating
; string, so (op () e "mark" (def r ...) "mark" (display r)) still runs.  In an
; arity-sensitive form it is silent and fatal:
;
;   (if (null? %r) () (%seq ...))   read after arming, becomes
;   (if "mark" (null? %r) "mark" () "mark" (%seq ...))
;
; which takes the wrong branch and prints nothing at all -- no error, no
; output, a suite that fails every test with an empty result.  That cost an
; afternoon, so it is written down here.
;
; THE RULE: after (%sweet-arm!), the stream may contain only single-line forms.
; Everything structural is defined before it.
(def %sweet-run
  (op () %E
    (def %r (sweet-read))
    (if (null? %r)
      ()
      (%seq
        (guard (err (%seq (display "Error: ") (%seq (display err) (newline))))
          (%repl-print (eval! %r)))
        (%sweet-run)))))
