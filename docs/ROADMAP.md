# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

Stages 0, 1 and 2 are done; [journal.md](journal.md) records what each one cost
and what it got wrong first.

---

## 1. The stages that remain

### 1.1 `%driver` — running passes in order

**The argument for it is now concrete rather than tidy.**
[`lib/expression.phx`](../lib/expression.phx) ships a `show` pass whose whole
purpose is to be used from *another* pass's diagnostics —

```
Binary ! $left.type <> "int" : "cannot add {} and {}" of $left.show, $right.show
```

— and that needs `show` to have run before `typecheck` does. There is no way to
sequence two passes, so a written, tested, working pass in `lib/` cannot be used
for the thing it exists for.

What it needs to say: which passes, in what order, which one produces the
output, and that a pass reporting errors stops the ones after it.

### 1.2 A standalone compiler

`phx pascal.phx -o pascal.c && cc pascal.c -o cpas && cpas prog.pas`.

Phoenix emits a program containing the grammar as tables, the passes as code,
and a runtime — which in C is `phoenix/` itself, since that is what the tool is
already made of. **This is the one place targeting C only is a genuine
narrowing**, because a backend is Phoenix's own code rather than anybody's
description.

---

## 2. Borrowed, and worth borrowing

Each of these is somebody else's solved problem. [lineage.md](lineage.md) says
whose.

### 2.1 Reference attributes — from JastAdd

**The limit they fix is one stage 2 ran into and worked around.** An attribute
is computed in one post-order walk, so it cannot refer *forward* to a node the
walk has not reached. A forward declaration therefore needs two passes: collect,
then check.

A reference attribute lets a `Variable` node hold a pointer to its declaration,
so the question is asked once and answered directly. JastAddJ is a Java compiler
built on this, so the idea carries a real language.

The cost is that demand-driven evaluation comes back with it, along with the
cycle detection that was avoided by walking once —
[journal.md](journal.md#2026-09-01--stage-2-and-one-thing-the-sketch-got-wrong)
records why that was dropped, and this is the thing that would justify
revisiting it.

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

**Not yet, and the entry exists to say what "not yet" is waiting for.**
Threading an environment is doing fine on the languages tried so far. When it
stops — modules, imports, mutually recursive scopes, `with` blocks that reopen a
record's namespace — the next answer is a scope graph, not a bigger version of
the current one.

---

## 3. What is deliberately not here

### 3.1 An interpreter that can loop

`--run` evaluates attributes, and an attribute is computed **once per node in
one walk**. A loop needs its body evaluated a number of times that depends on
the program, and a branch not taken must leave the variables alone. Neither is a
thing a value computed once can say.

This is not a gap to fill. Interpreting is for checking a language while it is
being designed; compiling is what Phoenix is for, and the clauses in
[`examples/calc.phx`](../examples/calc.phx) say so where a program runs into it.

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

**A `.` is whitespace-sensitive.** `$left.val` reads an attribute; `$left .`
ends a clause. No lookahead separates them — `. Binary(op: "+")` beginning the
next clause looks exactly like a field access — so adjacency decides. It is the
one place in the notation where a space changes a meaning.

**A grammar module imposes reserved words.** Importing
[`expression.phx`](../lib/expression.phx) means `and`, `or` and `not` cannot be
identifiers, because every word-shaped literal in the syntactic half is
reserved. There is no way to import a grammar and decline its vocabulary.

**Ordered choice is not revisited.** `a | b` tries `a`, and if `a` succeeds and
the rule around it fails later, `b` is never tried. It costs nothing on an LL(1)
grammar, which is what nearly every published grammar is, and it costs a syntax
error on a correct file otherwise.
