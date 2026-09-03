# Tutorial: a picture language, from nothing to a compiler

*Half an hour. You write a language nobody has described before, and end with a
single C file that compiles it and needs neither Phoenix nor a library to run.*

Everything below is typed into two files in a directory of your own. Nothing is
added to this repository, and every command and every piece of output on this
page was run exactly as it is written.

You need `bin/phx`; `make` at the top of the repository builds it. The examples
say `phx`, so either put `bin/` on your path or write `bin/phx`.

The language is a picture: circles and lines, on a hundred-by-hundred canvas.

```
# a face
circle 50, 50, 40;
circle 35, 40, 5;
circle 65, 40, 5;
line 35, 65, 65, 65;
```

Save that as `face.pic`. The target is SVG — chosen deliberately, because
nothing about Phoenix is about C. **An emit pass builds a string and nothing
anywhere cares what is in it.**

---

## 1. Characters into tokens

A description has two halves. The first says how characters become tokens, and
it is the default, so a file starts in it.

Create `picture.phx`:

```ebnf
digit   = "0" .. "9" .
number  = digit { digit } .
space   = ( " " | "\t" | "\n" ) { " " | "\t" | "\n" } .
comment = "#" { ! "\n" } .
symbol  = "," | ";" .

%skip space comment .
```

Three things here are not in Wirth's notation and are the only additions
Phoenix makes, because a lexer cannot be written without them: `"0" .. "9"` is a
range of one character, `! "\n"` is *one character provided that does not match
here*, and `"\n"` is an escape. All three are **lexical only** — using one where
there are only tokens is an error with a line number.

`%skip` says which token kinds are produced and then thrown away. It is not part
of the imported lexical library, on purpose: whether whitespace is discarded is
the *language's* business, and a layout-sensitive one keeps it.

Read the file back:

```sh
$ phx picture.phx
picture.phx:1:1: warning: 'digit' is used only by other lexical rules and is not a %fragment -- it will be returned as a token of its own
  digit = "0" .. "9" .
  ^
phx: add `%fragment digit` if it is a helper rather than a token
```

**This is the one thing about the notation that has to be learned.** `digit` is
a helper that `number` is written out of; it is not a token. Nothing about its
shape says so, and a scanner taking the longest match with ties broken by
declaration order would hand back a file as a stream of `digit`. Say what you
meant, at the top of the file:

```ebnf
%fragment digit .
```

Now `phx picture.phx` prints the grammar back with no complaint, which is the
fastest way to find out whether Phoenix understood what you wrote.

## 2. Tokens into a tree

`%syntax` names the seam. Everything after it is matched over **tokens**, and
`%start` says which rule is the goal — the first syntactic rule, if unsaid.

Add to `picture.phx`:

```ebnf
%syntax .
%start picture .

picture = { shape } .

shape = "circle" number "," number "," number ";"
      | "line" number "," number "," number "," number ";" .
```

```sh
$ phx picture.phx face.pic
picture.phx:16:9: error: no token rule spells "circle", so 'shape' can never match
  shape = "circle" number "," number "," number ";"
          ^
```

Correct, and caught before any file was read. Nothing in the lexical half
produces a word, so that alternative could never have matched — and without this
check the complaint would have arrived at the first picture with a circle in it,
pointing at the picture rather than at the grammar.

Add a word rule:

```ebnf
%fragment letter digit .

letter  = "a" .. "z" .
digit   = "0" .. "9" .

word    = letter { letter } .
number  = digit { digit } .
```

**Nothing declares `circle` and `line` to be keywords.** Every word-shaped
literal in the syntactic half is a reserved word, worked out from the grammar
rather than declared. Now:

```sh
$ phx --tokens picture.phx face.pic
   2:1    word               circle
   2:8    number             50
   2:10   symbol             ,
   2:12   number             50
   2:14   symbol             ,
   2:16   number             40
   2:18   symbol             ;
   3:1    word               circle
```

and parsing it:

```sh
$ phx picture.phx face.pic
picture
|- shape
|  |- "circle"
|  |- "50"
|  |- ","
|  |- "50"
|  |- ","
|  |- "40"
|  `- ";"
|- shape
...
```

That is the **concrete** tree: every comma and semicolon in it, because nothing
has yet said what a shape *means*.

## 3. Saying what a production builds

`->` after an alternative says what it means, as against what it looks like.

```ebnf
picture = { shape } -> Picture(shapes: $1) .

shape = "circle" x:number "," y:number "," r:number ";"
          -> Circle(x: $x, y: $y, r: $r)
      | "line" x1:number "," y1:number "," x2:number "," y2:number ";"
          -> Line(x1: $x1, y1: $y1, x2: $x2, y2: $y2) .
```

`$1` is the first factor, counting from one and **counting everything** — the
literals too. That is why the factors here are labelled instead: `x:number`,
read back as `$x`, survives the alternative being edited. Both forms are checked
when the grammar is read, because `$3` drifting after a factor is inserted
before it is yacc's most famous silent failure.

```sh
$ phx --tree picture.phx face.pic
Picture
`- shapes: [4]
   |- Circle
   |  |- x: "50"
   |  |- y: "50"
   |  `- r: "40"
   |- Circle
   |  |- x: "35"
   |  |- y: "40"
   |  `- r: "5"
   |- Circle
   |  |- x: "65"
   |  |- y: "40"
   |  `- r: "5"
   `- Line
      |- x1: "35"
      |- y1: "65"
      |- x2: "65"
      `- y2: "65"
