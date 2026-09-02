# Completed

*What is built, and what each piece cost against what it was predicted to cost.
[ROADMAP.md](ROADMAP.md) is what is **not** built; this is the other half, and
the two are meant to be read together.*

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

Seven were planned. [journal.md](journal.md) has the day-by-day; this is the
shape.

| | |
| --- | --- |
| 0 | read a grammar, scan and match a file, print the tree |
| 1 | `->` actions: what a production builds |
| 2 | `%pass`: clauses keyed on the vocabulary the actions build |
| 3 | `%driver`, and passes that read each other's work |
| 4 | `-o`: the description as a C program |
| 5 | Pascal, taken seriously — and `fpc` as an oracle |
| 6 | `%import`, and one directory per language |
| 7 | Solveig, and a binary target |

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

**The rule this repeats**: a round trip can be green while the parse is
consistently wrong, because what is written back out is wrong in the same way.
[journal.md](journal.md) records that three times, in two languages.

## The specification, made to run

[semantics.md](semantics.md) says what the meta-language's arithmetic,
comparison, text and formatting *are*. Nothing checked that until
[`tests/grammars/semantics.phx`](../tests/grammars/semantics.phx): every claim
as a check, every refusal as a clause, run through `phx` **and** through a
compiler `phx` wrote — which has to complain in the same words.

> A specification nothing runs is a document about a program, and it drifts
> from it one sentence at a time.
