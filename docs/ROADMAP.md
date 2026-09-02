# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

All seven stages are done; [journal.md](journal.md) records what each one cost
and what it got wrong first, and [postmortem.md](postmortem.md) scores the
predictions made here against what the evidence turned out to say.

---

## 1. The stages that remain

### 1.0 A reader-level mechanism, for a target language's imports

**The first gap that is about the shape of the tool rather than about
expressions**, and the one to decide next. `@include` splices another Solveig
file in before compiling; 24 of the files in that repository use it and the
bytecode backend refuses all 24.

A pass is a walk over **one tree that has already been read**, so no clause
can reach it. Phoenix has `%import` for its own descriptions and nothing for
the language being described. Any target with a module system wants the same
thing, so the question is not whether but where it belongs: a directive that
names which node stands for an include and how to get a path out of it, run
by the reader before the first pass, is the smallest shape that could work.

The thing to be careful about is that it makes the reader recursive over
*target* files, which is a new kind of failure — a cycle, a missing file, a
path relative to which of two files — and each needs a message with a
position.

### 1.1 A node's position, reachable from a clause

`$pos` does not exist. A node carries its position, every diagnostic uses it,
and nothing in the notation can read it. That is why the `.sob` backend emits
one line run per chunk and no file table, and why a traceback from bytecode it
produced says `[line 1]` where `solas` names the file and the line.

Everything needed is already there, which is what makes this small. What has
to be decided is what a position *is* to a description: a line, or a line and
a column, or an opaque value that only the diagnostics understand.

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

Worth waiting for a second example in a different language before deciding
that the repetition is the notation's fault rather than that description's.

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

The first is a warning and the other two are errors, because the first is legal
and merely almost never meant.

**The general shape is worth stating**: a description is read once and then run
over every program ever compiled with it, so a fault found while reading it is
found before anybody else sees it. That is the whole argument for a check
existing at all, and the reason to prefer one over a comment.

## 5. Known warts

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
