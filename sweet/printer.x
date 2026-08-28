; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/printer.x -- Scheme's `write`, which is not x's
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; x's `write` is round-trippable: a symbol renders with the quote its reader
; needs to give it back, so (list 'b 'c) writes as ('b 'c).  That is right for
; x, and blessed in docs/spec.md -- "(my-quote (+ 1 2)) -> ('+ 1 2)".
;
; Scheme's `write` renders symbols bare and strings quoted: (b c) and "hello".
; This bundle's own spec asserts it directly --
;
;     (write {1 + 2 * 3})   ->   ($nfx$ 1 + 2 * 3)
;
; -- so the difference is not cosmetic here, it is the assertion.
;
; Re-meaning a shared spelling is what a personality is FOR; the contract says
; so in as many words.  So `write` is rebound rather than the spec rewritten,
; and the same writer backs %repl-print.  (x-krn/krn/printer.x reaches the same
; conclusion from the same evidence -- worth noticing that two independent
; ports of two unrelated languages both needed this in their first hour.)

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
