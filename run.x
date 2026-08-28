; # x-sweet -- sweet-expressions for x-lang
;
; ## run.x -- THE entry, and the only file here that may know a path
;
; @description Sweet-expressions: SRFI-105 curly infix ({a + b}) and SRFI-110
;   indentation grouping, over a thin Scheme surface.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;     ., .,
;     {O,O}
;     (   )
;      " "
;
; Usage today (until `-l` grows a personality-root step, see README):
;   x.sh -F path/to/x-sweet/run.x     interactive
;   x.sh -f path/to/x-sweet/run.x     batch, program on stdin
;
; THE ONE FILE WITH LAYOUT KNOWLEDGE.  Every other file in this bundle
; resolves its siblings by `import`, so the bundle relocates.  That rule is
; the whole reason the last generation of personalities died -- see
; x-lang docs/personality-contract.md, "Why the last generation rotted".
(include "lib/x-core.x")

; --- Where this bundle lives ------------------------------------------------
; THE ENTRY CANNOT ASK.  x.sh CATS the entry into the engine's stdin rather
; than including it, so inside this file %include-curdir is "." and
; %install-root is unbound in a checkout.  An entry has no way to learn its
; own path -- which is why Logo's names its root with a literal and why the
; contract exempts entries from the path-literal lint.  Logo can get away
; with one literal because Logo lives INSIDE the platform tree; a bundle,
; by definition, does not.  That gap is the "searched personality root,
; extended by one step" the contract still lists as proposed.
;
; So: probe, and say so when nothing answers.  Every candidate below is a
; place a bundle actually sits today; the list shrinks to one line the day
; -l learns a personality root.
(def %sweet-entry-candidates
  (list
    ; installed tree, or a checkout with apps/sweet symlinked at the bundle
    (guard (_ "apps/sweet") (%path-join %install-root "apps/sweet"))
    ; checkout, cwd at the repo root -- what `x.sh -l sweet` gives today
    "apps/sweet"
    ; the entry was INCLUDED rather than piped (a harness, or `include`)
    (guard (_ ".") (%include-curdir))))
(def %sweet-entry-find-root
  (fn (self roots)
    (if (null? roots)
      ()
      (if (Sys file-exists? (%path-join (first roots) "sweet/base.x"))
        (first roots)
        (self (rest roots))))))
(def %sweet-entry-bundle-root (%sweet-entry-find-root %sweet-entry-candidates))
(if (null? %sweet-entry-bundle-root)
  (do
    ; Legible, not a bare "include: cannot open".  A refusal that names what
    ; it looked for is the difference between a five-minute fix and the
    ; afternoon the last generation of these cost.
    (display "x-sweet: cannot find the bundle root -- no sweet/base.x under:")
    (newline)
    (def %sweet-entry-say
      (fn (self roots)
        (if (null? roots)
          ()
          (do
            (display "  ")
            (display (%path-join (first roots) "sweet/base.x"))
            (newline)
            (self (rest roots))))))
    (%sweet-entry-say %sweet-entry-candidates)
    (display "Run from the x-lang repo root with apps/sweet pointing here, or")
    (newline)
    (display "install the bundle under <install-root>/apps/sweet.")
    (newline)
    (Sys exit 1))
  ())
(import-path! %sweet-entry-bundle-root)

(import sweet/base)

(set! %repl-prompt "")
(set! %lang-name "Sweet Expressions")
(set! %lang-version sweet-version)
; Scheme results, not x's round-trippable ones -- see sweet/printer.x.
(set! %repl-print %sweet-repl-print)

; ARMED LAST, AND NOTHING STRUCTURAL MAY FOLLOW.  Registering SWEET-WS changes
; how the very next character of input is tokenized, so any multi-line form
; read after this point has whitespace sentinels injected into it -- silent and
; fatal in an arity-sensitive form.  See the note in sweet/base.x.  Everything
; below is one line each, deliberately.
(%sweet-arm!)
(unless %batch? (%banner))
(%sweet-run)
