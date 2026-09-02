# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

All seven stages are done; [journal.md](journal.md) records what each one cost
and what it got wrong first, and [postmortem.md](postmortem.md) scores the
predictions made here against what the evidence turned out to say.

---

## 1. The stages

The first two are done and are kept here rather than deleted, because what an
entry predicted and what it cost is the only way to tell whether this page is
worth writing — and one of them predicted wrong, which is the more useful
half. The rest remain.

### 1.0 A reader-level mechanism, for a target language's imports — **done**

`%include` names which node an include is built as and which field holds the
file; the reader splices, before the first pass. It was written exactly as this
entry proposed and the prediction that mattered held: *the smallest shape that
could work* was two names and a fixed meaning, and no description gets to vary
what a splice is.

The three new failures this entry warned about turned out to be two:

- **a missing file** and **a path relative to which of two files** are one
  message between them, and it has to say where it looked, because "beside the
  includer, then the search path" is the rule nobody reconstructs from a bare
  failure;
- **a cycle** was not a failure at all. A file is read once however many ways
  it is reached — which `%import` already did one level up, for the same
  reason — so a file that comes round to itself finds itself already read and
  contributes nothing. There was nothing to detect.

What the entry did not anticipate is the pair of refusals that the *splice*
needs: an include where a field is expected, and an included file whose root
holds two parts. Both are "there is no answer to what this would mean", and
both are where a tool of this shape has to say so rather than pick.

