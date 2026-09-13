; # x-sweet -- sweet-expressions for x-lang
;
; ## run.x -- the entry point
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
; This file contains no path literals and no boot code. x.sh boots the dialect
; lang.xon declares, arms this bundle's root with import-path!, cats this file,
; and appends the launcher when no -f was given, so `import` below resolves
; against the bundle wherever it sits.
(import sweet/base)

(set! %lang-name "Sweet Expressions")
(set! %lang-version sweet-version)
(set! %repl-prompt "")
; Scheme results, not x's round-trippable ones -- see sweet/printer.x.
(set! %repl-print %sweet-repl-print)

; Arm last, then run: registering SWEET-WS changes how the next character is
; tokenized, so a multi-line form read after this point has whitespace
; sentinels injected among its elements -- silent and fatal in an
; arity-sensitive form. The setup above is one line each, and %sweet-run (the
; loop) is defined in sweet/base.x before the arm. The launcher x.sh appends
; prints the banner; this file does not.
(%sweet-arm!)
(%sweet-run)
