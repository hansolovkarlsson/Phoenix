# The Phoenix manual

*The notation, explained in the order you would learn it. This page argues;
[reference.md](reference.md) looks things up, [cheatsheet.md](cheatsheet.md) is
one page, and the two tutorials —
[a picture language](tutorial-picture.md) and
[an assembler](tutorial-assembler.md) — build something from nothing.*

---

## Contents

1. [What you are writing](#1-what-you-are-writing)
2. [Characters, then tokens](#2-characters-then-tokens)
3. [Tokens, then a tree](#3-tokens-then-a-tree)
4. [What a production builds](#4-what-a-production-builds)
5. [Passes](#5-passes)
6. [Order, and why some things take two walks](#6-order-and-why-some-things-take-two-walks)
7. [The expression language](#7-the-expression-language)
8. [Rewrites](#8-rewrites)
9. [Modules](#9-modules)
10. [Two things the reader does](#10-two-things-the-reader-does)
11. [Writing the compiler out](#11-writing-the-compiler-out)
12. [Working on a description](#12-working-on-a-description)
13. [Idioms and pitfalls](#13-idioms-and-pitfalls)

---

## 1. What you are writing

A `.phx` file is a **description**: it says how a language is written and what
each construct means. Phoenix turns a description into a compiler.

```
pascal.phx  ──phx──▶  pascal.c  ──cc──▶  cpas
                                          │
myprogram.pas ────────────────────────────┴──▶ myprogram.c ──cc──▶ a program
```

It is not a program — nothing runs it. It is not a grammar either, not since it
grew passes. When the file is being talked about as a *unit* — one of several,
importable, sitting in a directory — it is a **module**. `%import` brings in a
module; a module with a `%start` can stand on its own, and one without is only
ever imported.

The claim the whole tool rests on is that **a compiler is a grammar plus a
sequence of tree walks**, and that both halves can be written down instead of
programmed. What lex and yacc give you is the front of that and a syntax tree;
after it you still hand-write forward-declaration collection, type checking,
optimisation and code generation — four large modules that are mostly traversal
boilerplate and a little content, written again for every language.

A description has, in this order:

```ebnf
(* comments look like this, or a ; to the end of the line *)

%import "lexical.phx" .        (* modules, merged into one grammar *)

...lexical rules...            (* characters into tokens *)
%skip space comment .

%syntax .                      (* the seam *)
%start program .
...syntactic rules...          (* tokens into a tree, with -> actions *)

%pass name  ...clauses...      (* walks over the tree *)
%rewrite name strategy ...
%driver name = a, b -> attr .  (* what to run, in what order *)
```

Nothing else. Every mechanism below fits one of those lines.

---

## 2. Characters, then tokens

A file starts in the lexical half — `%tokens` is the default and so is optional.

```ebnf
%fragment letter digit .

letter  = "a" .. "z" | "A" .. "Z" | "_" .
digit   = "0" .. "9" .

name    = letter { letter | digit } .
integer = digit { digit } .
space   = ( " " | "\t" | "\n" ) { " " | "\t" | "\n" } .
comment = "{" { ! "}" } "}" .

%skip space comment .
```

The notation is Wirth's, which nearly every published grammar is written in and
which describes itself. Phoenix makes **three additions and no more**, because a
lexer cannot be written without them:

| | |
| --- | --- |
| `"a" .. "z"` | a range of one character |
| `! factor` | one character, provided that does not match here |
| `"\n"`, `"\t"` | the escapes, inside a literal |

All three are lexical only. Using one where there are only tokens is an error
with a line number, because it asks about characters where there are none.

`! factor` is how a comment is written: `"{" { ! "}" } "}"`. There is no "any
character" — `! ""` never matches, since an empty literal always matches and so
"one character provided nothing matches here" always fails.

**The scanner takes the longest match** over every token rule, ties going to the
rule declared first. That is what every lexer does, and it is what makes
`"<" | "<="` a question nobody has to answer *between* two rules. It does not
settle it *within* one: `symbol = ":=" | ":"` is ordered choice, and the longer
alternative has to come first. Phoenix warns when it does not.

### `%fragment`, which has to be learned

`letter` and `digit` are what the token rules are written out of. They are **not
tokens**. Nothing about their shape says so, and a longest-match scanner with
ties broken by declaration order will hand back a whole file as a stream of
`letter`, because both rules match `x` and `letter` is declared first.

```
warning: 'digit' is used only by other lexical rules and is not a %fragment
         -- it will be returned as a token of its own
phx: add `%fragment digit` if it is a helper rather than a token
```

### `%skip`

Which token kinds are produced and then thrown away. It is deliberately **not**
in `lib/lexical.phx`: whether whitespace is discarded is the language's own
business, since a layout-sensitive language keeps it.

---

## 3. Tokens, then a tree

`%syntax` names the seam, and everything after it is matched over tokens.

**The seam is declared rather than guessed.** A rule is not lexical because of
anything about its shape — `identifier` and `expression` look alike — and a tool
that guesses wrong reports a correct file as broken, which is the worst thing
this one could do.

```ebnf
%syntax .
%start program .

program   = { statement } .
statement = "print" expression ";" | "let" name ":=" expression ";" .
```

`%start` is the goal rule, and the first syntactic rule if unsaid.

**Reserved words are worked out rather than declared.** Every word-shaped
literal in the syntactic half is one, so `print` cannot arrive as an identifier
and no grammar had to say so. The other side of that bargain is that importing a
grammar module reserves *its* words too, which is why
[`lib/expression.phx`](../lib/expression.phx) says so at the top of the file and
why `div` and `mod` are deliberately not in it.

### The matcher

The syntactic half is **ordered choice with local backtracking** — a PEG, not a
general parser. `a | b` tries `a`, and tries `b` only if `a` failed; if `a`
succeeds and the rule around it fails later, the choice is not revisited.

That is a real restriction and it is said here rather than buried, because the
failure it produces is *a syntax error on a file that is correct*. It costs
nothing on an LL(1) grammar, which is what Wirth's Pascal is and what almost
every published grammar is. It costs something on a grammar with an alternative
that is a proper prefix of a later one — put the specific one first.

Three languages later this has still not cost anything, including awk, whose
grammar is famously not LL(1).

When a PEG fails at the top it has usually backtracked a long way from the real
mistake, so the position Phoenix reports is the one the match got **furthest**,
not the one it stopped at:

```
missing-semicolon.pas:13:3: error: expected else, ; or end, and found "n"
    n := n + 1;
    ^
```

---

## 4. What a production builds

Without an action, a rule answers what it matched, and the tree is the concrete
one — every bracket and semicolon in it. `->` says what an alternative *means*:

```ebnf
program   = { statement } -> Program(body: $1) .

statement = "print" e:expression ";"           -> Print(value: $e)
          | "let" n:name ":=" e:expression ";" -> Let(name: $n, value: $e) .

factor    = number             -> Number(value: $1)
          | name               -> Variable(name: $1)
          | "(" expression ")" -> $2 .
```

`$n` is the n'th factor, **counting from one and counting everything** — the
literals too. A factor can be labelled instead — `e:expression`, read back as
`$e` — which survives the alternative being edited.

**Both are checked when the grammar is read**, because `$3` drifting after a
factor is inserted before it is yacc's most famous silent failure: the grammar
still builds and the tree is quietly wrong.

### `$$`, and why a fold needs saying only once

`$$` is what has been built so far. An action mentioning it **replaces** the
value before it rather than following it — which is a left fold, and is how the
flat repetition every grammar writes for a binary operator becomes the tree it
means:

```ebnf
expression = term { ( "+" | "-" ) term -> Binary(op: $1, left: $$, right: $2) } .
term       = factor { ( "*" | "/" ) factor -> Binary(op: $1, left: $$, right: $2) } .
```

Precedence comes from the grammar, associativity from the fold, and
`width * height - 1` comes out as `Binary(-, Binary(*, width, height), 1)`.

### Interior nodes are never built

One rule decides what a production answers, and it has no exceptions:

> **A body that produced one value answers that value. A body that produced any
> other number answers a node named after the rule, holding them.**

So a chain of rules that each pass one thing along — `expression` to `term` to
`factor` to a number — collapses to the number, and nobody had to say so. The
useless interior nodes that every hand-written tree-builder exists to strip are
not stripped; they are **never built**.

### The vocabulary

`--nodes` prints what a grammar can build and the fields each node carries,
which is the surface a pass will be written against:

```
$ bin/phx --nodes languages/calc/calc.phx
Program(body)
Print(value)
Let(name, value)
Binary(op, left, right)
Number(value)
Variable(name)
```

A type built with two different field lists is a warning, since a pass keyed on
it would have to handle both.

### Where a node came from

Every node carries a position, and `$pos` reads it. It answers a **node**:

```
Position(line, column, file, endline, endcolumn)
```

A number would have been smaller and would have meant nothing to a description —
every use a description has for a position is a line or the name of a file. A
node makes reading part of one an ordinary field read, so the notation needs no
new syntax and no library function, and a fifth thing later is a field rather
than a second reserved name. `endline` and `endcolumn` arrived exactly that way.

**A node is a stretch of source and not a point.** That matters wherever
something is emitted after the things it is about: a call's own bytes go in
after its arguments, so the line they belong to is where the argument list
*ends*.

`pos` is the one reserved name in the whole notation. A grammar building a node
with a field of that name is refused when the description is read, rather than
giving two answers later.

---

## 5. Passes

A `%pass` is one walk over the tree, post-order, with two phases at each node. A
clause is keyed on a pattern and says what a node answers for an attribute.

```
%pass typecheck
  thread env = empty
  otherwise type = "void"

  Number   : type = "int" .
  Variable : type = lookup($env, $name)
           ! not defined($env, $name) : "'{}' is not defined" of $name .

  Let      : env = bind($env, $name, $value.type) .

  Binary   : type = "int"
           ! $left.type <> "int" or $right.type <> "int"
               : "'{}' wants two ints: {} is {} and {} is {}"
                   of $op, $left.show, $left.type, $right.show, $right.type .
```

### Three kinds of attribute

| | | |
| --- | --- | --- |
| `: attr = e` | **synthesised** | leaving, after the children |
| `: down attr = e` | **inherited** | entering, before the children, visible below this node |
| `: attr = e`, `attr` declared `thread` | **threaded** | leaving, and the value flows on to what the walk visits next |

That is the whole of it, and each answers a different question. *What is this
subtree?* is synthesised. *What is this node inside of?* is inherited. *What has
the walk seen so far?* is threaded — a symbol table, a label counter, a slot
number, anything that is a fold over the tree in document order.

An indentation level is the clearest inherited attribute there is: a node hands
it to its children and to nothing else.

```
Block  : down indent = "{}    " of $indent
       : out = join($body.out, "\n") .
```

### Reading

`$name` is a field of the node, or a binding from the pattern, or an attribute
handed down, or the current value of a thread — resolved in that order, so **a
field is read before an attribute of the same name**. `$child.attr` reads a
child's attribute.

`.` over a **list** means *that of each*, which is why there is no map in this
notation and no traversal to write:

```
Program : out = join($body.out, "\n") .
```

That is a whole block. `$body.pos.line` is its line table.

### Checks

```
! condition : message
```

A check runs **before** the attributes it guards, which is the point of it: a
diagnostic arrives instead of a consequence. The message is an ordinary
expression, so a complaint can render the thing it is about using another pass's
work:

```
print-a-bool.calc:3:3: error: print wants an int, and (n < 2) is bool
    print n < 2;
    ^
```

`$value.show` there came from `lib/expression.phx`, a module that knows nothing
about the language importing it.

**A pass that reports an error stops the ones after it** — not because the
sequence could not continue but because it should not, since a later pass
reading what a failed one left produces consequences of the first mistake rather
than new information.

### `otherwise`

Some attributes are answered the same way by nearly every node type.
`languages/pascal/pascal.phx` wrote `type = "void"` twenty-one times, with a
comment saying why: *so that a node above it can read a type without asking
which kind of statement it was.*

```
otherwise type = "void"
```

One clause, for every node whose own rule works nothing out — including a node
that matched no rule at all. It runs **after** that rule, so it can read what
the rule worked out, and only for the attributes the rule left alone. A node
with a *field* of that name reads the field, which is the node saying so itself,
and is what this is "otherwise" to.

**It is still a clause about a node**, which is why it is this rather than a
function or a macro. A description that could call a function would be a
description with two kinds of thing in it, and the reason this tool is small is
that there is only ever one.

What it buys, besides twenty lines of Pascal: a list of nodes has a column of
whatever every node answers. Neither `$body.runs` nor `$body.fileidx` needed a
way to map over a list — they needed an attribute every node has.

### Nesting a thread

A thread runs in one chain along the whole walk, which is right for anything the
program has one of and wrong for anything a scope has its own of. A `down`
clause naming a **threaded** attribute sets the thread for the subtree instead:

```
Block : down held  = $names       (* save the enclosing table   *)
      : down names = []           (* start this scope's own     *)
      ...                         (* the children fill it in    *)
      : names      = $held .      (* and the enclosing one back *)
```

The save is an ordinary `down` attribute and the restore is the node's own
leaving clause, which works because a node's scope is torn down *after* its
leaving clauses run. This is the mechanism a bytecode backend found the need
for: a method chunk carries its own name and constant tables, so entering one
has to start them empty and leaving one has to put the enclosing tables back,
and a single chain along the walk has no stack in it.

A rule that resets a thread and does not restore it lets the inner value flow on
to its siblings, which is legal and is occasionally what is wanted — a slot
counter that only ever grows, say.

### What a pass cannot do

An attribute is computed **once per node, in one walk**. A `while` needs its body
evaluated an unknown number of times and a branch not taken must leave the
variables alone, and neither is a thing a value computed once per node can say.

So an `eval` pass works on straight-line programs and cannot work on any other
kind. That is not a gap waiting to be filled: **interpreting is for checking a
language while it is being designed, and compiling is what Phoenix is for.**
`languages/calc/calc.phx` says so in the clauses, where a program runs into it:

```
While : out = ""
      ! true : "a loop cannot be interpreted -- compile it with emit-c" .
```

---

## 6. Order, and why some things take two walks

```
%driver c     = show, typecheck, emit-c -> out .
%driver run   = show, typecheck, eval   -> out .
%driver check = show, typecheck .
```

Passes in order, and which attribute of the root is the answer. A driver with no
`->` is a validation run: nothing is printed and the exit status is all it says.
The first declared is the default, for the same reason the first syntactic rule
is the default `%start`.

**Attributes stay on the nodes between passes**, which is what makes a sequence
worth having: `typecheck` reads what `show` worked out.

### The order is a claim, and it is checked

If a pass reads `$left.type` and the driver forgot to run `typecheck`, the
alternative to catching it here is a message from inside a pass about a missing
attribute — naming neither the driver that got the order wrong nor the pass that
would have supplied it.

```
error: driver 'bad' runs 'typecheck', which reads '.show', and nothing before
       it defines one
phx: 'show' defines 'show' -- did the driver mean to run it first?
```

**That message is the reason to declare a driver** rather than to run passes in
whatever order they were typed.

### Why two passes

An inherited attribute runs **before** a node's children; gathering runs
**after** them. One walk cannot do both, and Phoenix says so when you try:

```
error: this reads 'labels', which this rule computes on the way out
       -- and an inherited clause runs on the way in
phx: write the expression out here, or compute 'labels' in an earlier pass
```

That is why Pascal's checker is two passes — a `symbols` pass gathers each
block's declarations on the way up, and a `typecheck` pass reads them on the way
down — and it is also the whole answer to a **forward reference**. Nothing in a
walk can look ahead; a pass that builds the table and a later pass that hands it
down does. awk needed exactly that, and it took twenty lines, which is why
reference attributes were settled *against* rather than built. The assembler in
[tutorial-assembler.md](tutorial-assembler.md) is this from nothing.

---

## 7. The expression language

The same language appears in a grammar action, a pass clause, a check message
and a rewrite. What it *means* is fixed in [semantics.md](semantics.md) — which
is executable: every claim on that page is a check that `make test` runs,
through `phx` and through a compiler `phx` wrote.

### Six kinds of value

**integer** (64-bit, and **overflow is an error, not a wrap**), **float** (IEEE
754, which does *not* trap), **text** (bytes, one-based, both ends of a range
included), **boolean** (no truthiness — a condition must be a boolean),
**nil** (absence; not zero, not empty text, not `false`), and **node** and
**list**.

`45` is an integer and `45.0` is a float.

### No implicit conversion, anywhere

`1 + 1.0` is an error, not `2.0`. `int(x)` and `float(x)` convert, and are the
only things that do.

This is the single rule that most protects the property the whole design rests
on — that the interpreter and every generated compiler agree — because implicit
conversion is where host languages differ from one another most, and most
quietly.

It also means `$text` from a `number` rule is **text**, and a pass that wants to
do arithmetic on it writes `int($text)`.

### The most important thing on this page

**Phoenix's arithmetic is not the target language's arithmetic, and a pass that
folds target constants must say so.**

A pass computing `2 + 2` while compiling Pascal is doing *Phoenix's* arithmetic.
If it folds a Pascal `maxint + 1`, the answer must be *Pascal's* — and Pascal's
integers trap where another language's would wrap. Phoenix will not guess: its
arithmetic is for the compiler's own bookkeeping — counters, offsets, sizes,
table indices — and a pass modelling a target's arithmetic writes that model
out.

The sharp edge is division. **`div` and `mod` are floored**, so that `a mod b`
carries the sign of `b`:

```
 7 div  2 =  3       7 mod  2 =  1
-7 div  2 = -4      -7 mod  2 =  1
```

C, Java and Pascal truncate instead. A description emitting C therefore writes
`quotient` and `remainder`, and `languages/calc/calc.phx` says so at the one
line where it matters:

```
(* `quotient`, not `div`. Phoenix's `div` is floored and C's `/` truncates,
 * so `0 - 7 / 2` would be -4 interpreted and -3 compiled -- the same program
 * answering two things. *)
Binary(op: "/") : val = quotient($left.val, $right.val)
                ! $right.val = 0 : "division by zero" .
```

Get that wrong and you have the classic constant-folding bug: the interpreted
program and the compiled one disagree on a negative division, and nothing else
notices.

### Comparison

`=` and `<>` work on **any** two values and compare **structurally**: two lists
are equal when their elements are, two nodes when their type, fields and values
are. Values of different kinds are unequal rather than an error, so a guard may
ask `$x = nil` without knowing what `$x` is. `< > <= >=` work only **within** a
kind, because across kinds there is no order anyone would agree on.

### Formatting

```
"cannot add {} and {}" of $left.show, $right.show
```

`of` is the loosest operator there is, and fills the holes left to right. `{{`
and `}}` are literal braces, which is what an emit pass writing C needs. Too few
or too many arguments is an error checked when the description is read.

A float writes as **the shortest decimal that reads back as the same value**, so
`0.1` is `0.1`. A nil, a node or a list **has no written form** — deliberately,
because a default rendering for a node is a thing that would silently appear in
generated code.

### There is no conditional

None, on purpose ([ROADMAP 3.5](ROADMAP.md#35-conditionals-in-the-meta-language)).
Two spellings that differ are two clauses, keyed on shape:

```
Logical(op: "and") : out = "({} && {})" of $left.out, $right.out .
Logical(op: "or")  : out = "({} || {})" of $left.out, $right.out .
```

and the library carries the two places where that is not enough:
`lookup(env, name, default)` is the answer for absence, and `otherwise` is the
answer for a node with no clause.

### The library

Small, and drawn around on purpose: *a library nobody drew a line around is a
language nobody can reimplement.* Environments (`empty`, `bind`, `lookup`,
`defined`, `positions`), conversions, text (`size`, `slice`, `split`, `join`),
lists (`at`, `sizes`, `flatten`, `each`) and `bytes`. Every entry is one a pass
for a real language needed and could not write in the notation.
[reference.md § 11](reference.md#11-the-library) has all of them.

An **environment** is an association list — `[name, value]` pairs, most recent
first — so shadowing is what naturally happens and nobody implemented it. A
value can *be* a node, so an environment binding a name to the thing it was
declared as is an ordinary list, and Pascal's `with origin do ... x ...` is four
hops through one.

---

## 8. Rewrites

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

**The strategy is a word and not a default**, because getting it wrong is
silent: `2 + 3 * 4 + 1` folds to `15` bottom-up and stops at `((2 + 12) + 1)`
top-down, which asks about the outside of an expression before its inside.

| | |
| --- | --- |
| `bottomup` | children first, then this node, once |
| `topdown` | this node first, then the children of whatever it became |
| `innermost` | bottom-up, and again on the result until nothing matches |

A rewrite sees what its pattern bound, `$pos`, and the fields of the node it
matched — and **nothing a pass worked out**, because it runs to change the tree
rather than to answer about one.

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

## 9. Modules

A description is read into **one** grammar however many files it came from, and
a file is read **once** however many times it is named — so two modules may both
import a third, and two modules may import each other, without anybody arranging
for it. A cycle ends because a file that comes round to itself finds itself
already read.

A module is looked for beside the file that names it, then in the library beside
the `phx` executable (`$PHX_LIB` overrides). `--imports` lists what a description
was assembled from, which is what a Makefile that rebuilds on a change wants,
and a diagnostic always names the file it came from with that file's own line
numbers.

### The split that matters

It is not grammar-versus-passes. It is **the language** against **the target**:

| | |
| --- | --- |
| `languages/calc/calc.phx` | the grammar, the tree, `typecheck`, `eval` — none of which has an opinion about C |
| `languages/calc/calc-c.phx` | `%import "calc.phx"` and an emit pass |
| `languages/calc/calc-solveig.phx` | `%import "calc.phx"` and a different emit pass |

Everything upstream of emitting is about the source language. Only emit is per
target — which is why `calc-solveig.phx` went from ninety lines of duplicated
grammar, quietly wrong the first time `calc.phx` changed, to an emit pass and a
line naming the language.

### Modules declare their holes

An expression grammar cannot know what a language's atoms are — a number, a
name, a call, an index — and that is the one thing every language differs about.
So a module says what it needs and leaves it open:

```ebnf
%require primary .
...
unary = "-" u:unary -> Negate(value: $u) | "(" expression ")" -> $2 | primary .
```

A description with an open hole reads fine — that is what a module *is* — and is
refused, by name, the moment something asks it to parse a file. A module system
needs an interface in both directions, and `%require` is the half that is easy
to forget.

### What is in `lib/`

[`lib/expression.phx`](../lib/expression.phx) is infix with the precedence
everybody expects. Fill in `primary` and you have expressions:

```ebnf
%import "expression.phx" .
primary = integer -> Number(text: $1) | name -> Variable(name: $1) .
```

**Importing a grammar module costs two things, and both are worth stating.** It
**reserves words** — `and`, `or` and `not` cannot be identifiers in a language
that imports this one. And it **hands you a vocabulary**: the tree will contain
`Logical`, `Not`, `Compare`, `Binary` and `Negate`, and your passes have to
answer for them. Phoenix names the missing clause the first time a program
reaches for one.

[`lib/lexical.phx`](../lib/lexical.phx) is the other citizen and the simpler
one: `name`, `integer`, `real`, `hex`, `text` with escapes, three comment
shapes, `space`, and the `%fragment` declarations. Import only what a language
uses — every non-fragment rule there becomes a token kind, and a rule that
matches something the language does not have will happily match it.

**A pass is only reusable together with the grammar that produces the nodes it
keys on.** Building `expression.phx` turned up exactly **one** pass worth
sharing, and it is not a typechecker: `show` renders an expression back to
something close to what was read, for putting inside a diagnostic, and it
qualifies because it depends on the shape of these nodes and on nothing else. A
typechecker over the same nodes would need the importing language's type system;
an emit pass would need its target. Both are the caller's.

---

## 10. Two things the reader does

Two mechanisms are not passes and could not be, because they act while the file
is being read.

### `%embed` — a file's bytes, under a name

A backend that emits a language needs that language's **runtime**, and a
description has nowhere to put one. `languages/pascal/pascal-c.phx` gets away
with four `#include`s because Pascal's types are C's types.
`languages/awk/awk-c.phx` needs seven hundred lines, because awk's value model
is a string and a number at once and its one aggregate is a hash table.

```
%embed runtime "awk-runtime.c" .
...
: out = join([$runtime, $declarations], "\n") .
```

The file is read when the description is read and its bytes are frozen into
whatever `-o` writes, so *one file, no headers, no library* still holds.

**The reason is not that the literals were ugly.** Seven hundred lines of C
inside a `.phx` cannot be *compiled*. That runtime was written as a standalone
file and checked against awk before being embedded — and then the file was
thrown away, so the artefact that had been tested was not the artefact in the
repository. Now it is one, and `make test` compiles it on its own.

### `%include` — a target language's own imports

`%import` is about the *description*. A target language often has the same thing
about its own files — Solveig writes `@include "library.sol"` — and that one is
not a pass and cannot be:

> **A pass is a walk over one tree that has already been read.** An include is a
> second file, which has to be read before there is a tree to walk. No clause
> can reach it, however it is written.

So it is a directive the reader acts on, and it says two things:

```ebnf
include = "@include" p:string -> Include(path: slice($p, 2, size($p) - 1)) .
%include Include path .
```

which node an include is built as, and which of its fields holds the file. What
happens then is fixed and is not a description's to vary: the file is read with
this same grammar, and **the items its root holds take the include node's place
in the list that held it**, before the first pass. A backend needs no clause for
an include and never meets one.

The quotes come off in the *action*, not in the reader, and that is deliberate:
how a language spells a string is the one thing only its own description knows.

**The rules are C's, for C's reasons.** A file is found beside the file that
includes it — never beside the directory you were standing in, so a program
survives being moved — and failing that on the search path, `-I dir` in the
order given. `--no-includes` asks about one file's own text instead, which is
what a round trip is a question about.

---

## 11. Writing the compiler out

```sh
phx languages/pascal/pascal-c.phx -o pasc.c   # a Pascal-to-C compiler, one file
cc pasc.c -o pasc                             # no flags, no headers, no library
./pasc prog.pas > prog.c && cc prog.c -o prog && ./prog
```

A generator has two ways to produce a compiler. It can **emit code** — a
recursive-descent function per rule, a switch per pass — which is faster and is
what most of the yacc family does. Or it can **emit the description as data**
and ship the machine that already runs it.

Phoenix emits data, and the reason is the one this project keeps returning to:
the alternative is a second implementation of everything. A second matcher with
the same ordered-choice rules, a second evaluator with the same floored
division, a second pattern matcher. **Two implementations of one notation have
to agree**, and avoiding exactly that is why actions are not host-language
splices and why [semantics.md](semantics.md) exists.

So a generated compiler runs *the same* `lex.c`, `parse.c`, `eval.c` and `run.c`
that `phx` runs, over a grammar frozen into static tables, all of it written into
one file. There is nothing for the two to disagree about, because there is only
one of them.

> **The conformance rule:** the same `.phx`, interpreted and through every
> backend, produces identical output.

What it costs is speed: the generated compiler interprets a PEG rather than
being one. [performance.md](performance.md) says how much — the matcher is
linear in every shape tried, and 20,000 lines of Pascal reach running C in
238 ms.

---

## 12. Working on a description

The loop, in the order you will want it.

| | |
| --- | --- |
| `phx desc.phx` | does it read at all? Prints the grammar back, warnings and all. **Do this first, every time** |
| `phx --nodes desc.phx` | the vocabulary a pass will be written against |
| `phx --tokens desc.phx prog` | the lexical half, on its own |
| `phx --tree desc.phx prog` | the tree, whatever drivers exist |
| `phx --run PASS --show ATTR desc.phx prog` | one pass in isolation, and one attribute of the root |
| `phx --drivers desc.phx` | what there is to choose from |
| `phx --imports desc.phx` | what the description was assembled from |
| `phx --stats desc.phx prog` | match-steps per token — the constant, which should not grow with the file |
| `phx --quiet ...` | for a Makefile: the exit status is the answer |

**Read the warnings.** Every check in this tool exists because getting that
thing wrong produces the same failure — a correct file reported as broken, at a
place that is not the mistake — and the warnings are the half that were not
worth refusing outright.

**A language keeps its own tests.** `languages/pascal/tests/` holds the
published grammar it is checked against, the programs compared with `fpc`, and
the programs that must be refused.

**And build the oracle early.** The single most useful thing in this repository
is a directory of programs compiled twice — once by an existing compiler for the
language, once by the description — run, and compared byte for byte. The first
eight Pascal programs found six bugs at once, every one of them a place C's
obvious answer is not Pascal's, and none of them findable by reading the output
and thinking it looked right.

**And run the documentation.** Both tutorials on this page are executed by
`tests/tutorials.sh`, which builds every file they say to build, runs every
command they show, and checks that what came back appears *verbatim in the
page*. It was added after reading them had missed three defects that running
them found in one pass — including a command using a driver the page never
told the reader to write.

A round trip is *not* a substitute. Three tests agreed with each other for
months because they all asked the same wrong question: a miscounted `...`
spread built a wrong tree, wrote it back out wrongly *in the same way*, and
re-parsed to an identical tree. Running the program saw it at once.

---

## 13. Idioms and pitfalls

### A repetition flattens

```ebnf
line = { integer ";" } -> L(items: $1) .          (* 4;9; gives ["4",";","9",";"] *)
line = { i:integer ";" -> $i } -> L(items: $1) .  (* 4;9; gives ["4","9"]         *)
```

A `{ ... }` factor answers a **list holding everything every iteration
produced**. An iteration with more than one factor and no action contributes all
of them. Put an action inside the repetition, or make its body a single rule,
when you want one value per iteration.

An `[ ... ]` optional answers a list too: empty when it did not match.

### Label your factors

`$1` counts literals. `$3` is right until somebody inserts a factor before it,
and then it is silently wrong for the rest of the file's life. `e:expression`
and `$e` cost four characters and cannot drift.

### Put the longer alternative first

Ordered choice, in both halves. `symbol = ":=" | ":"`, not the other way round.
Phoenix warns in the lexical half; in the syntactic half it is your problem, and
the symptom is a syntax error on a correct file.

### Both of a node's clauses go in one rule

Rules are tried in order and the first match wins, so a second `Block` rule
further down would never be reached — and Phoenix refuses one.

```
Block  : down indent = "{}    " of $indent
       : out = join($body.out, "\n") .
```

The same applies to shape patterns: put `Logical(op: "and")` **above** the bare
`Logical`, never below it.

### `int($text)`, always

A number rule matched *text*. Nothing converts implicitly. The same goes the
other way: `text(n)` before a number can be joined into a string, unless `of` is
doing it for you.

### `quotient`, not `div`, when modelling C

Floored versus truncating division is the one arithmetic difference that
survives into generated code and disagrees with the interpreter only on negative
numbers.

### A node has no written form

`"{}" of $node` is an error, deliberately: a default rendering for a node is a
thing that would silently appear in generated code. Say what you want it to look
like — that is what an emit pass *is*.

### A filter is `[]` plus `flatten`

There is no filter and no conditional. A node that contributes nothing
contributes an empty list, and one level of `flatten` drops them:

```
Label : entry = [[$name, $pc]] .
otherwise entry = []
Program : labels = flatten($items.entry) .
```

### `...` of a non-list is an error, and that is a kindness

`[$e, ...$3]` where `$3` is the third *item* rather than a repetition would build
the first element twice and drop the rest. That bug lived in a real grammar for
months, invisible to a round trip, because the tree and what was written back
out were wrong in the same way.

### `positions` is zero-based

Everything else in the notation is one-based — text indices, `at`, columns.
`positions(list)` is the exception, because what it exists for is turning a list
of names into **slot numbers**, and slots start at zero.

### `otherwise` before writing the same line twenty-one times

If a clause is about to be copied to every node type, it is an `otherwise`.

### When a `down` clause will not read what you want

It is telling you the truth: gathering runs on the way up and handing down runs
on the way in. Split it into two passes and name them in the driver.

---

## Where to go next

| | |
| --- | --- |
| [tutorial-picture.md](tutorial-picture.md) | a language and a compiler, from nothing, in half an hour |
| [tutorial-assembler.md](tutorial-assembler.md) | two passes, a thread, and a forward reference |
| [reference.md](reference.md) | every directive, clause form and library function |
| [cheatsheet.md](cheatsheet.md) | one page |
| [semantics.md](semantics.md) | the meta-language's arithmetic, executably |
| [`languages/calc/`](../languages/calc/) | the smallest complete description worth reading |
| [`languages/pascal/`](../languages/pascal/) | the same shape at full size, against `fpc` |
| [ROADMAP.md](ROADMAP.md) | what is deliberately absent, and why |
