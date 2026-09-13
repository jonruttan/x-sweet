; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/indent.x -- SRFI-110, indentation as grouping
;
; @description A line's tokens are a list; a more-indented line is that
;   list's child.  `define x` over an indented `42` reads as (define x 42).
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The work is split in two. sweet/ws.x is the tokenizer half: an analyser
; returns a score or a next state, not a value, so it writes the column a
; whitespace run ends on into cells that this file reads. This file never sees
; characters; the analyser never sees expressions.
;
; The column measurement and the grouping rules belong to x/reader/indent, and
; are reached through sweet/ws.x, which caches the raw refs.
;
; This reader runs on the live stream and builds nested forms as it returns, so
; the recursion is its stack: `base` is the enclosing column, held in a frame
; rather than an explicit list.
;
; Known divergence from x/reader/indent: a line dedenting to a column that no
; enclosing level sits at unwinds past every level, where Indent's `close` mode
; stops at the nearest and `error` refuses. Fixing it requires an explicit
; stack.

(import sweet/ws)

(provide sweet/indent sweet-read sweet-read-expr)

(def %prim-read (prim-ref (lit io) (lit read)))

; A line of N tokens is a list; a line of ONE token is that token, not a
; one-element call.  SRFI-110 calls this the single-item rule, and it is what
; makes an indented `42` a value rather than `(42)`.
(def %sw1
  (fn (_ x)
    (if (null? x) () (if (null? (rest x)) (first x) x))))

(def %sweet-rev
  (fn (self lst acc)
    (if (null? lst) acc (self (rest lst) (pair (first lst) acc)))))

(def %sweet-append
  (fn (self a b)
    (if (null? a) b (pair (first a) (self (rest a) b)))))

(def sweet-read-expr ())
(def %sweet-siblings ())

; Every line strictly deeper than `base` belongs to the form being built; a
; line at `base` or shallower ends it and is somebody else's to read.
(set! %sweet-siblings
  (fn (_ lv)
    (def %go
      (fn (self acc)
        (def %child (sweet-read-expr lv))
        (if (null? %child)
          (%sweet-rev acc ())
          (if (if (%sweet-line-ended?)
                (eq? (%sweet-classify (%sweet-column) lv) (lit same))
                #f)
            (self (pair %child acc))
            (%sweet-rev (pair %child acc) ())))))
    (%go ())))

(set! sweet-read-expr
  (fn (_ base)
    (def %go
      (fn (self acc)
        (def %t (%prim-read))
        (if (null? %t)
          ; End of input.  The caller must be able to tell this from a line
          ; end, or %sweet-siblings loops forever on the last line of a file.
          (%seq (%sweet-line-end! 0) (%sw1 (%sweet-rev acc ())))
          (if (eq? %t %sweet-ws-mark)
            ; A line ended.  With nothing accumulated it was a leading, blank,
            ; or comment-only line -- keep reading rather than returning an
            ; empty form.  That single branch is the whole of why blank lines
            ; and comment lines are transparent.
            (if (null? acc)
              (self acc)
              ; The rules come from x/reader/indent: deeper, same, shallower.
              (if (eq? (%sweet-classify (%sweet-column) base) (lit deeper))
                ; Deeper: those lines are this form's children.  The flag is
                ; left to %sweet-siblings, whose last child sets it to whatever
                ; ended the whole group -- that is what our own caller needs.
                (%sw1
                  (%sweet-append
                    (%sweet-rev acc ())
                    (%sweet-siblings (%sweet-column))))
                (%seq (%sweet-line-end! 1) (%sw1 (%sweet-rev acc ())))))
            ; An ordinary token joins this line.  STRIPPED IF IT IS A LIST: a
            ; `(...)` spanning lines was read by the C reader, which knows
            ; nothing about our whitespace type, so every run inside it left a
            ; sentinel among the elements.  See sweet/ws.x.
            (self
              (pair (if (pair? %t) (%sweet-strip-ws %t) %t) acc))))))
    (%go ())))

(def sweet-read (fn (_) (sweet-read-expr 0)))
