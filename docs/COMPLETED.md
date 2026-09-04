# Completed

*What is built, and what each piece cost against what it was predicted to cost.
[ROADMAP.md](ROADMAP.md) is what is **not** built; this is the other half, and
the two are meant to be read together. [CHANGELOG.md](CHANGELOG.md) is the
third question those two do not answer: **when**.*

An entry leaves the roadmap and arrives here when it is settled — which
includes being settled **against** building it, because a mechanism refused on
evidence is a decision as much as one built.

---

## The tool

C11, no dependencies, ~12,900 lines including the header.

```
phoenix/
  the runtime      support.c eval.c library.c lex.c parse.c include.c run.c
  the front        grammar.c check.c expr.c pass.c emit.c main.c
```

**The runtime is what *runs* a description**; the front is what *reads* one. A
generated compiler is the runtime plus frozen tables, written into one file —
which is why `cc pascal.c -o cpas` needs no flags, no headers and no library.

## The languages

| | | |
| --- | --- | --- |
| [`pascal/`](../languages/pascal/) | 1,434 lines, 56 node types | ISO 7185 subset: grammar, symbols, typechecker, a C backend and an outline backend. 35 programs agree with `fpc -Miso`; 5 outside the subset are refused with a position |
| [`solveig/`](../languages/solveig/) | 1,108 lines, 15 node types | a front end and a `.sob` bytecode backend. **Every `.sol` file in that repository** prints what `solas`'s bytecode prints — byte for byte, tracebacks included, nothing normalised |
| [`awk/`](../languages/awk/) | 968 lines + a 682-line C runtime, 50 node types | POSIX awk: grammar, a call check, and a compiler to C. 6 programs that e2fsprogs, ncurses and vim ship compile and print what `/usr/bin/awk` prints |
| [`solvm/`](../languages/solvm/) | 820 lines, 32 node types | an assembly language for SolVM and an assembler producing `.sob` bytecode. Two passes, because a jump names a label below it. Every program is held against `solas` instruction by instruction, and against the bytes it made last time when no Solveig is to hand |
| [`calc/`](../languages/calc/) | 362 lines, 15 node types | the smallest language worth a compiler. Two backends, and the conformance rule is checked on it |
| [`phx/`](../languages/phx/) | 256 lines | the notation described in itself. It parses itself and every other description here |

## The notation

Everything below is built, and each line names the entry that argued for it.

