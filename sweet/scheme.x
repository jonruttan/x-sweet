; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/scheme.x -- the Scheme names the notation is written in
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A PLACEHOLDER, AND SAYING SO IS THE POINT.  SRFI-105 and SRFI-110 are
; Scheme SRFIs, and this bundle's specs are written in Scheme -- `define`,
; `lambda`, `null?`.  The 2024 tree got those by opening with
;
;   (include "lang/r7rs/lib/r7rs-base.x")
;
; which made the smallest personality depend on the two largest, neither of
; which is ported.  That is a real dependency, but it is a dependency on the
; *alias layer*, not on R7RS: nothing in sweet-expressions needs `dynamic-wind`
; or a numeric tower.  The specs need eight names.
;
; So this file is those eight, and it is meant to be DELETED.  When x-r5rs
; lands as a bundle, personality.xon grows a dependency on it and this file
; becomes `(import r5rs/base)`.  Until then, a placeholder that is honest
; about being one beats a blocked port -- and beats quietly rewriting the
; specs into x, which would have changed what the suite tests.
;
; Everything here is a thin operative over an x form.  None of it is a
; contribution to what Scheme means; x-r5rs is the arbiter of that.

(provide sweet/scheme define lambda begin)

; `lambda`: Scheme's formals have no receiver, x's `fn` does -- (lambda (n) ...)
; is (fn (_ n) ...).  Splicing the `_` in is the whole of the difference.
(def lambda
  (op (formals . body)
    e
    (eval (pair (lit fn) (pair (pair (lit _) formals) body)) e)))

; `define`, in both its spellings.  This used to put its eval in TAIL position
; so TCO would pop the operative's frame first and leave the binding global --
; fragile, because one extra frame anywhere up the chain made every definition
; vanish silently.  (base def-global) takes the global path unconditionally
; (x-lang#527).  Internal defines are not in this bundle's specs, so the
; body-position rewrite x-krn and x-r5rs need is not duplicated here.
; eval! evaluates with no env save/restore, so a `def` inside it persists in the
; caller's world whatever the frame depth.  (An earlier draft used a proposed
; (base def-global) primitive that engine v0.1.2 does not carry -- prim-ref
; answers () for it, and every define then bound nothing, silently.)
(def %sweet-def-global
  (fn (_ n v) (eval! (list (lit def) n v))))
(def define
  (op (name-or-form . body)
    e
    (if (pair? name-or-form)
      (%sweet-def-global
        (first name-or-form)
        (eval (pair (lit lambda) (pair (rest name-or-form) body)) e))
      (%sweet-def-global name-or-form (eval (first body) e)))))

(def begin do)

; The rest are one-for-one renames of live x names.  They are `def`, not
; operatives, because they are values -- rebinding a name costs nothing and
; keeps the specs readable as Scheme.
(def car first)
(def cdr rest)
(def cons pair)
(def else #t)

; x spells these differently; sweet's specs use the Scheme spellings.
(def equal? eq?)
