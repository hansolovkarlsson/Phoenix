# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

All six stages are done; [journal.md](journal.md) records what each one cost
and what it got wrong first.

---

## 1. The stages that remain

### 1.1 Compiling the tables to code

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

---

## 4. Known warts

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