| | |
| --- | --- |
| `%tokens` `%syntax` | the two halves, declared and never guessed — [3.3](ROADMAP.md#33-guessing-the-lexicalsyntactic-seam) |
| `%fragment` `%skip` `%require` `%start` `%ignorecase` | the lexical vocabulary |
| `%import` | a description assembled from modules, each read once |
| `%embed` | a file's bytes under a name, frozen at read time — [1.5](#15-a-runtime-that-is-not-a-literal) |
| `%include` | a *target* language's own includes, spliced by the reader — [1.0](#10-a-reader-level-mechanism-for-a-target-languages-imports) |
| `->` actions | what a production *builds*; no host-language splices — [3.2](ROADMAP.md#32-actions-as-host-language-fragments) |
| `%pass`, clauses keyed on node type | attributes: synthesised, `down`, `thread` |
| `otherwise` | what a node answers when its own rule works nothing out — [1.3](#13-a-way-for-a-description-to-share-a-computation) |
| `%rewrite` with `topdown` `bottomup` `innermost` | replacing a node rather than decorating it — [2.2](#22-strategies--from-stratego) |
| patterns, including `[ a, b ]` over lists | one for every kind a value can be |
| `$pos` → `Position(line, column, file, endline, endcolumn)` | where a node came from, and where it ends — [1.1](#11-a-nodes-position-reachable-from-a-clause), [1.4](#14-where-a-node-ends) |
| `%driver` | the order the stages run in, and what the answer is |
| `-o` | the description written out as a C program that is its compiler |

---

## The stages

Seven were planned, after a stage 0 that was the groundwork.
[journal.md](journal.md) has the day-by-day; this is the shape, and the tags
`stage-0` … `stage-7` are where each one ends.

| | |
| --- | --- |
| 0 | read a grammar, scan and match a file, print the tree |
| 1 | `->` actions: what a production builds |
| 2 | `%pass`: clauses keyed on the vocabulary the actions build |
| 3 | `%driver`, passes that read each other's work, and `%import` with `%require` |
| 4 | actions on Wirth's Pascal, taken from the published grammar unmodified |
| 5 | `-o`: the description written out as a C program that is its own compiler |
| 6 | Pascal taken seriously — typechecking, a C backend, and `fpc` as an oracle — one directory per language, the notation described in itself, and a Solveig front end |
| 7 | Solveig, and a binary target |

*Rows 3 to 6 were corrected on 2026-09-03, when
[CHANGELOG.md](CHANGELOG.md) was written from the tags and found them
disagreeing: this table had `-o` at 4 and Pascal at 5, where both the tags and
`journal.md` have Pascal at 4 and `-o` at 5 — the journal has no stage 4 entry
at all, and its stage 5 entry is `-o`. `%import` was credited to 6; the commit
adding it is inside 3.*

**The [README](../README.md#where-it-is) numbers these differently, and is not
wrong.** Its table is the *plan*, ticked off as each row was delivered; this
one is the *delivery*, keyed to the tags. They agree everywhere except stage 4:
the plan put an emit pass writing C there, and that arrived early —
`examples/calc-c.phx` is already present at tag `stage-3` — so the `stage-4`
tag went onto the Pascal work instead. **A plan and a delivery that diverge by
one stage is not an error in either; it is the thing worth knowing, and neither
table said it before.**

What came after was not planned as stages, and each one is an entry below.

---

## Settled, and built

### 1.0 A reader-level mechanism, for a target language's imports

`%include Include path` names which node an include is built as and which field
holds the file; the reader reads that file and puts the items its root holds
where the include stood, before the first pass.

**It could not have been a pass**: a pass is a walk over one tree that has
already been read, and an include is a second file that has to be read before
there is a tree to walk.

*Predicted three new failures — a cycle, a missing file, a path relative to
which of two files.* Two of them are one message. The third was not a failure
at all: a file is read once however many ways it is reached, so a cycle ends
with nothing to detect. What the entry did not anticipate is the two refusals a
**splice** needs — an include where a field is wanted, and a file whose root
holds two parts.

Moved the Solveig oracle from 50 programs to 72.

### 1.1 A node's position, reachable from a clause

`$pos` answers a **node**, so reading part of one is an ordinary field read and
the notation needs no new syntax and no library function.

*Predicted "everything needed is already there, which is what makes this
small".* Wrong, and usefully. Reading a position is thirty lines; **using** one
is not, because a table is a value computed for every element of a list. That
sent 1.3 back to be thought about again.

### 1.3 A way for a description to share a computation

`otherwise attr = expr` — what a node answers with when its own rule works
nothing out. It runs after that rule, so it can read what the rule worked out,
and a node with a *field* of that name reads the field, which is the node
saying so itself.

*This was the most dangerous entry on the page and said so twice: every obvious
fix was a second mechanism.* The answer was **the general clause about a
node**, so the warning did not apply. The evidence that settled it was already
written: `languages/pascal/pascal.phx` had `type = "void"` twenty-one times,
with a comment saying exactly why. That is one line now.

The entry had framed the problem as *a map over a list*. It was **an attribute
every node has**, of which a list of nodes then has a column for free.

Two library entries — `sizes` and `bytes` over a list — were added a stage
earlier for cases this covers. They stay, and they are the price of answering a
question one case at a time before seeing its shape.

### 1.4 Where a node ends

*Asked whether a position is a point or a span.* It is a span. `solas` writes an
`OP_SEND` after compiling the arguments, so the line it records is where the
argument list **ends** — and a node carried only its first token.

Four programs, and one word: `$pos.line` to `$pos.endline`.

The last thing between `languages/solveig/` and an oracle it agrees with on
every byte. Nothing is normalised there now and nothing is counted apart.

### 1.5 A runtime that is not a literal

`%embed runtime "awk-runtime.c"` — a file's bytes under a name, read when the
description is read and frozen into whatever `-o` writes.

*The entry said to wait for a second customer.* **That was the wrong test.**
There is still only one. What made the case is a cost the entry had not
noticed: seven hundred lines of C inside a `.phx` cannot be **compiled**. That
runtime was written standalone and checked against awk before being embedded,
twice, and both times the tested file was thrown away and only the
transcription survived.

`awk-c.phx` went from 1,187 lines to 510, and `make test` compiles the runtime
on its own.

### 1.6 `|` as an expression operator, for `getline`

`cmd | getline` and `cmd | getline var` — the last two of awk's six forms, and
the only piece of unfinished work in any language described here.

*The entry called it small and awkward rather than deep, and said `printargs`
would have to be told where to stop if `|` became an operator.* Both right, and
the second turned out to need nothing: awk itself keeps `|` as the redirect
inside a print, and `print "echo hi" | getline x` pipes the string to whatever
command `getline x` answers. So the print ladder simply does not get the rung —
which is the split it already had, for the relation `print a > b` takes away.

**Where the rung goes is the part a reading of the ladder gets wrong**, and it
was settled against `/usr/bin/awk` rather than reasoned out:

| | |
| --- | --- |
| `"ec" "ho hi" \| getline x` runs `echo hi` | looser than concatenation |
| `"echo hi" \| getline x > 5` answers 0 | tighter than a relation |
| `cmd \| getline x \| getline y` pipes twice | a left fold |
| `"cmd" \|` then a newline is a syntax error | no `nl` after it |

Only the two bare forms may follow the pipe, which is `simple_get` in POSIX's
own grammar: the command is already where the input comes from, so `< file`
cannot follow.

Eleven lines of grammar and two `show` clauses. What holds it is
`tests/conformance/getline-pipe.awk`, run under `/usr/bin/awk` before and after
this description renders it — because the round trip alone proves only that the
description agrees with itself, and two of those four facts are ones it could
have been consistently wrong about.

Still not **compiled**: `awk-c.phx` refuses every form of `getline` by name,
and the piped one now among them.

### 2.2 Strategies — from Stratego

`%rewrite name strategy`, with Stratego's words unchanged.

*Predicted "most of the machinery is already built".* Right — the same
`match_pattern` and the same `eval_expr`, plus a traversal that puts the answer
back. A rewrite and a pass cannot disagree about what a pattern means because
there is one of each.

What the entry did not anticipate is that it needed **list patterns**: a value
can be a list and a pattern could not be one, so the shape every optimisation
over a message send asks about was not sayable.

### 2.4 Inlining a block — from `solas`

Seven rewrite rules and a clause each. `solas` compiles the block of an
`ifTrue:`, a `whileTrue:` and the rest into the enclosing chunk, behind a jump;
so does `languages/solveig/solveig-sob.phx`.

*The entry worried about "a jump over code in the middle of the chunk being
built".* A clause has no slot to patch and needs none: the code being jumped
over is a value the clause is holding, so an offset is a `size` rather than a
fixup.

Fixed the format's nesting limit, the call depth, and every extra frame in a
traceback.

---

## Settled, and not built

Three entries, and each was refused on evidence a language produced
rather than on taste.

### 1.2 Compiling the tables to code

**Settled against, after four measurements, and the fourth is the one that
settled it.** A generated compiler interprets a PEG rather than being one,
which is the price of there being **one** implementation of the notation rather
than two — see [the README](../README.md#writing-a-compiler-out) for why that
trade was made deliberately.

The first three measurements said the same thing and could not say why: the
matcher is linear in every shape tried. All three grammars were expression
languages, so *flat in all of them* had no control.

**The fourth added one.** `languages/solvm/` has no expression grammar at all —
an instruction is a mnemonic and its operands, and the first token settles which
rule matches. It is what this matcher costs when a grammar asks nothing of it:

| | steps per token |
| --- | --- |
| SolVM assembly — no ladder | 11 – 25 |
| Pascal — a shallow ladder | 12 – 31 |
| awk — fourteen rungs and juxtaposition | 221 – 2,638 |

**240× in constant, and no difference at all in curve**, over nine shapes.
Two of the nine get cheaper per token as they grow.

> The constant tracks how deep ordered choice must go before it commits. The
> curve tracks nothing.

That is what closes it. Generating code buys a constant factor on a matcher
whose constant is already within 2× of a grammar that asks nothing — and costs
a second implementation of ordered choice, of floored division, of pattern
matching. *Two implementations of one notation* is the thing this project has
refused everywhere else, and there is now a measurement saying what refusing it
costs: nothing that has been asked for.

**If it is ever reopened, the order is what makes it safe.** The tables pin the
definition down first, and code generated against them can be checked against
the interpreter that produced them. Doing it the other way round is how two
implementations appear.

*Measuring it a fourth time also found a defect in the measuring* —
`bench/run.sh` could not report a failed run, and two numbers in
[performance.md](performance.md) had been parsed out of an error message. See
the last row of *Defects found* below.

### 2.1 Reference attributes — from JastAdd

**Tested against the language it was waiting for, and lost.**

The entry had been narrowed to one case: *a reference that points forward, to a
node the walk has not reached*. Its condition was a language that needs one.
awk is that language — a function may be called above where it is defined, and
awk resolves it by name over the whole program.

Checking those calls is **two passes and twenty lines**: one collects the
functions and leaves the table on the root, the other hands it back down. A
leaving clause on the root runs after the whole subtree, so the forward
reference is answered by the *shape of the walk* rather than by a mechanism.

Two passes cost a second walk. Reference attributes cost demand-driven
evaluation and the cycle detection that walking once avoids, and would have
bought one walk instead of two. The case two passes cannot do is a dependency
that does not **stratify**, and none of Pascal, Solveig or awk has one.


### 2.3 Scope graphs — from Statix

**Settled against, and the way it was settled is the point.** The entry named
three things that would make a scope graph earn its place: modules that import
each other, scopes visible from more than one place, and a name whose meaning
depends on which path you reached it by. Pascal has none, Solveig has one flat
namespace, awk has two — so the entry had scepticism and no evidence.

**Turbo Pascal's units have all three**, so they were described:
[`languages/units/`](../languages/units/). Every rule was settled against
`fpc -Mtp` before a line of grammar was written, including one a reading of the
others gets wrong — inside a unit's initialisation section, the unit's own
interface shadows what its implementation uses.

Resolution stayed a list. All four scopes compose into one:

    Init : down env = [...$implexp, ...$ifexp, ...$env] .

*Later in a `uses` clause shadows earlier* needed no list reversed, which
matters because there is no way to reverse one: each used unit is a **node**,
so walking the clause **is** the fold.

**And a cycle between two implementations costs nothing**, which is the whole
finding. Because visibility does not compose — using `c` does not give you what
`c`'s interface used — resolving a `uses` is one lookup in a table the first
pass built, not a walk. *There is no traversal for a cycle to be a cycle in.*

So the entry's first criterion, *modules that import each other*, turns out
**not to be sufficient**. A cycle is only dangerous to a resolver that has to
follow it.

The description needed two things and both already existed: `interface` and
`implementation` had to be **nodes**, because a `down` clause reaches a whole
subtree and they need different environments — which is a truer tree anyway;
and an implementation needs its **sibling** interface's exports, which a parent
hands across because the earlier pass had already worked them out. The same
answer a forward reference gets.

**Two things here are graph-shaped, and neither is resolution.** Refusing a
circular *interface* `uses` is reachability, and this description manages it
only two units deep — a longer cycle needs transitive closure, and closure
needs a fixpoint over *data*, which nothing in this notation does. And
initialisation order is a topological sort. Both are in
[`divergent/`](../languages/units/divergent/), written down rather than hidden,
and the suite checks they are still the divergences they say they are.

**What to look for instead**, if this is ever reopened: a language where
visibility *composes* — Rust's `pub use`, ML's `open` inside a signature, a
class hierarchy several classes share. That is criterion two and three, and
Pascal units are not it.
---

## Defects found, and what found them

Every one of these was found by a test comparing Phoenix against something
outside it. None was found by reading the code.

| | |
| --- | --- |
| a literal holding a **NUL** was frozen with `strlen` | `-o` wrote a compiler that disagreed with `phx`, silently, for any description with a NUL in a literal — which every binary backend has. Found by asking what happens when the `.sob` description is written out as a compiler, which nobody had asked |
| the generated `main` had no `--raw` | so a compiler written out from a description that emits **bytes** appended a newline `phx` does not |
| `if (c) { a }; else { b }` | a `;` after a block ends the statement and orphans the `else`. Read back as the same tree, so the round trip was green. Found by running the rendering under `awk` |
| `printf("%s\n", a, b)` | a parenthesised argument list compiled to a **C comma expression** — printed the last argument, dropped the rest. Found by compiling awk that e2fsprogs ships |
| `getline line` read as two variables concatenated | `getline` was not described, so it was not a keyword. Ordinary awk, read as something else, quietly |
| `substr("abc", 0, 2)` | was `"a"`; one-true-awk says `"ab"`. POSIX can be read either way and an oracle cannot |
| `for (;;)` would not parse | the rule for "newlines or semicolons between two things" was eating a `for` header's own semicolons |
| **the benchmark could not report a failure** | `bench/run.sh` never checked `phx`'s exit status, and `--stats` writes to the same stream as a diagnosis — so a failed run was parsed out of the error text and printed as a measurement. Two numbers in [performance.md](performance.md) came from it. Found by re-running a measurement that had been called settled |

**The rule this repeats**: a round trip can be green while the parse is
consistently wrong, because what is written back out is wrong in the same way.
[journal.md](journal.md) records that three times, in two languages.

The last row is the same rule about the *instrument* rather than the subject: a
harness that cannot report failure reports something else, and a number nobody
can reproduce is where that hides.

## The specification, made to run

[semantics.md](semantics.md) says what the meta-language's arithmetic,
comparison, text and formatting *are*. Nothing checked that until
[`tests/grammars/semantics.phx`](../tests/grammars/semantics.phx): every claim
as a check, every refusal as a clause, run through `phx` **and** through a
compiler `phx` wrote — which has to complain in the same words.

> A specification nothing runs is a document about a program, and it drifts
> from it one sentence at a time.
