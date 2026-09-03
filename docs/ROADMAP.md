# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

**This page is what is *not* built.** [COMPLETED.md](COMPLETED.md) is the other
half — the tool, the languages, the notation, and every entry that has left
here with a verdict. [journal.md](journal.md) records what each stage cost and
what it got wrong first; [postmortem.md](postmortem.md) scores the predictions.

Three languages are described and compiled: Pascal against `fpc`, Solveig
against `solas`, awk against `/usr/bin/awk`. What remains on this page is one
measurement that keeps coming out the same way and one borrowed idea nothing
has asked for. **There is no unfinished work in any language described here.**

---

## 1. The stages that remain

Seven entries have left this section; [COMPLETED.md](COMPLETED.md) has them,
with what each predicted against what it cost. Three of the seven predicted
wrong, which is the more useful half.

| | |
| --- | --- |
| [1.0](COMPLETED.md#10-a-reader-level-mechanism-for-a-target-languages-imports) | `%include` — a target language's own imports |
| [1.1](COMPLETED.md#11-a-nodes-position-reachable-from-a-clause) | `$pos` — where a node came from |
| [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation) | `otherwise` — what a node answers when its rule does not |
| [1.4](COMPLETED.md#14-where-a-node-ends) | a position is a **span** |
| [1.5](COMPLETED.md#15-a-runtime-that-is-not-a-literal) | `%embed` — a file's bytes under a name |
| [1.6](COMPLETED.md#16--as-an-expression-operator-for-getline) | `\|` as an expression operator — awk's `cmd \| getline` |

### 1.2 Compiling the tables to code

A generated compiler interprets a PEG rather than being one, which is the price
of there being **one** implementation of the notation rather than two — see
[the README](../README.md#writing-a-compiler-out) for why that trade was made
deliberately.

**Measured three times now, and the case is weaker each time.**
[performance.md](performance.md) has the numbers. The matcher is linear in
every shape tried — Pascal's four, and awk's two — and 20,000 lines of Pascal
reach running C in 238 ms.

**awk is the interesting third measurement**, because it is the grammar that
ought to have broken this: fourteen rungs of expression ladder, concatenation
with no operator, and a `print` whose arguments need six of those rungs
duplicated. It costs **370 to 2,600 match-steps per token** where Pascal costs
24 — and it is still flat, at 369 per token from 705 tokens to 11,205. A
hundred times the constant and the same curve.

And the constant does not matter: the largest program in the awk corpus is 269
lines and reaches running C in **50 ms**. Memoisation would cut it and cost a
table per position; generating code would cut it further and cost a second
implementation of the notation. The hardest grammar tried has not asked for
either.

If it is ever done, the order is what makes it safe: the tables pin the
definition down first, and code generated against them can be checked against
the interpreter that produced them. Doing it the other way round is how two
implementations appear.


## 2. Borrowed, and worth borrowing

Each of these is somebody else's solved problem. [lineage.md](lineage.md) says
whose. Three of the four are settled — two built, one **tested and refused** —
and what is left is the one this page has always said to be sceptical about.

| | |
| --- | --- |
| [2.1](COMPLETED.md#21-reference-attributes--from-jastadd) | reference attributes, from JastAdd — settled **against**: awk needed a forward reference and two passes gave it |
| [2.2](COMPLETED.md#22-strategies--from-stratego) | strategies, from Stratego — `%rewrite` |
| [2.4](COMPLETED.md#24-inlining-a-block--from-solas) | inlining a block, from `solas` |

### 2.3 Scope graphs — from Statix

**Further off than it looked**, and further still after a third language.

`with` blocks that reopen a record's namespace were named here as the thing
that would break threading, and Pascal has them — and they turned out to need
nothing but an environment that binds names to nodes, which was already
expressible.

A scope graph earns its place when resolution stops being a search through a
list that the walk built in order: modules that import each other, scopes
visible from more than one place, a name whose meaning depends on which path
you reached it by. Pascal has none of those. **Solveig has one flat global
namespace and awk has two** — globals, and a function's parameters — and awk's
is resolved by C's own block scoping in the backend, without the description
saying anything at all.

Three languages, and the shape that would want this has not appeared. After the
`with` case and after awk, it is worth being sceptical that the next one will
either.

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

**awk is what this costs, and it is worth being exact about whose problem it
is.** `/` is division and `/re/` is a regular expression, and which one it is
depends on the parser: a real awk lexer asks whether the previous token could
end an expression. Phoenix's scanner is longest match over the token rules and
has no such feedback, so `languages/awk/awk.phx` **guesses** — a regexp may not
start with a space, a tab or an `=`, and must close on the same line.

That is the description guessing, which is its business, and not the tool
guessing, which is what this entry refuses. The difference matters: the guess
is written down at the top of the file, it has a witness in
`tests/divergent/slash.awk`, and rendering that program puts the spaces in so
the divergence is **visible** rather than silent. A tool that guessed would
have had nowhere to write any of that.

What a scanner with parser feedback would cost is the thing to weigh if this
ever comes up twice: two languages have been described without wanting one, and
the third wants it in one construct.

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
thing about the notation — see [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation):

| | |
| --- | --- |
| `sizes(list)` | the size of each element. The companion to `positions`: that one answers where each thing is, this one how big it is, and neither can be asked any other way |
| `bytes(list, width)` | a **column** of numbers, each as bytes. Not a new entry — the same function taking a list, the way `bind` takes names pairwise and `each` takes two lists |

**Both are cases `otherwise` would have covered**, and that is the entry worth
reading beside this one. They were added while the question looked like *"a map
over a list"*; it was [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation)'s,
*"an attribute every node has"*, and a list of nodes then has a column of them
for free. The rule this section states was met by both and they are still here,
so the rule is not enough on its own: **a library entry answers one case, and
what it costs is the chance to see the shape of the rest.**

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

**But it has a shape, and awk found it.** `lookup` is a function, so **both
answers are worked out** before it chooses. That is fine when both can be, and
it is not when one of them cannot:

```
lookup([[true, ""]], $init = nil, "{};" of $init.out)    (* fails on the nil *)
```

A conditional would have skipped the branch it did not take. What was done
instead is worth more than the `if` would have been: the **grammar** changed so
that there is no nil. An omitted `for` part builds a `Nothing` node that renders
as nothing, every part is emitted the same way whether it is there or not, and
the question disappears rather than being answered.

That is the third time the answer to "the notation cannot say this" has been
"say something else earlier" — see [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation)
and [2.4](COMPLETED.md#24-inlining-a-block--from-solas). It is not proof that an `if` is
never wanted. It is one more case where wanting one was a sign that a tree had
the wrong shape.

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

`%rewrite` brought three more, and all three are about a **stage**: a driver
names one by its name, so two rewrites of one name, or a rewrite sharing a
pass's, is refused; and a rewrite reading `.something` a pass computes is
refused, because a rewrite runs to change the tree rather than to answer about
one and the walk it would be reading has not happened. The ordering hazard is
checked in a rewrite exactly as it is in a pass, since both try their rules in
order and the first match wins.

The first is a warning and the other two are errors, because the first is legal
and merely almost never meant.

**The general shape is worth stating**: a description is read once and then run
over every program ever compiled with it, so a fault found while reading it is
found before anybody else sees it. That is the whole argument for a check
existing at all, and the reason to prefer one over a comment.

**And two things no check can reach.** A description is checked when it is
read; what `-o` writes out is checked by *comparing* it with `phx`, and that is
only as strong as the widest thing compared. Text was compared for a year and
the one backend emitting **bytes** was never written out as a compiler at all,
so nothing noticed that a literal holding a NUL was frozen with `strlen` and
arrived short while the length beside it still said otherwise. The two
disagreed, silently, about a description they were both running. The suite
compares `.sob` files now.

The second is the **notation itself**. Every check on this page is about a
description; [semantics.md](semantics.md) is about the language descriptions
are written in, and nothing asked whether that page and `eval.c` still agreed.
They could have drifted a claim at a time with the whole suite green. Every
claim it makes is a check now, and every refusal it names is a clause, run
through `phx` and through a compiler `phx` wrote — which has to complain in the
same words. **A specification nothing runs is a document about a program.**

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

*Three languages later this has still not cost anything*, including awk, whose
grammar is famously not LL(1) — concatenation with no operator, and a `print`
whose arguments exclude a rung the rest of the ladder has. Both were describable
by putting the specific alternative first, which is what ordered choice asks
for and what a published grammar written for yacc does not say.

**A description may guess where the tool will not.** `languages/awk/awk.phx`
decides whether `/` opens a regexp by looking at the character after it,
because awk's own lexer asks the parser and Phoenix's scanner cannot — see
[3.3](#33-guessing-the-lexicalsyntactic-seam). That is the description's
business rather than the tool's, and the difference is that a description can
write the guess down, test the shapes it gets wrong, and render them back
visibly. `languages/awk/tests/divergent/` holds all three.
