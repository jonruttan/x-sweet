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
