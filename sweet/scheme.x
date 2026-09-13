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

(provide sweet/scheme define lambda begin)

; `lambda`: Scheme's formals have no receiver, x's `fn` does -- (lambda (n) ...)
; is (fn (_ n) ...).  Splicing the `_` in is the whole of the difference.
(def lambda
  (op (formals . body)
    e
    (eval (pair (lit fn) (pair (pair (lit _) formals) body)) e)))

; `define`, in both its spellings. Binds globally: (base def-global) takes
; def's top-level path unconditionally and is frame-independent. Where the
; engine lacks it -- prim-ref answers () for a missing member -- the fallback
; is eval! of (def name (lit value)). The (lit ...) wrap is required: eval!
; evaluates the def form it is handed, which would evaluate the value a second
; time; self-evaluating values hide that, a symbol value gets looked up. The
; eval! fallback is not frame-independent -- an interposed operative frame (as
; when `guard` shadows a late-bound name) captures the binding and discards it
; -- which is why def-global is preferred when present. See x-lang#527.
(def %dg-prim (prim-ref (lit base) (lit def-global)))
(def %sweet-def-global
  (if (null? %dg-prim)
    (fn (_ n v) (eval! (list (lit def) n (list (lit lit) v))))
    (fn (_ n v) (%dg-prim n v))))
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
