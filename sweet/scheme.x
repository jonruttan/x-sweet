; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/scheme.x -- the Scheme names the notation is written in
;
; @description The eight Scheme bindings this bundle's specs use: define,
;   lambda, begin, car, cdr, cons, else, equal?. Each is a thin wrapper over
;   an x form.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Placeholder. When x-r5rs lands as a bundle, lang.xon takes a dependency on
; it and this file becomes `(import r5rs/base)`. Nothing here defines what
; Scheme means; x-r5rs is the arbiter of that.

; `lambda`: Scheme's formals have no receiver, x's `fn` does -- (lambda (n) ...)
; is (fn (_ n) ...).  Splicing the `_` in is the whole of the difference.
(module sweet/scheme)
(def lambda
  (op (formals . body)
    e
    (eval (pair (lit fn) (pair (pair (lit _) formals) body)) e)))

; `define`, in both its spellings. Binds in the root: eval! evaluates there
; whatever the frame depth (engine law 10). The (lit ...) wrap keeps def from
; evaluating the value a second time -- a symbol value would be looked up.
(def %sweet-def-root (fn (_ n v) (eval! (list (lit def) n (list (lit lit) v)))))
(def define
  (op (name-or-form . body)
    e
    (if (pair? name-or-form)
      (%sweet-def-root
        (first name-or-form)
        (eval (pair (lit lambda) (pair (rest name-or-form) body)) e))
      (%sweet-def-root name-or-form (eval (first body) e)))))

; The rest are one-for-one renames of live x names.  They are `def`, not
; operatives, because they are values -- rebinding a name costs nothing and
; keeps the specs readable as Scheme.
(def car first)
(def cdr rest)
(def cons pair)
(def else #t)

; x spells these differently; sweet's specs use the Scheme spellings.

(provide sweet/scheme
  (global car) (global cdr) (global cons) (global define) (global else)
  (global lambda))
