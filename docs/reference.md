# Phoenix reference

*Every directive, every clause form, every operator and every library function.
For an explanation rather than a lookup, read [manual.md](manual.md); for one
page, [cheatsheet.md](cheatsheet.md).*

What the meta-language's **arithmetic** means is specified separately and
executably in [semantics.md](semantics.md); this page repeats its conclusions
and does not restate its argument.

---

## Contents

1. [Running `phx`](#1-running-phx)
2. [The text of a description](#2-the-text-of-a-description)
3. [Directives](#3-directives)
4. [The grammar](#4-the-grammar)
5. [Actions — what a production builds](#5-actions--what-a-production-builds)
6. [Passes](#6-passes)
7. [Rewrites](#7-rewrites)
8. [Drivers](#8-drivers)
9. [Expressions](#9-expressions)
10. [Patterns](#10-patterns)
11. [The library](#11-the-library)
12. [What is checked before anything runs](#12-what-is-checked-before-anything-runs)

---

## 1. Running `phx`

```
phx [options] <description.phx> [source]
```

With no source, the description is read, checked and printed back — which is
the fastest way to find out whether Phoenix understood it. With a source, the
source is scanned and parsed, and the default driver runs over the tree.

| Option | |
| --- | --- |
| `--tree` | print the tree and stop, whatever drivers there are |
| `--tokens` | print the token stream and stop |
| `--nodes` | print the node types the grammar builds, and each one's fields |
| `--grammar` | print the grammar as it was understood |
| `--drivers` | list the drivers, marking the default |
| `--imports` | list every file the description was assembled from |
| `-o FILE.c` | write this description out as a C program that is its compiler |
| `--driver NAME` | which `%driver` to run. Default: the first declared |
| `--run PASS` | run one `%pass` on its own, ignoring the drivers |
| `--show ATTR` | print this attribute of the root, overriding the driver's |
| `--raw` | write the answer exactly, adding no trailing newline |
| `--stats` | report how much work reading the source took |
| `--no-includes` | do not follow the source's own `%include`s |
| `-I DIR`, `-Idir` | where to look for a file the **source** includes. Repeatable, in order |
| `--quiet` | say nothing on success |
| `--help`, `-h` | the usage |

Exit status is `0` on success, `1` when the description or the program was
refused, `2` when the command line was wrong.

### Where files are looked for

| | |
| --- | --- |
| `%import "x.phx"` | beside the file that names it, then in the library beside the `phx` executable |
| `%embed n "x.c"` | the same two places |
| the source's own `@include` | beside the file that includes it, then each `-I` directory in order — C's rules, for C's reasons |

`$PHX_LIB` overrides the library directory. A file is read **once** however
many times it is reached, so two modules may import a third, and two modules
may import each other, without anybody arranging for it — and a cycle ends
because a file that comes round to itself finds itself already read.

### `--stats`

```
111 bytes  21 tokens  22 nodes  2984 scan-steps  265 match-steps  depth 26  (12.6 match-steps per token)
```

Match-steps per token is the number to watch: it is the constant, and it should
not grow with the size of the file. [performance.md](performance.md) has the
measurements.

---

## 2. The text of a description

**Comments** are `(* ... *)`, which do not nest, or `;` to the end of a line.

**Names** are a letter or `_`, then letters, digits and `-`. A hyphen is an
ordinary character in a name: `line-comment` and `emit-c` are one name each.

**Literals** are written in double or single quotes, and take these escapes:

```
\"   \\   \n   \t   \r   \0   \'   \xHH
```

`\0` is a real NUL and survives into a generated compiler — a literal holding
one is frozen with its length, not with `strlen`.

**Numbers** are `45` (an integer) and `45.0` (a float). There is no other
numeric literal syntax in an action.

**A directive may be terminated with a `.`**, as everything else in the
notation is. Without one, its arguments end at the end of the line.

### Reserved words are worked out, not declared

**Every word-shaped literal in the syntactic half becomes a reserved word.** A
grammar writing `"begin"` in a syntactic rule cannot then see `begin` arrive as
an identifier, and nothing had to say so.

This is why importing a grammar module costs something:
[`lib/expression.phx`](../lib/expression.phx) writes `"and"`, `"or"` and
`"not"`, so a language importing it cannot have identifiers of those names.
`div` and `mod` are deliberately *not* in that module for the same reason.

Inside a **pass**, the words `of`, `and`, `or`, `not`, `div`, `mod`, `thread`,
`down` and `otherwise` are operators, and `true`, `false` and `nil` are values.
All of them are still perfectly good *field* names, because the reader knows an
operator from a field by where it is looking.

**`pos` is reserved across the whole notation.** A grammar building a node with
a field of that name, or a pass defining an attribute of that name, is refused
when the description is read — because `$pos` has to mean one thing in every
clause of every pass.

---

## 3. Directives

| | |
| --- | --- |
| `%tokens` | what follows is lexical. This is the default, so it is optional |
| `%syntax` | what follows is matched over tokens |
| `%fragment a b .` | these lexical rules are helpers and never tokens on their own |
| `%skip a b .` | these token kinds are produced and then thrown away |
| `%start name .` | the goal rule. The first syntactic rule if unsaid |
| `%ignorecase .` | letters compare without regard to case |
| `%import "path" .` | read that module into this grammar |
| `%embed name "path" .` | that file's bytes, readable as `$name` |
| `%require name .` | this module leaves that rule open |
| `%include Type field .` | which node an include is built as, and which field holds the file |
| `%pass name` | clauses, until the next directive |
| `%rewrite name strategy` | rewrite rules, until the next directive |
| `%driver name = a, b -> attr .` | stages in order, and which attribute of the root is the answer |

An unknown directive is refused and the message lists the ones there are.

### `%fragment`

`letter` and `digit` are lexical rules and are **not** tokens; they are what the
token rules are written out of. Nothing about their shape says so, and a
scanner taking the longest match with ties broken by declaration order returns
a whole file as a stream of `letter`, because both rules match `x` and `letter`
is declared first. Phoenix warns when a rule looks like a forgotten fragment.

### `%skip`

`%skip` is deliberately **not** in `lib/lexical.phx`. Whether whitespace is
thrown away is the language's business — a layout-sensitive language keeps it —
so the description that imports the lexical rules says so itself.

### `%import`

A description is read into **one** grammar however many files it came from. A
diagnostic always names the file a rule came from, with that file's own line
numbers. `--imports` lists what a description was assembled from, which is what
a Makefile that rebuilds on a change wants.

Two rules of the same name in two files is an error: modules merge, they do not
override.

The split that matters is not grammar-versus-passes. It is **the language**
against **the target**: everything upstream of emitting belongs to the language
and has no opinion about C, so `pascal.phx` is imported by both `pascal-c.phx`
and `pascal-outline.phx` and knows about neither.

### `%require`

```ebnf
%require primary .
unary = "-" u:unary -> Negate(value: $u) | "(" expression ")" -> $2 | primary .
```

A module says what it needs and leaves it open. A description with an open hole
**reads** fine — that is what a module is — and is refused, by name, the moment
something asks it to parse a file:

```
lib/expression.phx: this description has holes in it, so it cannot parse an-expression.txt
phx:   'primary' is required and never defined
```

### `%embed`

```
%embed runtime "awk-runtime.c" .
...
: out = join([$runtime, $declarations], "\n") .
```

The file is read when the description is read, and its bytes are frozen into
whatever `-o` writes — so *one file, no headers, no library* still holds.

The reason it exists is not that the literals were ugly. Seven hundred lines of
C inside a `.phx` **cannot be compiled**, so the artefact that had been tested
was never the artefact in the repository. Now it is one file that `make test`
compiles on its own.

`--imports` names embedded files too. Embedding two files under one name is
refused.

### `%include`

`%import` is about the *description*. A target language often has the same
thing about its own files — Solveig writes `@include "library.sol"` — and that
one is not a pass and cannot be:

> **A pass is a walk over one tree that has already been read.** An include is a
> second file, which has to be read before there is a tree to walk.

So it is a directive the reader acts on, and it says two things:

```ebnf
include = "@include" p:string -> Include(path: slice($p, 2, size($p) - 1)) .
%include Include path .
```

which node an include is built as, and which of its fields holds the file. What
happens then is fixed: the file is read with this same grammar, and **the items
its root holds take the include node's place in the list that held it**, before
the first pass. A backend needs no clause for an include and never meets one.

The quotes come off in the *action*, not in the reader — how a language spells a
string is the one thing only its own description knows.

Two shapes are refused rather than guessed at: an include where a **field** is
expected, since a file is a number of things and a field holds one; and a file
whose root holds two parts, since nothing says which of them a statement
position wanted.

`--no-includes` asks about one file's own text instead, with the include nodes
still in the tree — which is what a round trip is a question about.

---

## 4. The grammar

The notation is Wirth's, from *What can we do about the unnecessary diversity of
notation for syntactic definitions* (1977):

```ebnf
production = identifier "=" expression "." .
expression = term { "|" term } .
term       = factor { factor } .
factor     = identifier | literal | "(" expression ")"
           | "[" expression "]" | "{" expression "}" .
```

The older shape is read by the same reader: `<name>` is a name, `=` and `:=`
and `::=` are all the definition symbol, and the trailing `.` is optional.

### Factors

| | |
| --- | --- |
| `name` | another rule |
| `"lit"` | a literal |
| `( a b )` | grouping |
| `[ a ]` | optional |
| `{ a }` | repetition, zero or more |
| `"a" .. "z"` | a range of one character — **lexical only** |
| `! factor` | one character, provided that does not match here — **lexical only** |
| `l:factor` | a label |

`"{" { ! "}" } "}"` is a brace comment. Using `..` or `!` where there are only
tokens is an error with a line number: it asks about characters where there are
none.

**There is no "any character".** `! ""` never matches — an empty literal always
matches, so "one character provided nothing matches here" always fails. Write
out the alternatives you mean.

### The value of a factor

This is the part that surprises people, so it is worth stating exactly.

| | |
| --- | --- |
| a literal | the text it matched |
| a rule | whatever that rule answered |
| `( ... )` | whatever the group produced, by the rule below |
| `[ ... ]` | **a list** — empty when it did not match, otherwise everything it matched |
| `{ ... }` | **a list**, holding everything **every** iteration produced, flattened |

The repetition rule catches people out:

```ebnf
line = { integer ";" } -> L(items: $1) .        (* 4;9;  gives ["4", ";", "9", ";"] *)
line = { i:integer ";" -> $i } -> L(items: $1) . (* 4;9;  gives ["4", "9"] *)
```

An iteration with more than one factor and no action contributes all of them.
Put an action inside the repetition — or make the body a single rule — when you
want one value per iteration.

### The two halves

A grammar for a language is written over **tokens** and says nothing about how
characters become them. `%syntax` names the seam, and it is declared rather than
guessed: a rule is not lexical because of anything about its shape —
`identifier` and `expression` look alike — and a tool that guesses wrong reports
a correct file as broken.

**The lexical half takes the longest match** over every token rule, ties going
to the rule declared first. That is what every lexer does, and it makes
`"<" | "<="` a question nobody has to answer *between* rules.

**The syntactic half is ordered choice with local backtracking** — a PEG, not a
general parser. `a | b` tries `a`, and tries `b` only if `a` failed; if `a`
succeeds and the rule around it fails later, the choice is not revisited.

That is a real restriction. It costs nothing on an LL(1) grammar, which is what
nearly every published grammar is. It costs a syntax error on a correct file
where an alternative is a proper prefix of a later one. **Within a rule, ordered
choice applies to the lexical half too**, so `symbol = ":=" | ":"` must put the
longer first — Phoenix warns when it does not.

When a PEG fails at the top it has usually backtracked a long way from the real
mistake, so the position reported is the one the match got **furthest**, not the
one it stopped at.

---

## 5. Actions — what a production builds

`->` after an alternative says what it *means*, as against what it looks like.

```ebnf
program   = { statement } -> Program(body: $1) .

statement = "print" e:expression ";"            -> Print(value: $e)
          | "let" n:name ":=" e:expression ";"  -> Let(name: $n, value: $e) .

factor    = number             -> Number(value: $1)
          | "(" expression ")" -> $2 .
```

| | |
| --- | --- |
| `$1`, `$2` … | the n'th factor, counting from **one** and counting **everything**, literals included |
| `$name` | a labelled factor, which survives the alternative being edited |
| `$$` | what has been built so far |
| `$pos` | where this node came from |

Both `$n` and `$label` are checked when the grammar is read, because `$3`
drifting after a factor is inserted before it is yacc's most famous silent
failure: the grammar still builds and the tree is quietly wrong.

### Building a node

`Name(field: value, ...)` builds a node. **A capital starts a node type and a
lower-case letter starts a function call** — that is the one convention the
notation asks for, and it is what lets `Empty` be a node with no fields while
`empty` is a call with no arguments.

A node with no fields is written bare: `-> Halt`.

### `$$`, and why a fold needs saying only once

`$$` is what has been built so far. An action mentioning it **replaces** the
value before it rather than following it — which is a left fold:

```ebnf
expression = term { ( "+" | "-" ) term -> Binary(op: $1, left: $$, right: $2) } .
term       = factor { ( "*" | "/" ) factor -> Binary(op: $1, left: $$, right: $2) } .
```

Precedence comes from the grammar, associativity from the fold, and
`width * height - 1` comes out as `Binary(-, Binary(*, width, height), 1)`.

`$$` inside a repetition whose enclosing alternative builds something of its own
is refused: the fold and the value it would fold onto are in different lists.

### No action at all

> **A body that produced one value answers that value. A body that produced any
> other number answers a node named after the rule, holding them.**

So a chain of rules that each pass one thing along — `expression` to `term` to
`factor` to a number — collapses to the number, and nobody had to say so. The
useless interior nodes that every hand-written tree-builder exists to strip are
not stripped; they are never built.

The node a rule with no action builds is named after the rule **exactly as
written**, in lower case: `line = one-thing ";" .` builds a `line`.

### `--nodes`

```
$ bin/phx --nodes languages/calc/calc.phx
Position(line, column, file, endline, endcolumn)
Number(text)
Variable(name)
Binary(op, left, right)
Program(body)
Print(value)
Let(name, value)
```

That is the surface a pass will be written against. A type built with two
different field lists is a warning, since a pass keyed on it would have to
handle both.

### `$pos`

Every node carries a position, and `$pos` answers a **node**:

```
Position(line, column, file, endline, endcolumn)
```

which is the whole of the design. A number would have meant nothing to a
description — every use a description has for a position is a line or the name
of a file — and a node makes reading part of one an ordinary field read, so a
fifth thing later is a field rather than a second reserved name. `endline` and
`endcolumn` arrived exactly that way.

**A node is a stretch of source and not a point.** That matters wherever
something is emitted after the things it is about: a send's own bytes go in
after its arguments, so the line they belong to is where the argument list
*ends*.

`line` and `column` count from one. `file` is the file that stretch of source
came from, which after an include is not necessarily the one the command line
named. Because `.` over a list already means *that of each*, a table with a row
per statement is written the way every other list is:

```
Program : lines = bytes($body.pos.line, 4) .
```

A node built by a **rewrite** takes the position of the node it replaced, so a
later diagnostic points at the program rather than at the rule.

---

## 6. Passes

```
%pass typecheck
  thread env = empty
  otherwise type = "void"

  Variable : type = lookup($env, $name)
           ! not defined($env, $name) : "'{}' is not defined" of $name .

  Let      : env  = bind($env, $name, $value.type)
           : type = "void" .
```

A pass is **one walk, post-order, with two phases at each node**. A clause is
keyed on a pattern; rules are tried in order and the first match wins.

### Clause forms

| | |
| --- | --- |
| `: attr = e` | **synthesised** — computed on leaving, after the children |
| `: down attr = e` | **inherited** — computed on entering, before the children, and visible to everything below this node |
| `: attr = e` where `attr` was declared `thread` | **threaded** — computed on leaving, and the value flows on to whatever the walk visits next |
| `! condition : message` | a **check** |

A rule is a pattern, then one or more of those, then an optional `.`:

```
Assign : type = "void"
       ! not defined($env, $name) : "'{}' is assigned before it is declared" of $name
       ! $value.type <> lookup($env, $name)
           : "'{}' holds {}, and this assigns {}"
               of $name, lookup($env, $name), $value.type .
```

### Reading things

| | |
| --- | --- |
| `$field` | a field of the node this clause matched |
| `$binding` | a name bound by the pattern |
| `$attr` | an attribute handed down, or the current value of a thread |
| `$child.attr` | an attribute of a child |
| `$list.attr` | *that of each* — a list of the attribute over every element |
| `$embedded` | the bytes of a `%embed`ed file |
| `$pos` | this node's position |
| `f(x).attr` | an attribute of whatever an expression answered |

These resolve in a fixed order — `$pos`, then a binding, then a field, then an
attribute of any kind, then an embedded file. **A binding wins over a field**,
which is what lets a pattern rename one; **a field wins over an attribute**,
which is why an attribute shadowed by a field is reported:

| the shadowed attribute is | |
| --- | --- |
| **synthesised** | a **warning** — it is computed, but nothing outside the pass can see it |
| **inherited** (`down`) | a **warning** — what it hands down still reaches a descendant with no such field, but this node cannot read what it wrote |
| **threaded** | an **error** — the clause updating the thread reads the field instead, so the thread does not pass through this node at all and every node after it carries on from a value that never went through here |

`$pos` resolves **before** bindings, fields and attributes, so that it means the
same thing everywhere.

`$child.attr` over a list is what makes a list of nodes answerable without a
map: `join($body.out, "\n")` is a whole block, and `$body.pos.line` is its line
table.

### Checks

```
! $value.type <> "int" : "print wants an int, and {} is {}" of $value.show, $value.type
```

A check runs **before** the attributes it guards — which is the point of it, and
is why a check reading those attributes is refused when the description is read.
The message is an ordinary expression, so a diagnostic can render the thing it
is complaining about using another pass's work:

```
print-a-bool.calc:3:3: error: print wants an int, and (n < 2) is bool
    print n < 2;
    ^
```

**A pass that reports an error stops the ones after it** — not because the
sequence could not continue but because it should not, since a later pass
reading what a failed one left produces consequences of the first mistake
rather than new information.

### `otherwise`

```
otherwise type = "void"
```

What a node answers for that attribute when the rule it matched has no clause
for it — including a node that matched no rule at all. It runs **after** the
node's own clauses, so it can read what they worked out, and it may name a
threaded attribute, in which case it updates the thread the way a clause would.

`languages/pascal/pascal.phx` wrote `type = "void"` twenty-one times before this
existed, with a comment saying why: *so that a node above it can read a type
without asking which kind of statement it was.*

A node with a **field** of that name reads the field, which is the node saying
so itself, and is what this is "otherwise" to.

`otherwise down` is refused: what a node hands its children is not what it
answers with. Two `otherwise` clauses for one attribute is refused: that is two
answers to one question.

It is still a clause about a node, which is why it is this rather than a
function or a macro. A description that could call a function would be a
description with two kinds of thing in it.

### Threads

```
thread env = empty
```

A threaded attribute is a fold over the tree in document order — a symbol table,
a label counter, a slot number. It is declared before the clauses that update
it, so that a clause naming it is recognisably an update rather than a
synthesised attribute that happens to share the name. The starting value may be
left off.

**A `down` clause naming a threaded attribute sets the thread for the subtree**,
which is what makes a thread nest. A thread otherwise runs in one chain along
the whole walk, which is right for anything the program has one of and wrong for
anything a scope has its own of. The save is an ordinary `down` attribute and
the restore is the node's own leaving clause, which works because a node's scope
is torn down *after* its leaving clauses run:

```
Block : down held  = $names       (* save the enclosing table   *)
      : down names = []           (* start this scope's own     *)
      ...                         (* the children fill it in    *)
      : names      = $held .      (* and the enclosing one back *)
```

A rule that resets a thread and does not restore it lets the inner value flow on
to its siblings, which is legal and is occasionally what is wanted — a slot
counter that only ever grows, say.

### Why some things need two passes

An inherited attribute runs **before** a node's children, and gathering runs
**after** them, so one walk cannot do both. Pascal's checker is two passes for
exactly this reason: a `symbols` pass gathers each block's declarations on the
way up, and a `typecheck` pass reads them on the way down.

That is also the answer to a forward reference. Nothing in a pass can look
ahead; a pass that computes the table and a later pass that hands it down does.

### What a pass cannot do

An attribute is computed **once per node, in one walk**. A loop needs its body
evaluated an unknown number of times and a branch that is not taken must leave
the variables alone, and neither is a thing a value computed once per node can
say. So an `eval` pass works on straight-line programs and no others — which is
why interpreting is for checking a language while it is being designed, and
compiling is what Phoenix is for. See
[ROADMAP 3.1](ROADMAP.md#31-an-interpreter-that-can-loop).

---

## 7. Rewrites

A `%pass` **decorates**: it works out attributes and leaves the tree alone. A
`%rewrite` **replaces**:

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(text: a), right: Number(text: b))
    => Number(text: text(int($a) + int($b))) .
```

Both halves were already there — a pattern tests and binds, and the evaluator
builds nodes — so what this adds is a traversal that puts the answer back. It is
the same matcher and the same evaluator a pass uses, so the two cannot disagree
about what a pattern means.

| Strategy | |
| --- | --- |
| `bottomup` | children first, then this node, once |
| `topdown` | this node first, then the children of whatever it became |
| `innermost` | bottom-up, and again on the result until nothing matches |

**The strategy is a word and not a default, because getting it wrong is
silent**: `2 + 3 * 4 + 1` folds to `15` bottom-up and stops at `((2 + 12) + 1)`
top-down, which asks about the outside of an expression before its inside.

`innermost` is the only one that can fail to settle, and it stops with a message
rather than running forever.

A rewrite sees what its pattern bound, `$pos`, and the fields of the node it
matched — and **nothing a pass worked out**, because it runs to change the tree
rather than to answer about one. Reading an attribute from a rewrite is refused.

A rewrite is a stage of a `%driver` like a pass and is named the same way, so a
rewrite and a pass may not share a name.

**What it is for is the thing a clause cannot say.** A clause answers *about* a
node; some things are answered by there being a different node. Solveig's
`x:ifTrue({ ... })` compiles to a jump rather than to a block, and written as
clauses that would mean conditioning thirty of `Block`'s on whether its parent
inlined it. Written as a rewrite it is one rule: the block is not something to
compile differently, it is something that should not be there.

```
Send(to: c, message: "ifTrue", args: [Block(params: [], temps: [], body: b)])
  => IfTrue(cond: $c, body: $b) .
```

---

## 8. Drivers

```
%driver c     = show, typecheck, emit-c -> out .
%driver run   = show, typecheck, eval   -> out .
%driver check = show, typecheck .
```

Stages in order, and which attribute of the root is the answer. A stage is a
`%pass` or a `%rewrite`. A driver with no `->` is a **validation run**: nothing
is printed and the exit status is all it says. The first declared is the
default, for the same reason the first syntactic rule is the default `%start`.

```sh
phx calc-c.phx prog.calc                # the first driver
phx calc-c.phx prog.calc --driver run   # by name
phx --drivers calc-c.phx                # what there is to choose from
```

**Attributes stay on the nodes between passes**, which is what makes a sequence
worth having: `typecheck` can render the expression it is complaining about
using `show`, a pass that came from a library module and knows nothing about the
language importing it.

### A driver is a claim about order, and it is checked

If a pass reads `$left.type` and the driver forgot to run `typecheck`, the
alternative to catching it here is a message from inside a pass about a missing
attribute — naming neither the driver that got the order wrong nor the pass that
would have supplied it. What each pass defines and what it reads are both
decidable when the description is read:

```
misordered-driver.phx:20:15: error: driver 'bad' runs 'typecheck', which reads
                            '.show', and nothing before it defines one
phx: 'show' defines 'show' — did the driver mean to run it first?
```

**That message is the reason to declare a driver** rather than to run passes in
whatever order they were typed.

Refused as well: a driver naming a stage that does not exist, a driver answering
with an attribute none of its passes defines, and two drivers of one name.

---

## 9. Expressions

The expression language is the same in a grammar action, a pass clause, a check
message and a rewrite. What it *means* is specified in
[semantics.md](semantics.md), which is executable; this is the summary.

### Values

Six kinds, and no others.

| | |
| --- | --- |
| **integer** | 64-bit, signed. **Overflow is an error, not a wrap** |
| **float** | IEEE 754 binary64. Floats do **not** trap |
| **text** | a sequence of **bytes**, one-based, both ends of a range included |
| **boolean** | `true`, `false`. There is no truthiness |
| **nil** | one value meaning absence. Not zero, not empty text, not `false` |
| **node**, **list** | as the grammar half builds them |

`45` is an integer and `45.0` is a float. **`1 + 1.0` is an error** — `int(x)`
and `float(x)` convert, and are the only things that do. This is the single rule
that most protects the conformance rule, because implicit conversion is where
host languages differ from one another most, and most quietly.

### Operators

Precedence, tightest first:

```
f(x)  $a.b                  call, attribute
not  -                      unary
*  /  div  mod
+  -
=  <>  <  >  <=  >=
and                         short-circuits, left to right
or                          short-circuits, left to right
of                          formatting, loosest
```

Evaluation is **left to right everywhere**, and the operands of an operator are
evaluated before it.

**`div` and `mod` are floored**, so that `a mod b` always carries the sign of
`b` — which is what makes `x mod n` an index into `n` things without a
correction:

```
 7 div  2 =  3       7 mod  2 =  1
-7 div  2 = -4      -7 mod  2 =  1
 7 div -2 = -4       7 mod -2 = -1
-7 div -2 =  3      -7 mod -2 = -1
```

C, Java and Pascal truncate instead, so **a pass modelling one of those calls
`quotient` and `remainder`** rather than `div` and `mod`. Getting this wrong is
the classic constant-folding bug: the interpreted program and the compiled one
answer differently on a negative division, and nothing else notices.

`=` and `<>` work on **any** two values and compare **structurally**: two lists
are equal when their elements are, two nodes when their type, fields and values
are. Values of different kinds are unequal rather than an error, so a guard may
ask `$x = nil` without knowing what `$x` is. `< > <= >=` work only **within** a
kind, because across kinds there is no order anyone would agree on.

### Formatting

```
"cannot add {} and {}" of $left.show, $right.show
```

`of` fills the holes left to right. `{{` and `}}` are literal braces — which is
why an emit pass writing C writes `"{{\n{}\n}}"`. Too few or too many arguments
is an error, **checked when the description is read**.

| | |
| --- | --- |
| integer | decimal digits, `-` when negative, never `+`, no padding |
| float | the **shortest decimal that reads back as the same value** — `0.1`, not `0.1000000000000000055` |
| text | itself, unquoted |
| boolean | `true` or `false` |
| nil, node, list | **an error** |

The last is deliberate. A default rendering for a node is a thing that would
silently appear in generated code, and a pass that wants one says what it is.

### Lists

`[a, b]` builds one; `...x` inside a list spreads it. **`...` of anything that
is not a list is an error**, because the likeliest way to write one is
miscounting a factor — `[$e, ...$3]` where `$3` is the third *item* rather than
the repetition builds the first element twice, and nothing downstream can tell.
That bug survived a round-trip test for months in a real grammar.

---

## 10. Patterns

A pattern tests and binds at once, and there is one for every kind a value can
be:

| | |
| --- | --- |
| `Binary` | a node of that type |
| `Binary(op: "+", left: a)` | a field written with a value tests it, with a name binds it, left out is not looked at |
| `[a, b]`, `[]` | a list of **exactly** that many, each element matching |
| `"text"`, `45`, `true`, `nil` | that value |
| `name` | anything, bound to that name — read back as `$name` |
| `_` | anything |

**Rules are tried in order and the first match wins**, in a pass and in a
rewrite alike — which is why a general pattern above a specific one is refused
rather than silently taking every case the specific one was for. Both of a
node's clauses go in one rule:

```
Block  : down indent = "{}    " of $indent
       : out = join($body.out, "\n") .
```

A second `Block` rule further down would never be reached.

Shape matching is how a clause says that two spellings differ, rather than a
conditional inside one clause — and there is no conditional in the notation, on
purpose ([ROADMAP 3.5](ROADMAP.md#35-conditionals-in-the-meta-language)):

```
Logical(op: "and") : out = "({} && {})" of $left.out, $right.out .
Logical(op: "or")  : out = "({} || {})" of $left.out, $right.out .
```

---

## 11. The library

Every entry is one a pass for a real language actually needed. `library.c`'s own
header says why the line is drawn: *a library nobody drew a line around is a
language nobody can reimplement.* See
[ROADMAP 3.4](ROADMAP.md#34-a-library-that-grows-without-deciding).

**And this section is executable.**
[`tests/grammars/library.phx`](../tests/grammars/library.phx) is every claim
below as a check, in the order they are made, and
[`library-refused.phx`](../tests/grammars/library-refused.phx) is every refusal
it names. Both run under `make test`, through `phx` *and* through a compiler
`phx` wrote — which is what the conformance rule says has to hold.

It was added because the library was held by nothing: eighteen of the
twenty-two functions had no executable check at all, and nearly every sentence
here is an edge case written down *because somebody got it wrong*. `each`
running to the longer of two lists is on this page because taking the shorter
turned `abs(i)` into `abs()`.

An **environment** is an association list — a list of `[name, value]` pairs,
most recent first. `bind` puts a pair on the front, so shadowing is what
naturally happens and nobody implemented it.

### Environments

| | |
| --- | --- |
| `empty` | the empty environment. A bare lower-case name is a call with no arguments, so `empty()` is the same thing |
| `bind(env, name, value)` | a new environment with that pair on the front. `name` may be a **list** of names — as many values as names binds them pairwise, one value binds every name to it |
| `lookup(env, name)` | the value, or `nil` |
| `lookup(env, name, default)` | the value, or that default — which is what a notation with no conditional needs |
| `defined(env, name)` | a boolean |
| `positions(list)` | a table of `[value, index]` pairs. **The index is zero-based**, which is what turns a list of names into slot numbers. A repeated element keeps its first position, matching what `lookup` would answer |

Keys are compared the way `=` compares, not as text only.

### Conversions

| | |
| --- | --- |
| `int(text)`, `int(text, base)` | base 2 to 36. An integer answers itself; **a float is refused** — narrowing has a direction, so it is named |
| `float(x)` | from text or an integer |
| `text(x)` | any value with a written form |
| `floor(f)`, `ceiling(f)`, `round(f)`, `truncate(f)` | a float to an integer, saying which direction |

### Arithmetic the target's way

| | |
| --- | --- |
| `quotient(a, b)`, `remainder(a, b)` | division that **truncates toward zero**, as C, Java and Pascal do |

These exist because there is no way to write truncation in terms of flooring in
a notation with no conditional — and without them an emit pass and an eval pass
for the same language quietly disagree about negative division.

### Text

| | |
| --- | --- |
| `size(t)` | bytes |
| `slice(t, from, to)` | one-based, both ends included. Out-of-range ends are clamped |
| `split(t, sep)` | a list of text. Splitting on nothing is an error |
| `join(list)`, `join(list, between)` | one piece of text |

Turning a Pascal `'it''s'` into `"it's"` is
`join(split(slice(t, 2, size(t) - 1), "''"), "'")`, and cannot be written any
other way here.

### Lists

| | |
| --- | --- |
| `size(x)` | elements of a list, fields of a node, bytes of text |
| `sizes(list)` | the same, for each element |
| `at(list, i)` | one-based |
| `flatten(list)` | **one level** only, because a deeper one would be guessing |
| `each(list, template)` | the template's `{}` is the element |
| `each(a, b, template)` | two lists **in step**, one hole from each. It runs to the **longer** of the two; a list that runs out contributes nothing rather than ending the walk |

There is no map and no lambda; `each` is the map, and its template is built with
`of` like any other piece of text, so the parts that do not vary are already in
it by the time it is called:

```
each($names, "{} {}{};" of $type.pre, "{}", $type.post)
```

### Bytes

| | |
| --- | --- |
| `bytes(n, width)` | one integer as `width` bytes, **least significant first**. Width is 1 to 8 |
| `bytes(list, width)` | a list of numbers gives a list of encodings — which is what a column of a table in a binary format is |

A float is written as its IEEE 754 bits, at width 8 or 4. Narrower is refused
rather than quietly rounded.

`bytes` cannot be written in the notation: there is no way to take a value apart
into bytes with arithmetic that answers integers and text that answers
characters.

---

## 12. What is checked before anything runs

Every one of these exists because getting it wrong produces the same failure: a
correct file reported as broken, at a place that is not the mistake.

### About the grammar

| | |
| --- | --- |
| left recursion | `a = a "+" b` is an infinite descent for ordered choice. Warshall over leftmost-reachability, so mutual recursion is caught too |
| a name that is not a rule | and one named by a directive but never defined |
| `..` or `!` over tokens | asking about characters where there are none |
| a literal nothing spells | `","` in the syntactic half when no token rule produces a comma — the rule can never match, and without this the message arrives at the first file with a comma in it |
| alternatives in the wrong order | `"<" \| "<="`, in the lexical half where it matters *(warning)* |
| a fragment not declared one | the `letter` trap *(warning)* |
| a rule nothing reaches | a leftover or a typo *(warning)* |
| a rule defined in two files | modules merge, they do not override |
| a module used with its hole open | `%require` names it |

### About actions

| | |
| --- | --- |
| `$n` past the last factor | and `$label` naming no factor — yacc's silent drift, made loud |
| `$$` with nothing to fold onto | the fold and its subject are in different lists |
| one node type, two shapes | a pass keyed on it would have to handle both *(warning)* |
| a field called `pos` | the name every node says its position with |
| the wrong number of `{}` holes | counted when the description is read |

### About passes

| | |
| --- | --- |
| a clause nothing can reach | a general pattern above a specific one takes every case the specific one was for |
| an attribute with a field's name | a field is read before an attribute, so nothing outside the pass could see it *(warning)* |
| an **inherited** attribute with a field's name | it hands a value down that the node itself cannot read *(warning)* |
| a **threaded** attribute with a field's name | the update reads the field, so the thread does not pass through that node — and nothing about the answer looks wrong |
| an inherited clause reading its own rule's work | `down` runs on the way in and the attribute is computed on the way out |
| a check reading the attributes it guards | a check runs first, by design |
| two `otherwise` clauses for one attribute | two answers to what a node answers when it has none of its own |
| `otherwise down` | what a node hands its children is not what it answers with |
| a clause defining `pos` | one reserved name, meaning one thing |

### About rewrites and drivers

| | |
| --- | --- |
| a rewrite named like a pass | a driver names a stage by its name, so which one it meant has to be one stage |
| a rewrite reading an attribute | it runs to change the tree, so the walk it would be reading has not happened |
| an `innermost` rewrite that never settles | it stops with a message rather than running forever |
| a driver in the wrong order | a stage reads an attribute nothing before it defines |
| a driver naming no such stage | |
| a driver answering with nothing | none of its passes defines that attribute |
| two drivers of one name | |

### About `%include` and `%embed`

| | |
| --- | --- |
| `%include` naming a node nothing builds | or a field that node has not got — the mechanism would then do nothing, quietly, and every include would reach a pass as a node it has no clause for |
| `%include` declared twice | |
| an include where one value is wanted | a file is a number of things and a field holds one |
| an included file with a two-part root | nothing says which of them a statement position wanted |
| `%embed` of a file that is not there | |
| two files embedded under one name | |

---

## Known warts

**`pos` is a reserved field name.** One word, across the whole notation.

**A grammar module imposes reserved words.** Importing
[`expression.phx`](../lib/expression.phx) means `and`, `or` and `not` cannot be
identifiers. There is no way to import a grammar and decline its vocabulary.

**There is no syntactic negative lookahead.** `!` is lexical only. The cost is
that the notation cannot describe one thing its own reader does: a production
ending without its `.`, which needs two-token lookahead.

**Ordered choice is not revisited.** Seven grammars later this has still not
cost anything, including awk, whose grammar is famously not LL(1) — both hard
cases were describable by putting the specific alternative first, and two
descriptions now rely on it rather than merely surviving it.

**There is no iteration over data.** `%rewrite innermost` reaches a fixpoint
over the shape of a tree; nothing does that over a table. The cost is
transitive closure — see [ROADMAP.md § 5](ROADMAP.md#5-known-warts).

**A field can shadow an attribute handed down**, so a `down` clause may hand a
value to its children that the node itself cannot read back. A warning; the
[threaded version](#6-passes) is an error.

**`positions` is zero-based**, alone in a notation that counts from one
everywhere else, because what it exists for is slot numbers.

[ROADMAP.md § 5](ROADMAP.md#5-known-warts) is the maintained list.
