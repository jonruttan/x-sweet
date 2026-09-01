; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/curly.x -- SRFI-105, curly-infix notation
;
; @description {a + b} reads as (+ a b); {a + b + c} folds to (+ a b c);
;   mixed operators produce ($nfx$ ...) as the SRFI requires.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; THIS IS A READER TYPE, and the 2024 version of it is the clearest single
; case of what changed underneath these personalities.  It used to be:
;
;   (make-type "SWEET-CURLY"
;     (list (cons (lit first-chars) "{}")
;           (cons (lit analyse) (%nth 0 %compiled))   ; native-compiled
;           ...
;
; Three things in that are gone.  `make-type` as a bare global is now
; (prim-ref 'type 'make).  `first-chars` no longer exists at all -- the
; tokenizer iterates every registered type and scores its analyse hook, so the
; leading-character prefilter it named was removed rather than renamed.  And
; the callbacks were compiled to native code through `compile-batch`, which
; forced the state cells to be GC roots (`heap-mark-root!`, also gone).
;
; The port drops the compilation.  lib/x/num/float.x is the live worked
; example of a reader type in plain x closures -- its `analyse` returns
; further closures to advance a state machine -- and a curly reader is far
; cheaper than a float reader.  Plain closures also delete the root problem
; outright: ordinary bindings are visible to the collector, so nothing needs
; marking by hand.  Reach for `compile` again only if a measurement asks.

(import sweet/ws)

(provide sweet/curly %sweet-curly-register! $nfx$)

; --- Catalog fetches ---------------------------------------------------------
; ns `type`/`buf`/`io` are de-registered as ambient names (R5); consumers hold
; their own refs.  Fetched once at load, never per character.
(def %make-type (prim-ref (lit type) (lit make)))
(def %buf-last-char (prim-ref (lit buf) (lit last-char)))
(def %prim-read (prim-ref (lit io) (lit read)))

; --- Infix to prefix ---------------------------------------------------------
; SRFI-105: an even-positioned operand list with all-equal odd-positioned
; operators folds to a prefix call; anything else is ($nfx$ . tokens) and the
; reader hands the decision to the program.
(def %sweet-ops
  (fn (self toks)
    (if (null? toks)
      ()
      (if (null? (rest toks))
        ()
        (pair (first (rest toks)) (self (rest (rest toks))))))))

(def %sweet-operands
  (fn (self toks)
    (if (null? toks)
      ()
      (pair
        (first toks)
        (if (null? (rest toks)) () (self (rest (rest toks))))))))

(def %sweet-all-eq?
  (fn (self lst)
    (if (null? lst)
      #t
      (if (null? (rest lst))
        #t
        (if (eq? (first lst) (first (rest lst))) (self (rest lst)) #f)))))

(def %sweet-reverse
  (fn (self lst acc)
    (if (null? lst) acc (self (rest lst) (pair (first lst) acc)))))

(def %infix->prefix
  (fn (_ toks)
    (if (null? toks)
      ()
      ; {x} is x -- a single element is identity, not a one-element call.
      (if (null? (rest toks))
        (first toks)
        ; {a b} has no operator to fold: two elements stay a list, which is
        ; what SRFI-105 calls the unary case ({- 5}, {not #f}).
        (if (null? (rest (rest toks)))
          toks
          (let ((ops (%sweet-ops toks))
                (operands (%sweet-operands toks)))
            (if (%sweet-all-eq? ops)
              (pair (first ops) operands)
              (pair (lit $nfx$) toks))))))))

; The SRFI's escape hatch: mixed operators are not an error, they are a call to
; $nfx$, which a program may define.  Undefined, it reports itself.
(def $nfx$ (op args e (pair (lit $nfx$) args)))

; --- The reader --------------------------------------------------------------
; A fresh pair, identity-compared, so the close marker can never collide with
; anything a read returns -- the same discipline lib/x/repl/loop.x uses for its
; cancel marker.
(def %curly-close (list (lit %sweet-curly-close)))
(def %curly-close?
  (fn (_ x) (if (pair? x) (eq? (first x) (first %curly-close)) #f)))

; Nested `if`, never `cond`, and no allocation in the loop head: this runs
; inside a reader callback, where the 2024 file's own note warns that cond
; triggers a collection mid-tokenize.
(def %curly-read
  (fn (_ . args)
    (if (= (%buf-last-char (first args)) #\})
      %curly-close
      (do
        (def %go
          (fn (self acc)
            (def %e (%prim-read))
            (if (null? %e)
              (%infix->prefix (%sweet-reverse acc ()))
              (if (%curly-close? %e)
                (%infix->prefix (%sweet-reverse acc ()))
                ; A whitespace run inside braces is not an operand.  {a +\n b}
                ; is one infix expression, so the sentinel is dropped rather
                ; than folded -- indentation does not group inside {}.
                (if (eq? %e %sweet-ws-mark)
                  (self acc)
                  (self
                    (pair (if (pair? %e) (%sweet-strip-ws %e) %e) acc)))))))
        (%go ())))))

; Both hooks reject while %sweet-sus is up -- an include is loading a PLAIN-X
; file, where a brace is not notation.  One slot read per character, same
; discipline as the gate in sweet/ws.x, which also owns the why.
(def %curly-analyse
  (fn (_ buffer score chr)
    (if (< 0 (first %sweet-sus))
      ()
      (if (if (= chr #\{) #t (= chr #\}))
        (%score-set score 1 buffer)
        ()))))

; { and } terminate an adjacent token, so a{b} reads as a then {b}.
(def %curly-delimit
  (fn (_ buffer . rest)
    (if (< 0 (first %sweet-sus))
      ()
      (if (if (= (%buf-last-char buffer) #\{) #t (= (%buf-last-char buffer) #\}))
        (%seq (%buffer-unread buffer) buffer)
        ()))))

; Registration is a VERB, not a load side effect.  base.x decides when the
; reader arms, so loading this module in a harness that only wants
; %infix->prefix does not change how the file being read is tokenized.
(def %sweet-curly-register!
  (fn (_)
    (%make-type
      "SWEET-CURLY"
      (list
        (pair (lit analyse) %curly-analyse)
        (pair (lit read) %curly-read)
        (pair (lit delimit) %curly-delimit)))))
