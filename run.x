; # x-sweet -- sweet-expressions for x-lang
;
; ## run.x -- THE entry
;
; @description SRFI-105 curly infix ({a + b}) and SRFI-110 indentation
;   grouping, over a thin Scheme surface.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Usage:
;   x -l sweet                interactive
;   x -l sweet -f prog.sweet  batch
;
; THIS FILE KNOWS NO PATHS, and that is the whole point of the arrangement.
; x.sh boots the dialect lang.xon declares, arms this bundle's root with
; import-path!, cats this file, and appends the launcher when no -f was given.
; So by the time anything below runs, the platform is up and `import` resolves
; against the bundle wherever it happens to sit.
;
; It used to do all of that itself: include "lib/x-core.x" to self-boot, probe
; a list of candidate directories to guess its own location, and end with its
; own %batch?-guarded launcher.  Every line of that was a workaround for `-l`
; not knowing about bundles.  It does now.
(import sweet/base)

(set! %lang-name "Sweet Expressions")
(set! %lang-version sweet-version)
(set! %repl-prompt "")
; Scheme results, not x's round-trippable ones -- see sweet/printer.x.
(set! %repl-print %sweet-repl-print)

; ARMED LAST, AND NOTHING STRUCTURAL MAY FOLLOW.  Registering SWEET-WS changes
; how the very next character of input is tokenized, so any multi-line form
; read after this point has whitespace sentinels injected into it -- silent and
; fatal in an arity-sensitive form.  See the note in sweet/base.x.  Everything
; below is one line each, deliberately.
;
; THE LOOP IS OURS, not the launcher's: a sweet "unit" is an indented block,
; not an s-expression, so %sweet-run reads with sweet-read.  x.sh appends its
; own launcher only when this file does not end in one.
(%sweet-arm!)
(unless %batch? (%banner))
(%sweet-run)
