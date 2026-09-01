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
; WHY THIS IS ITS OWN MODULE.  Curly-infix (SRFI-105) and indentation grouping
; (SRFI-110) are independent notations, and neither implies the other.  But
; both have to cope with the same fact: once a whitespace type is registered,
; it fires EVERYWHERE, including inside `(...)` and `{...}`, and whatever its
; reader returns lands in the list being built.
;
; THE SENTINEL IS THE FIX, AND THE 2024 CHOICE OF IT WAS THE BUG.  That reader
; returned #t, with the note "self-evaluating, so the C eval loop handles it
; harmlessly between top-level forms".  Harmless there; not harmless inside a
; list, where it is indistinguishable from a #t the program wrote:
;
;   (lit (a          reads as    ('a #t 'b)
;     b))
;
; and the bundle's own spec `if #t` / indented `42` is a live case of a real #t
; in the same position.  The 2024 file already carried a %ws-mark sentinel and
; a strip-ws that removed it -- but nothing ever returned %ws-mark, so the
; stripper had no work to do and the #t stayed.
;
; So: return the sentinel, and strip THAT.  A fresh pair, compared by identity,
; can never collide with a value a program can write -- the discipline
; lib/x/repl/loop.x uses for its own cancel marker.
;
; ALLOCATION IS THE CONSTRAINT.  The analyser runs per character inside a
; tokenizer callback, where a collection mid-token is a hazard -- the 2024 file
; avoided `cond` there for exactly this reason.  Nested `if` only, and no `let`.
;
; THE COUNTERS ARE ORDINARY SLOTS, NOT INT CELLS, and that is a correction.
; The obvious modern spelling of the 2024 atom-val / atom-set! / atom-add!
; helpers is %cell-int / %set-cell-int!, which read and write a RAW MACHINE
; WORD in an object's first data slot.  Applied to a (list 0) that silently
; corrupts the heap: slot 0 of a pair holds an object POINTER, so the next
; mark phase traces the integer as an address and the process dies with no
; diagnostic.  Three lines reproduce it, and x-lang#522 has them.
;
; Every one of the platform's own callers applies those two to C-created
; cells.  A pair written with %set-first! is traced correctly, small integers
; are immediates so the arithmetic below allocates nothing, and the whole
; hazard evaporates.

(provide sweet/ws
  %sweet-ws-register! %sweet-ws-reset! %sweet-column %sweet-strip-ws
  %sweet-ws-mark %sweet-line-end! %sweet-line-ended? %sweet-classify
  %sweet-sus %sweet-suspend! %sweet-resume!)

(def %make-type (prim-ref (lit type) (lit make)))

; #520: THE COLUMN ARITHMETIC IS SHARED NOW, and it arrived carrying a fix.
; This file advanced the column by 8 on a tab.  SRFI-110 -- and CPython, and
; every editor -- advance to the NEXT MULTIPLE of 8, which is a different number
; the moment a tab is not the first thing on the line: for "<space><tab>x", +8
; says 9 and a tab stop says 8.  This suite has no tab case, so nothing caught
; it in either direction.  x/reader/indent is where that answer lives now, for
; this bundle and for Logo and for anything after them.
;
; Fetched raw, never dispatched: this runs once per character inside a tokenizer
; callback, where class dispatch would allocate mid-token.
(import x/reader/indent)
(def %sweet-advance (prim-ref (lit indent) (lit advance)))
(def %sweet-classify (prim-ref (lit indent) (lit classify)))

; --- State -------------------------------------------------------------------
; Plain one-slot lists used as int cells.  Ordinary global bindings, so the
; collector traces them; the 2024 version had to heap-mark-root! each of these
; because native callbacks held references x could not see.  That primitive
; still exists -- it is (Heap mark-root!) now -- but with plain closures
; nothing needs it.
(def %nl (list 0))    ; a newline has been seen in this run
(def %lv (list 0))    ; column of the line the run ends on
; Whether the last sweet-read-expr STOPPED at a line end rather than at EOF.
; Written by the grouping layer, never by the reader -- see below.
(def %wsf (list 0))
; SUSPENSION DEPTH, for the include path.  Registered types fire on EVERY
; buffer, and `include` (which `import` and include-once funnel through) hands
; the C loader a PLAIN-X file: it reads and evaluates forms itself, so nothing
; on that path runs %sweet-strip-ws.  A multi-line (def name\n  (fn ...)) in an
; included module then reads as (def name <mark> (fn ...)) and binds NAME TO
; THE SENTINEL -- observed live 2026-09-01, when (import x/tool/profile) bound
; %prof-kv to " sweet-ws" and evaluating the mangled body segfaulted the
; engine.  While this cell is nonzero both sweet analysers reject at entry, the
; platform's own types take every token, and the included file reads exactly as
; it would with sweet never armed.  A DEPTH, not a flag: includes nest.
; Exported as a cell, not a predicate: the analysers pay one slot read per
; character, never a closure call.  base.x wraps `include` with the pair below.
(def %sweet-sus (list 0))
(def %sweet-suspend!
  (fn (_) (%set-first! %sweet-sus (+ (first %sweet-sus) 1)) ()))