```

Every bracket is gone and nothing had to strip it. `--nodes` prints the
vocabulary a pass will be written against:

```sh
$ phx --nodes picture.phx
Position(line, column, file, endline, endcolumn)
Picture(shapes)
Circle(x, y, r)
Line(x1, y1, x2, y2)
```

## 4. A pass, and a driver

A `%pass` is one walk over the tree. A clause is keyed on a node type and says
what that node answers for an attribute.

```
%pass emit-svg

  Circle : out = "  <circle cx=\"{}\" cy=\"{}\" r=\"{}\" fill=\"none\" stroke=\"black\" />"
             of $x, $y, $r .

  Line   : out = "  <line x1=\"{}\" y1=\"{}\" x2=\"{}\" y2=\"{}\" stroke=\"black\" />"
             of $x1, $y1, $x2, $y2 .

  Picture : out = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">\n{}\n</svg>"
              of join($shapes.out, "\n") .

%driver svg = emit-svg -> out .
```

Three things are doing work in those eight lines.

**`of` fills the holes**, left to right. `{{` and `}}` would be literal braces,
which is what an emit pass writing C needs and this one does not.

**`$shapes.out` is `out` of each shape.** `shapes` is a list, and `.` over a
list means *that of each* — so there is no map, no lambda and no traversal to
write. `join` puts them together.

**`%driver` says what to run and which attribute of the root is the answer.**
The first declared is the default.

```sh
$ phx picture.phx face.pic
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="40" fill="none" stroke="black" />
  <circle cx="35" cy="40" r="5" fill="none" stroke="black" />
  <circle cx="65" cy="40" r="5" fill="none" stroke="black" />
  <line x1="35" y1="65" x2="65" y2="65" stroke="black" />
</svg>
```

Open it in a browser. It is a face.

## 5. Refusing a picture that is wrong

A clause may also carry a **check** — `! condition : message` — which runs
*before* the attributes it guards, so a diagnostic arrives instead of a
consequence.

```
%pass sane
  Circle ! int($r) = 0 : "a circle of radius {} draws nothing" of $r .

%driver svg   = sane, emit-svg -> out .
%driver check = sane .
```

A pass with nothing but a check is a perfectly good pass. Note `int($r)`: `$r`
is the **text** the number rule matched, and **nothing in this notation converts
implicitly** — `int` and `float` are the only things that do.

Put a flat circle in a file of its own — `circle 10, 10, 0;` in `flat.pic`:

```sh
$ phx picture.phx flat.pic
flat.pic:1:1: error: a circle of radius 0 draws nothing
  circle 10, 10, 0;
  ^
$ echo $?
1
```

The position is in `flat.pic`, not in the description. A node carries where it
came from, and a diagnostic points at the program.

`%driver check = sane .` has no `-> out`, which makes it a **validation run**:
nothing is printed and the exit status is all it says.

```sh
$ phx --driver check picture.phx face.pic ; echo $?
0
```

## 6. Writing the compiler out

```sh
$ phx picture.phx -o picc.c
$ cc picc.c -o picc
$ ./picc face.pic
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="40" fill="none" stroke="black" />
...
```

That is about 4,500 lines of C in one file. No flags, no headers, no library, and no
Phoenix:

```sh
$ ./picc flat.pic
flat.pic:1:1: error: a circle of radius 0 draws nothing
  circle 10, 10, 0;
  ^
```

**What was written out is the description, as data, beside the machine that
already runs it.** `picc` runs the same matcher and the same evaluator `phx`
does, over your grammar frozen into static tables. The alternative — generating
a recursive-descent function per rule — is faster and is what most of the yacc
family does, and it is a second implementation of the notation that has to agree
with the first. There is nothing here for the two to disagree about, because
there is only one of them. [The README](../README.md#writing-a-compiler-out) has
the argument, and [performance.md](performance.md) has what it costs.

## 7. A second target, for free

The emit pass is the only part of that file with an opinion about SVG. Split it
in two: leave everything up to and including `%pass sane` in `picture.phx`, and
move the rest into `picture-svg.phx`:

```
(* picture-svg.phx *)
%import "picture.phx" .

%pass emit-svg
  ...as before...

%driver svg   = sane, emit-svg -> out .
%driver check = sane .
```

A second target is then a second small file and nothing else:

```
(* picture-text.phx *)
%import "picture.phx" .

%pass emit-text
  Circle  : out = "a circle of radius {} at ({}, {})" of $r, $x, $y .
  Line    : out = "a line from ({}, {}) to ({}, {})" of $x1, $y1, $x2, $y2 .
  Picture : out = join($shapes.out, "\n") .

%driver text = sane, emit-text -> out .
```

```sh
$ phx picture-text.phx face.pic
a circle of radius 40 at (50, 50)
a circle of radius 5 at (35, 40)
a circle of radius 5 at (65, 40)
a line from (35, 65) to (65, 65)

$ phx --imports picture-text.phx
picture-text.phx
picture.phx
```

**The split that matters is not grammar-versus-passes; it is the language
against the target.** Everything upstream of emitting — the grammar, the tree,
the checks — belongs to the language and has no opinion about where it is going.
Only emit is per target. `languages/calc/` is this same split at slightly larger
scale, and `languages/pascal/` at much larger.

---

## What to read next

| | |
| --- | --- |
| [tutorial-assembler.md](tutorial-assembler.md) | the next tutorial: two passes, a threaded attribute, and a forward reference |
| [manual.md](manual.md) | the whole notation, explained in order |
| [reference.md](reference.md) | every directive, clause form and library function |
| [`languages/calc/`](../languages/calc/) | this shape again, with expressions, a typechecker and an interpreter |
