; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/printer.x -- Scheme-style `write`
;
; @description Renders symbols bare and strings quoted, as Scheme's `write`
;   does. Rebinds `write`; the same writer backs %repl-print.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x's `write` is round-trippable: a symbol renders with the quote its reader
; needs to give it back, so (list 'b 'c) writes as ('b 'c). Scheme's renders
; (b c). The difference is asserted by this bundle's specs, e.g.
;
;     (write {1 + 2 * 3})   ->   ($nfx$ 1 + 2 * 3)

(provide sweet/printer %sweet-write %sweet-repl-print)

; Recursive descent, because only the SYMBOL leaf differs from x's `write`.
; Everything else -- strings, ints, chars, booleans, procedures -- delegates,
; so the personality inherits the platform's rendering and stays correct as new
; types arrive.
(def %sweet-write ())
(def %x-write write)

(def %sweet-write-items
  (fn (_ v)
    (%sweet-write (first v))
    (if (null? (rest v))
      ()
      ; Proper tail: keep going.  Improper: the dotted spelling.  A printer
      ; that cannot render (a . b) cannot show a pair, and pairs are the
      ; substrate.
      (if (pair? (rest v))
        (%seq (display " ") (%sweet-write-items (rest v)))
        (%seq (display " . ") (%sweet-write (rest v)))))))

(set! %sweet-write
  (fn (_ v)
    (if (pair? v)
      (%seq (display "(") (%seq (%sweet-write-items v) (display ")")))
      (if (symbol? v) (display v) (%x-write v)))))

; The %repl-print shape: nil is the "no value" result and prints only the
; newline, matching lib/x/repl/loop.x.
(def %sweet-repl-print
  (fn (_ result)
    (unless (null? result) (%sweet-write result))
    (newline)))
