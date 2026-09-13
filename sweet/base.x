; # x-sweet -- sweet-expressions for x-lang
;
; ## sweet/base.x -- the language, assembled
;
; @description SRFI-105 (curly infix) and SRFI-110 (indentation) over a thin
;   Scheme surface.  Loads the parts and arms the readers.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; No path literals and no dialect boot here: run.x owns both. This file must
; not start a session either -- launching is the entry's job, and a bare
; (sweet-repl) call here would make merely importing the language open one.

(import sweet/printer)
(import sweet/scheme)
(import sweet/ws)
(import sweet/curly)
(import sweet/indent)

(provide sweet/base sweet-read sweet-version %sweet-arm! %sweet-repl-print
  %sweet-run)

; --- The version -------------------------------------------------------------
; The version comes from a stamp file beside the bundle, not from this source:
; `make install` and tools/bundle.sh both write <bundle>/version from git
; describe. x.sh emits %lang-root ahead of the entry, so this reads the stamp
; with a raw syscall -- the shape module.x's versioned-import scan uses, since
; it runs at load before the class layer, as body defs. Any miss yields "dev":
; %lang-root unbound (the spec harness imports this directly), no stamp file
; (a checkout), or a failed read. A leading "v" is stripped for the banner,
; which composes " v{%lang-version}".
(def %sweet-stamp-version
  (fn (_)
    (import x/platform/syscall)
    (def %sa (prim-ref (lit str) (lit append)))
    (def %mk (prim-ref (lit str) (lit make)))
    (def %br (prim-ref (lit str) (lit byte-ref)))
    (def %bs (prim-ref (lit str) (lit byte-sub)))
    (def %ci (prim-ref (lit char) (lit ->int)))
    ; O_RDONLY is 0 in both of x/platform/syscall's flag tables; the perm
    ; seat is ignored without O_CREAT and stays 420 so the call keeps the
    ; uniform 3-arg shape module.x and sys/file.x use.
    (def %fd (syscall (syscall-id (lit open)) (%sa %lang-root "/version") 0 420))
    (if (< %fd 0)
      "dev"
      (do
        (def %buf (%mk 64))
        (def %n (syscall (syscall-id (lit read)) %fd %buf 63))
        (syscall (syscall-id (lit close)) %fd)
        (if (< %n 1)
          "dev"
          (do
            ; One line is the contract (both writers printf '%s\n'); tolerate
            ; its absence.  Bytes compared as ints: byte-ref answers a char,
            ; and hex.x is the precedent for going through char->int.
            (def %end
              (if (= (%ci (%br %buf (- %n 1))) 10) (- %n 1) %n))
            (if (if (< 0 %end) (= (%ci (%br %buf 0)) 118) #f)
              (%bs %buf 1 (- %end 1))
              (%bs %buf 0 %end))))))))
(def sweet-version (guard (err "dev") (%sweet-stamp-version)))

; Arming is an explicit call, not a load side effect: registering a reader type
; changes how every subsequent character is tokenized, so a harness can import
; the grouping logic without the reader arming underneath it.
(def %sweet-arm!
  (fn (_)
    (%sweet-curly-register!)
    (%sweet-ws-register!)
    (%sweet-ws-reset!)
    ()))

; --- The include seam --------------------------------------------------------
; Once armed, the sweet types fire on every buffer -- including the plain-x
; module files `include` hands to the C loader, which reads and evaluates them
; itself with no %sweet-strip-ws on the path. A sentinel inside a multi-line
; form there binds a name to the sentinel string and corrupts the surrounding
; forms. So `include` is fronted with a wrapper that suspends both sweet types
; for the duration of the load; import, include-once and import-version all
; funnel through the `include` binding (module.x mutates that slot, which is
; why set! and not def), so one seam covers every module load. The -f program
; and the launcher do not pass through here -- x.sh cats both onto stdin, where
; sweet-read strips.
;
; Wrapped once, guarded like module.x's own wrapper: a second capture would
; make the wrapper call itself and recurse. The guard resumes before
; re-raising, so an error mid-load cannot leave the reader suspended.
(if (null? (prim-ref (lit module) (lit sweet-include-wrapped)))
  (do
    (prim-reg! (lit module) (lit sweet-include-wrapped) (pair () ()))
    (def %sweet-include-raw include)
    (set! include
      (fn (_ path)
        (%sweet-suspend!)
        (guard (err (%sweet-resume!) (error err))
          (def %sweet-include-result (%sweet-include-raw path))
          (%sweet-resume!)
          %sweet-include-result))))
  ())

; Install Scheme's `write` (see sweet/printer.x). A vocabulary binding, done at
; load, not at arm time.
(def write %sweet-write)

; --- The loop ----------------------------------------------------------------
; Defined before anything is armed -- a correctness requirement. Once SWEET-WS
; is registered it fires on every whitespace run containing a newline,
; including runs inside a multi-line `(...)` form that the C reader builds
; without knowing this type, leaving a sentinel among the elements.
; %sweet-strip-ws cleans the forms this loop reads; nothing cleans the forms
; the platform's own top-level loop reads from the same stream. In a body
; sequence a leaked sentinel is inert (a self-evaluating string); in an
; arity-sensitive form it is silent and fatal:
;
;   (if (null? %r) () (%seq ...))   read after arming, becomes
;   (if "mark" (null? %r) "mark" () "mark" (%seq ...))
;
; taking the wrong branch with no error and no output. The rule: after
; (%sweet-arm!) the stream may contain only single-line forms, so everything
; structural is defined before it.
(def %sweet-run
  (op () %E
    (def %r (sweet-read))
    (if (null? %r)
      ()
      (%seq
        (guard (err (%seq (display "Error: ") (%seq (display err) (newline))))
          (%repl-print (eval! %r)))
        (%sweet-run)))))
