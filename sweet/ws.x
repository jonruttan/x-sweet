; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/ws.x -- the whitespace token both SRFIs stand on
;
; @description A reader type that turns a run of whitespace containing a
;   newline into one token, recording the column of the line it ends on.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Curly-infix (SRFI-105) and indentation grouping (SRFI-110) are independent
; notations, and both need this token, so it lives in its own module.
;
; Constraints on anything changed here:
;
; - Once the type is registered it fires everywhere, including inside `(...)`
;   and `{...}`, and whatever its reader returns lands in the list being built.
;   The reader returns %sweet-ws-mark; %sweet-strip-ws removes it. The mark is
;   a string compared with `eq?` -- by identity -- so no value a program can
;   write collides with it.
;
; - The analyser runs per character inside a tokenizer callback, where a
;   collection mid-token is a hazard. Nested `if` only: no `cond`, no `let`.
;
; - The counters are ordinary slots written with %set-first!. Do not switch
;   them to %cell-int / %set-cell-int!: those write a raw machine word into
;   slot 0, which the collector traces as a pointer on a pair, corrupting the
;   heap (x-lang#522). Small integers are immediates, so the arithmetic below
;   allocates nothing either way.

(provide sweet/ws
  %sweet-ws-register! %sweet-ws-reset! %sweet-column %sweet-strip-ws
  %sweet-ws-mark %sweet-line-end! %sweet-line-ended? %sweet-classify
  %sweet-sus %sweet-suspend! %sweet-resume!)

(def %make-type (prim-ref (lit type) (lit make)))

; Column arithmetic comes from x/reader/indent, shared with Logo and anything
; after: a tab advances to the next multiple of 8, not +8, which differs once a
; tab is not first on the line. Fetched raw, never dispatched -- this runs once
; per character inside a tokenizer callback, where class dispatch would
; allocate mid-token.
(import x/reader/indent)
(def %sweet-advance (prim-ref (lit indent) (lit advance)))
(def %sweet-classify (prim-ref (lit indent) (lit classify)))

; --- State -------------------------------------------------------------------
; Plain one-slot lists used as int cells. Ordinary global bindings, so the
; collector traces them; with plain-closure callbacks nothing needs a manual
; GC root.
(def %nl (list 0))    ; a newline has been seen in this run
(def %lv (list 0))    ; column of the line the run ends on
; Whether the last sweet-read-expr STOPPED at a line end rather than at EOF.
; Written by the grouping layer, never by the reader -- see below.
(def %wsf (list 0))
; Suspension depth for the include path. Registered types fire on every buffer,
; and `include` (which import and include-once funnel through) hands the C
; loader a plain-x file it reads and evaluates itself, with no %sweet-strip-ws.
; While this cell is nonzero both sweet analysers reject at entry and the
; platform's own types take every token, so an included file reads as it would
; with sweet never armed. A depth, not a flag, because includes nest. Exported
; as a cell, not a predicate: the analysers pay one slot read per character,
; never a closure call. base.x wraps `include` with the pair below.
(def %sweet-sus (list 0))
(def %sweet-suspend!
  (fn (_) (%set-first! %sweet-sus (+ (first %sweet-sus) 1)) ()))
; Popping past zero is a no-op: an underflow is a wrapper bug, and should read
; as nothing happening rather than the reader dying while a form is on the wire.
(def %sweet-resume!
  (fn (_)
    (if (< 0 (first %sweet-sus))
      (%set-first! %sweet-sus (- (first %sweet-sus) 1))
      ())
    ()))

(def %sweet-ws-reset!
  (fn (_)
    (%set-first! %nl 0)
    (%set-first! %lv 0)
    (%set-first! %wsf 0)
    ()))

; The line-end signal is the returned sentinel, not a flag. A flag set on every
; whitespace run would also be set by a run inside a `(...)` form (the C reader
; reads those elements itself), so the grouping loop could not tell a real line
; end from one deep in a nested form. The sentinel belongs to the read that
; produced it: a nested run returns its mark into the list the C reader builds,
; where %sweet-strip-ws removes it, and the outer loop never sees it.
;
; %wsf answers only the question the value cannot: did the read that just
; returned stop at a line end or at end of input? The grouping layer knows and
; writes it; the tokenizer does not.
(def %sweet-line-end! (fn (_ v) (%set-first! %wsf v) ()))
(def %sweet-line-ended? (fn (_) (if (= (first %wsf) 0) #f #t)))
(def %sweet-column (fn (_) (first %lv)))

; --- The sentinel ------------------------------------------------------------
; A string, load-bearing twice over. Unique: x compares strings by identity, so
; (eq? "sweet-ws" "sweet-ws") is #f and no program writing the same characters
; can forge this object. Self-evaluating: between arming and entering the loop
; the platform's top-level eval reads and evaluates a token or two (the newline
; after the arm), and those reads return the mark -- a string evaluates to
; itself, so the leak is inert, where a pair would be called and raise Unbound
; SYMBOL.
(def %sweet-ws-mark "\u0000sweet-ws")

; Recursive, because a mark can land at any depth: (a (b\n c)) puts one in the
; inner list.  Improper tails are preserved -- a personality whose reader
; cannot round-trip (a . b) cannot read a pair.
(def %sweet-strip-ws
  (fn (self lst)
    (if (not (pair? lst))
      (if (eq? lst %sweet-ws-mark) () lst)
      (if (eq? (first lst) %sweet-ws-mark)
        (self (rest lst))
        (pair
          (if (pair? (first lst)) (self (first lst)) (first lst))
          (self (rest lst)))))))

; --- The analyser ------------------------------------------------------------
; State 2: the loop, once per character until the run ends. A newline resets
; the column and marks that we are measuring indent; a second newline is a
; blank line and ends the run at once (without that an interactive session
; blocks waiting for input). Spaces and tabs count only after a newline --
; leading whitespace on the first line is not indentation. Any other character
; ends the run, but only if a newline was seen: a space-only run between two
; tokens on one line is not a grouping signal, so it rejects and the platform's
; own whitespace type takes the token.
(def %ws-loop ())
(set! %ws-loop
  (fn (_ buffer score chr)
    (if (= chr #\newline)
      (if (= (first %nl) 0)
        (%seq (%set-first! %nl 1) (%seq (%set-first! %lv 0) %ws-loop))
        (%seq (%set-first! %lv 0) (%score-set score 1 buffer)))
      ; Space and tab share a branch; %sweet-advance applies the column width.
      (if (if (= chr #\space) #t (= chr #\tab))
        (%seq
          (if (= (first %nl) 0)
            ()
            (%set-first! %lv (%sweet-advance (first %lv) chr 8)))
          %ws-loop)
        (if (if (= chr #\return) #t (if (= chr 11) #t (= chr 12)))
          %ws-loop
          (if (= (first %nl) 0)
            ()
            (%score-set score 1 buffer))))))))

; State 1: the entry.  The first character must be whitespace or this is not
; our token at all.  Suspended (an include is loading a plain-x file), it
; rejects unconditionally and the platform's whitespace type takes the run;
; only the entry needs the check, because suspension can only change between
; tokens -- include runs during eval, never mid-tokenize.
(def %ws-analyse
  (fn (_ buffer score chr)
    (if (< 0 (first %sweet-sus))
      ()
      (if (match
            ((= chr #\space) #t)   ((= chr #\tab) #t)
            ((= chr #\newline) #t) ((= chr #\return) #t)
            ((= chr 11) #t)        ((= chr 12) #t)
            (#t #f))
        (%seq
          (if (= chr #\newline)
            (%seq (%set-first! %nl 1) (%set-first! %lv 0))
            (%set-first! %nl 0))
          %ws-loop)
        ()))))

; Scored inclusive, which wins the tie: %score-set scores the buffer as it
; stands, while the platform's whitespace type unreads first and scores one
; less, so equal-length runs go to SWEET-WS. The extra character is given back
; here.
(def %ws-read
  (fn (_ . args)
    (%buffer-unread (first args))
    %sweet-ws-mark))

(def %sweet-ws-register!
  (fn (_)
    (%make-type
      "SWEET-WS"
      (list
        (pair (lit analyse) %ws-analyse)
        (pair (lit read) %ws-read)))))
