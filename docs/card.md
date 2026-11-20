# x-sweet card

## Run

```sh
x -l sweet
x -l sweet -f PROGRAM
x -l sweet -f tests/card/factorial.sweet | tail -n 1 -> 120
```

```sweet
define factorial
  lambda (n)
    if {n <= 1}
      1
      {n * (factorial {n - 1})}   ; -> #<fn>

factorial 5                       ; -> 120
```

| Run                    | Prints                                         |
|------------------------|------------------------------------------------|
| `x -l sweet`           | a prompt: each form's value as it is entered   |
| `x -l sweet -f FILE`   | the value of each top-level form in FILE       |

## Curly infix

| Written           | Read as                                             |
|-------------------|-----------------------------------------------------|
| `{a + b}`         | `(+ a b)`                                           |
| `{a + b + c}`     | `(+ a b c)`: one operator, any number of operands   |
| `{a * {b + c}}`   | `(* a (+ b c))`: braces nest                        |
| `{(f x) + 1}`     | `(+ (f x) 1)`: an operand is any form               |
| `{- a}`           | `(- a)`: two items are a call                       |
| `{a}`             | `a`                                                 |
| `{}`              | `()`                                                |
| `{a + b * c}`     | `($nfx$ a + b * c)`: operators are not ranked       |

```sweet
{1 + 2}                           ; -> 3
{1 + 2 + 3 + 4}                   ; -> 10
{2 * {3 + 4}}                     ; -> 14
{(+ 1 2) + (+ 3 4)}               ; -> 10
{5 > 3}                           ; -> #t
{- 5}                             ; -> -5
'{a + b + c}                      ; -> (+ a b c)
'{a + b * c}                      ; -> ($nfx$ a + b * c)
(null? {})                        ; -> #t
```

## Indentation

| Written                        | Read as                                |
|--------------------------------|----------------------------------------|
| a line of several items        | a list: `f a b` is `(f a b)`           |
| a line of one item             | the item: `x` is `x`, not `(x)`        |
| a line indented under another  | the next item of the list above it     |
| lines at one indent            | items of the same list, in order       |
| a line back at an outer indent | closes every list deeper than it       |
| `( )` and `{ }`                | as written: no indentation inside them |
| a blank line, a `;` comment    | nothing                                |
| a tab                          | the next column that is a multiple of 8 |

```sweet
define x 42                       ; -> 42
+ 1 2                             ; -> 3
x                                 ; -> 42

define y
  + x
    * 2 4                         ; -> 50

; a comment line, and a blank one, are skipped
if {y > x}
  "more"
  "less"                          ; -> "more"

(define z
        {x + y})                  ; -> 92
```

## Programs

| Name                            | Is                                    |
|---------------------------------|---------------------------------------|
| `define NAME VALUE`             | a name for a value                    |
| `define (NAME ARG...) BODY`     | a name for a function                 |
| `lambda (ARG...) BODY`          | a function                            |
| `car` `cdr` `cons`              | the first, the rest, a pair           |
| every other name                | x-lang's own: `if`, `let`, `list`, `+` |

```sweet
define square
  lambda (n) {n * n}              ; -> #<fn>
square 7                          ; -> 49
(square {1 + 2})                  ; -> 9

define (cube n)
  {n * (square n)}                ; -> #<fn>
cube 3                            ; -> 27

let ((a 1) (b 2))
  {a + b}                         ; -> 3

define numbers
  list 1 2 3                      ; -> (1 2 3)
car (cdr numbers)                 ; -> 2
cons 0 numbers                    ; -> (0 1 2 3)
```

## Differs

| Here                                   | In SRFI-105 and SRFI-110          |
|----------------------------------------|-----------------------------------|
| `{a + b * c}` reads, and has no meaning | `$nfx$` is the user's to define   |
| `\\` is not a group marker             | starts a group                    |
| `$` is not a sublist                   | the rest of the line is a sublist |
| `<*` and `*>` are not read             | a collecting list                 |
| `!` is not indentation                 | counts as indentation             |
| the names are x-lang's                 | Scheme's                          |
| `f(x)` is not a call                   | `(f x)`                           |

## More

| Where                               | What                               |
|-------------------------------------|------------------------------------|
| `README.md`                         | what is built of each SRFI         |
| `tests/specs/01-curly-infix.spec.md` | one case a curly form             |
| `tests/specs/02-indentation.spec.md` | one case an indentation rule      |
| `make card`                         | runs every program on this page    |
