## indentation single-line

### tokens on one line form a list

```scheme
define x 42
```
---
    42

### function call on one line

```scheme
+ 1 2
```
---
    3

## indentation basic grouping

### indented body becomes child

```scheme
define x
  42
x
```
---
    42

### indented function call

```scheme
define x
  + 1 2
x
```
---
    3

### multiple head tokens with child

```scheme
if #t
  42
```
---
    42

## indentation if expression

### if with two branches

```scheme
if {3 > 2}
  "yes"
  "no"
```
---
    "yes"

### if false branch

```scheme
if {3 < 2}
  "yes"
  "no"
```
---
    "no"

## indentation nested

### two levels of nesting

```scheme
define x
  +
    1
    2
x
```
---
    3

### define with lambda

```scheme
define double
  lambda (n)
    * n 2
double 7
```
---
    14

## indentation factorial

### recursive factorial

```scheme
define factorial
  lambda (n)
    if {n <= 1}
      1
      {n * (factorial {n - 1})}
factorial 5
```
---
    120

## indentation with parens

### parens override indentation

```scheme
(define x
  42)
x
```
---
    42

### sexp inside sweet

```scheme
define x (+ 1 2)
x
```
---
    3

## indentation with curlies

### curly infix in indented position

```scheme
define x
  {3 + 4}
x
```
---
    7

## indentation tabs

### a tab-indented body is a child

A tab advances to the next multiple of 8, so a tab-indented body groups as a
child.

```scheme
define x
	42
x
```
---
    42

## indentation blank lines

### blank lines between expressions

```scheme
define x 10
x
```
---
    10

### a line after a blank line starts a form of its own

```scheme
define %sweet-bl 1

list %sweet-bl 2
```
---
    (1 2)

### and after several, and after a line of blanks alone

```scheme
define %sweet-bm 3


list %sweet-bm 4
   
list %sweet-bm 5
```
---
    (3 5)

### a blank line inside an indented body does not end it

```scheme
define %sweet-bn
  list 6

    7
%sweet-bn
```
---
    (6 7)

## indentation comments

### comment line is transparent

```scheme
define x
  ; this is a comment
  42
x
```
---
    42

### a comment after a line's items leaves the line end where it is

```scheme
define %sweet-ca 1 ; one
list %sweet-ca 2   ; a list
```
---
    (1 2)

### a comment line at the margin does not end an indented body

```scheme
define %sweet-cb
; at the margin
  list 8 9
%sweet-cb
```
---
    (8 9)

### a comment inside parentheses and inside braces is dropped

```scheme
(list 1 ; one
      {2 + ; two
       3})
```
---
    (1 5)