**It moved the Solveig oracle from 50 programs to 72**, and the 22 it added
found nothing wrong with the backend — which is the useful negative result. It
did surface something already there; see [2.4](#24-inlining-a-block--from-solas).

### 1.1 A node's position, reachable from a clause — **done**

The question this entry posed was *what a position is to a description*: a
line, a line and a column, or an opaque value only the diagnostics understand.
The answer is **none of the three** — it is a node:

```
Position(line, column, file)
```

which makes reading part of one an ordinary field read, needs no new syntax and
no library function, and takes a fourth thing later as a field rather than as a
second reserved name. `$pos` resolves before bindings, fields and attributes so
that it means one thing everywhere, and the cost is stated rather than
discovered: `pos` is a word a grammar may not call a field, refused when the
description is read.

`.` over a list already means "that of each", so `$body.pos.line` is a column
of line numbers, and that is the shape a table in a binary format wants.

**"Everything needed is already there, which is what makes this small" was
wrong**, and the way it was wrong is the useful part. *Reading* a position is
small — thirty lines. *Using* one is not: a `.sob` line table is a run per
statement, and building it needs a value computed for every element of a list,
which the notation cannot do. Two things closed that gap and both are listed in
[3.4](#34-a-library-that-grows-without-deciding); what it could not close is
[1.3](#13-a-way-for-a-description-to-share-a-computation), which now has its
second example.

What it bought: the line table is exact, the file table is written whenever a
chunk is about one file, and the Solveig oracle stopped normalising locations
away. Sixty-six programs now agree on every byte of their output, tracebacks
included.

### 1.2 Compiling the tables to code

A generated compiler interprets a PEG rather than being one, which is the price
of there being **one** implementation of the notation rather than two — see
[the README](../README.md#writing-a-compiler-out) for why that trade was made
deliberately.

**Measured, and the case for doing it is weak.** [performance.md](performance.md)
has the numbers: the matcher is linear in all four shapes tried, at about 24
match-steps per token, and 20,000 lines of Pascal reach running C in 238 ms.
Memoisation would cut the constant and cost a table per position; generating
code would cut it further and cost a second implementation of the notation.
Nothing has asked for either.

If it is ever done, the order is what makes it safe: the tables pin the
definition down first, and code generated against them can be checked against
the interpreter that produced them. Doing it the other way round is how two
implementations appear.

### 1.3 A way for a description to share a computation

The append-if-absent idiom appears six times in
[`solveig-sob.phx`](../languages/solveig/solveig-sob.phx) — once per node type
that interns a name — because there is no way to name a shared computation.
The notation has clauses keyed by node type and nothing else.

**It is not urgent and it is the most dangerous entry on this page**, because
the obvious fixes are all a second mechanism: a function, a macro, a rule
other rules call. Each one would be the first thing in the notation that is
not a clause about a node, and the reason this tool is small is that there is
only ever one of those.

**The second example arrived with [1.1](#11-a-nodes-position-reachable-from-a-clause),
and it is a different shape.** The first was a computation repeated because
several node types do the same thing. This one is a computation the notation
cannot express *at all*:

> **A value computed for every element of a list.** `each` applies a *template*
> to a list, and a template can only write an element out. There is no way to
> say "for each of these, this expression of it".

Two library entries covered the cases the `.sob` line table needed — the size
of each element, and each of a column of numbers as fixed-width bytes — and one
case is still open, because it is a `lookup` per element: a chunk holding code
from two files needs a run per statement naming a row of a table of the
distinct files, and a description cannot compute that column. The `.sob` file
table is therefore written only when a chunk is about one file, which is the
honest answer rather than a wrong file name.

That the fix was **two library entries and then a third case it did not
cover** is the argument for reading this entry again. A map with an expression
would have covered all three at once, and it is the mechanism this page keeps
warning about.

Still worth waiting for a second *language* before deciding, but the evidence
has moved: it is no longer only about repetition.

---

## 2. Borrowed, and worth borrowing

Each of these is somebody else's solved problem. [lineage.md](lineage.md) says
whose.

### 2.1 Reference attributes — from JastAdd

**Most of this turned out to be already here, and the entry is much smaller
than it was.**

Both cases that motivated it — `with origin do ... x ...` needing a record's
fields, and `function Area;` needing the `forward` heading it repeats — are
solved in `languages/pascal/pascal.phx` with nothing that was not already in the
notation. A value can *be* a node, `.field` reads one wherever it came from,
and an environment binding a name to the thing it was declared as is an
ordinary list of pairs. Following `origin` to its `NamedType`, that to `Point`,
`Point` to its `RecordType` and that to its fields is four hops and no new
mechanism.

**They work because every hop points backwards** — at a node the one post-order
walk has already visited and finished with, whose attributes are therefore
computed. That is the whole of what made them look hard and the whole of why
they were not.

So what is actually missing is narrower than the literature's version:

> **A reference that points *forward*** — to a node the walk has not reached —
> which is the only case a backward lookup cannot serve.

Pascal barely has one; `forward` exists precisely so that it does not.
Mutually recursive types in a language without a forward declaration would, and
so would a language where a method may be used above where it is defined. Until
one of those is being described, this stays unbuilt, and the reason is now
evidence rather than policy.

If it is ever built, the cost is that demand-driven evaluation comes back with
it, along with the cycle detection that walking once avoided —
[journal.md](journal.md#2026-09-01--stage-2-and-one-thing-the-sketch-got-wrong)
records why that was dropped.

### 2.2 Strategies — from Stratego

The `%rewrite` deferred on day one, with the vocabulary already worked out:
`topdown`, `bottomup`, `innermost`.

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(text: a), right: Number(text: b))
    => Number(text: text(int(a) + int(b))) .
```

**Most of the machinery is already built.** Patterns match on shape and bind, so
what is missing is a traversal that replaces rather than decorates. Constant
folding is the first customer and the reason to want it.

### 2.3 Scope graphs — from Statix

**Further off than it looked.** `with` blocks that reopen a record's namespace
were named here as the thing that would break threading, and Pascal has them —
and they turned out to need nothing but an environment that binds names to
nodes, which was already expressible.

A scope graph earns its place when resolution stops being a search through a
list that the walk built in order: modules that import each other, scopes that
are visible from more than one place, a name whose meaning depends on which
path you reached it by. Pascal has none of those. Nothing has yet asked for
this, and after the `with` case it is worth being sceptical that the next thing
will either.

### 2.4 Inlining a block — from `solas`

**Found by 1.0 rather than by design**, which is why it is here rather than in
the warts: `@include` made 24 more programs compilable, and two of them cross a
line the others never reach. [1.1](#11-a-nodes-position-reachable-from-a-clause)
then made it the *only* remaining disagreement about a traceback, which is what
turns this from a curiosity into the next thing worth doing.

`solas` compiles the block of an `ifTrue:`, a `whileTrue:`, an `and:` and an
`or:` **into the enclosing chunk**, behind a jump. `languages/solveig/solveig-sob.phx`
compiles every block as a block. The bytes differ and what a program prints does
not — the two agree over sixty-six programs byte for byte — except in three
places where a block that is really a block is visible:

| | |
| --- | --- |
| a traceback | an inlined block is a frame that is not there, and the frame around it points at the statement the block is written in rather than at the send inside it. **Since [1.1](#11-a-nodes-position-reachable-from-a-clause) this is the only thing left that a traceback disagrees about**, and it is counted rather than normalised: seven programs differ in a traceback line and in nothing else |
| the format's nesting limit | `.sob` allows blocks 16 deep. `programs/pascal.sol` nests 19 and `solas` inlines its way under; this backend cannot, and the loader refuses what it writes |
| the call depth | `programs/basic.sol` is a BASIC interpreter whose own suite calls something recursive until the machine stops it, and prints what happened. One extra frame per level means it stops one test earlier |

**It is not a miscompile and it is not urgent.** What makes it worth an entry is
that it is the first thing the `.sob` backend cannot express rather than has not
got round to: an inlined block needs a jump over code that is *in the middle of
the chunk being built*, and every clause so far has answered with bytes that are
complete when the clause runs. Whether that is a gap in the notation or in that
description is exactly the question [1.3](#13-a-way-for-a-description-to-share-a-computation)
says to wait for a second example before answering, and this is a second
example of a different thing.

---

## 3. What is deliberately not here

### 3.1 An interpreter that can loop

`--run` evaluates attributes, and an attribute is computed **once per node in
one walk**. A loop needs its body evaluated a number of times that depends on
the program, and a branch not taken must leave the variables alone. Neither is a
thing a value computed once can say.

This is not a gap to fill. Interpreting is for checking a language while it is
being designed; compiling is what Phoenix is for, and the clauses in
[`languages/calc/calc.phx`](../languages/calc/calc.phx) say so where a program runs into it.

*It does cost something.* The conformance rule — the same description,
interpreted and compiled, giving the same answer — therefore covers
straight-line programs only. A second emit backend is what would restore it,
which since `%import` is about fifteen lines.

### 3.2 Actions as host-language fragments

yacc pastes C, Coco/R pastes C#, ANTLR pastes Java. It is the cheapest possible
design and Phoenix will not have it, because a description containing host code
can only ever generate that host — and *what language should the generated
compiler be written in* stops being a question anybody can ask.

### 3.3 Guessing the lexical/syntactic seam

A rule is not lexical because of anything about its shape; `identifier` and
`expression` look alike. A tool that guesses wrong reports a correct file as
broken, which is the worst thing this one could do. `%syntax` is declared.

### 3.4 A library that grows without deciding

[`phoenix/library.c`](../phoenix/library.c) is a separate file so that every
addition is visible as an addition. A compiler generator whose library keeps
growing has failed at something: the notation was not expressive enough and
nobody noticed.

The rule an entry has to meet: **a pass for a real language needed it, and it
could not be written in the notation.** `quotient` and `remainder` are the
worked example — target languages disagree about negative division, and
truncation cannot be written in terms of flooring without a conditional.

The `.sob` backend added three, and each says what was missing:

| | |
| --- | --- |
| `bytes(n, width)` | a number as little-endian bytes; of a float, its IEEE 754 bits. A binary format cannot be emitted without it |
| `int(text, base)` | Solveig writes `#45`, `$ff` and `%1010` as one node, so the marker says the base |
| `positions(list)` | the table saying where each thing is. A slot *is* a position in the frame's list of names, and `at` wants an index rather than making one |

The line table added **one more, and one extension**, and both say the same
thing about the notation — see [1.3](#13-a-way-for-a-description-to-share-a-computation):

| | |
| --- | --- |
| `sizes(list)` | the size of each element. The companion to `positions`: that one answers where each thing is, this one how big it is, and neither can be asked any other way |
| `bytes(list, width)` | a **column** of numbers, each as bytes. Not a new entry — the same function taking a list, the way `bind` takes names pairwise and `each` takes two lists — and without it a table in a binary format is written as the same line of notation once per node type that could be a row |

### 3.5 Conditionals in the meta-language

There is no `if`. Clauses match on shape, and a clause that needs a choice is
evidence for another clause:

```
Binary(op: "+") : val = $left.val + $right.val .
Binary(op: "-") : val = $left.val - $right.val .
```

This is the assumption in the design most likely to be wrong, and it is written
here so that the first thing it cannot express is recognised as this decision
arriving rather than as a puzzle.

**It has not arrived.** Tables-as-conditionals carried an entire bytecode
backend — three-way choices between a local, an outer slot and a global, an
append-if-absent on four tables at once — without wanting an `if`. What gave
way first was something else entirely: see 3.6.

### 3.6 Threaded and inherited wanted to be one thing

A threaded attribute accumulates left to right along the walk. An inherited
one is scoped to a subtree. **A `.sob` method chunk wanted both**: its own
name and constant tables, accumulated in walk order, started empty on the way
in and put back on the way out.

The fix was not a new mechanism but a meaning for a combination that had none:
a `down` clause naming a threaded attribute sets the thread for the subtree.
The save is then an ordinary `down` attribute and the restore is the node's
own leaving clause, and it nests because a stack nests. `run.c` grew eleven
lines and knows nothing about chunks.

This is the first thing the design could not express, and it is recorded here
in the terms 3.5 asked for: not a puzzle, a decision arriving.

---

## 4. What a description is checked for

Every check Phoenix makes about a description exists because getting it wrong
produces the same failure: something that looks right and is not. The three
newest are all about **when a clause runs**, and all three were mistakes made
more than once while writing `languages/pascal/`:

- an attribute with the same name as a field of the node it is on — a field is
  read first, so nothing outside the pass can see the attribute
- a `down` clause reading an attribute its own rule computes — inherited runs
  on the way in, synthesised on the way out
- a check reading the attributes it guards — a check runs before them

A fourth arrived with `%include`, and it is the same argument in a different
place: a directive that names a node type and a field of it is two names that
can be typos, and a typo in either is a mechanism that silently does nothing.
Both are decidable from the description, so both are decided when it is read.

A fifth came with `$pos`, and it is about a **name** rather than about an
order: `pos` means the same thing in every clause of every pass only if nothing
else can be called that, so a field or an attribute of that name is refused.
The cost of a reserved word is real and is the kind this project prefers to
state rather than to hide — [5](#5-known-warts) already says so about `and`
and `or`.

The first is a warning and the other two are errors, because the first is legal
and merely almost never meant.

**The general shape is worth stating**: a description is read once and then run
over every program ever compiled with it, so a fault found while reading it is
found before anybody else sees it. That is the whole argument for a check
existing at all, and the reason to prefer one over a comment.

## 5. Known warts

**`pos` is a reserved field name.** Every node has a position and `$pos` is
what reads it, in every clause of every pass — which only holds if nothing else
can be called that. A grammar building a node with a field of that name is
refused. One word, across the whole notation, and it is the same bargain as the
one below rather than a different kind of cost.

**A grammar module imposes reserved words.** Importing
[`expression.phx`](../lib/expression.phx) means `and`, `or` and `not` cannot be
identifiers, because every word-shaped literal in the syntactic half is
reserved. There is no way to import a grammar and decline its vocabulary.

**There is no syntactic negative lookahead.** `!` is lexical only, refused in a
syntactic rule because there it would ask about characters where there are only
tokens. The cost is that the notation cannot describe two things the reader
does: a production ending without its `.`, and a directive's arguments ending
at a line. The second was fixed by letting a directive be terminated; the first
stands, and `languages/phx/phoenix.phx` records it.

**Ordered choice is not revisited.** `a | b` tries `a`, and if `a` succeeds and
the rule around it fails later, `b` is never tried. It costs nothing on an LL(1)
grammar, which is what nearly every published grammar is, and it costs a syntax
error on a correct file otherwise.