; Popping past zero is a no-op, mirroring module.x's include-dir stack: an
; underflow is a wrapper bug and should read as nothing happening, not as the
; reader dying while a form is still on the wire.
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

; THE SIGNAL IS THE VALUE, NOT A FLAG, and getting that backwards cost the
; hardest bug in this port.
;
; The 2024 reader set a "whitespace fired" flag and the grouping loop tested it
; after every read.  That is wrong the moment a whitespace run happens inside a
; `(...)` form: the C reader reads that list's elements itself, our type fires
; on the newline between them, and the flag is left set.  The grouping loop
; then sees a perfectly ordinary token -- the whole (define x 42) -- with the
; flag up, concludes a line ended, and DISCARDS the form.  Silently:
;
;   (define x        read one form,     evaluated nothing,
;     42)            then `x`           and reported x unbound.
;   x
;
; The returned sentinel does not have that problem, because it is attached to
; the read that produced it rather than to a global.  A nested run returns its
; mark into the list the C reader is building, where %sweet-strip-ws removes
; it, and the outer loop never sees it at all.
;
; %wsf survives only for the question the value cannot answer: did the read
; that just RETURNED stop at a line end or at end of input?  The grouping layer
; knows; the tokenizer does not.  So the grouping layer writes it.
(def %sweet-line-end! (fn (_ v) (%set-first! %wsf v) ()))
(def %sweet-line-ended? (fn (_) (if (= (first %wsf) 0) #f #t)))
(def %sweet-column (fn (_) (first %lv)))

; --- The sentinel ------------------------------------------------------------
; A STRING, and the type is load-bearing twice over.
;
; UNIQUE: x compares strings by identity, so two identical literals are not
; eq? -- (eq? "sweet-ws" "sweet-ws") is #f.  This object cannot be forged by a
; program that writes the same characters, which is the property the close
; marker in sweet/curly.x gets from being a fresh pair.
;
; SELF-EVALUATING: and this is the half a pair cannot do.  Between arming the
; reader and entering the loop, the platform's own top-level eval reads a
; token or two -- the newline after (%sweet-arm!) is one.  Those reads return
; the mark, and the top-level loop EVALUATES what it reads.  A pair
; ((%sweet-ws)) is a call, and the session dies on `Unbound SYMBOL '%sweet-ws`
; before the personality has run a line.  A string evaluates to itself and the
; leak is inert.
;
; This is what the 2024 #t was reaching for, and it was right about the
; requirement -- just not about needing to give up uniqueness to get it.
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
; State 2: the loop, once per character until the run ends.
;
; A newline resets the column and records that we are now measuring indent.  A
; SECOND newline is a blank line and ends the run at once -- without that an
; interactive session blocks waiting for content the user has not typed.
;
; Spaces and tabs count only AFTER a newline: leading whitespace on the first
; line of input is not indentation relative to anything.  What a tab is worth is
; no longer decided here -- see the tab-stop note at the top (#520, settled).
;
; Any other character ends the run, but only if a newline was seen.  A
; space-only run between two tokens on one line is not a grouping signal, so it
; REJECTS and the platform's own whitespace type takes the token instead.
(def %ws-loop ())
(set! %ws-loop
  (fn (_ buffer score chr)
    (if (= chr #\newline)
      (if (= (first %nl) 0)
        (%seq (%set-first! %nl 1) (%seq (%set-first! %lv 0) %ws-loop))
        (%seq (%set-first! %lv 0) (%score-set score 1 buffer)))
      ; Spaces and tabs are one branch now: which of them is worth what is
      ; x/reader/indent's question, not this loop's.
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
      (if (if (= chr #\space) #t
            (if (= chr #\tab) #t
              (if (= chr #\newline) #t
                (if (= chr #\return) #t
                  (if (= chr 11) #t (= chr 12))))))
        (%seq
          (if (= chr #\newline)
            (%seq (%set-first! %nl 1) (%set-first! %lv 0))
            (%set-first! %nl 0))
          %ws-loop)
        ()))))

; SCORED INCLUSIVE, AND THAT IS WHAT WINS THE TIE.  %score-set scores the
; buffer as it stands; the platform's whitespace type unreads first and so
; scores one less.  Equal-length runs therefore go to SWEET-WS, which is the
; only reason this type ever fires.  The extra character is given back here.
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
