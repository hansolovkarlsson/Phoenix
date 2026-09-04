# Changelog

*What has shipped, newest first, for somebody who is not reading the source.*

The other records are internal and answer different questions:
[journal.md](journal.md) is the day-by-day narrative and what each stage got
wrong first, [postmortem.md](postmortem.md) scores the predictions,
[COMPLETED.md](COMPLETED.md) is the standing inventory of what exists, and
[ROADMAP.md](ROADMAP.md) is what does not. **This page is the one that says
*when*.**

Phoenix versions by **stage**, tagged `stage-0` … `stage-7`. Work after stage 7
was not planned as stages; it is dated instead. There is no release cadence and
no compatibility promise yet — the notation is still being decided, and every
entry below that changes it says so.

---

## 2026-09-03 — an assembler, and documentation for a stranger

**A fourth description, and a *target* rather than a language:
[`languages/solvm/`](../languages/solvm/).** An assembly
language for SolVM and an assembler that emits `.sob` bytecode — 21 mnemonics,
labels, and blocks whose chunks nest. Phoenix can emit `.sob` and cannot read
it: a length-prefixed format needs the match to depend on a count it has just
read, and the notation has no computed repetition. `solvm --dump` stays the
reading half, and comparing what it prints for two producers of one program is
the oracle.

**Slots may be addressed by name.** Where a frame is declared as its slots'
names — `slots self, n` — an instruction may write `local n` and `outer 1, n`
rather than `local 1`. The name resolves against that frame's own declaration
and the same byte is written, so the two spellings are one program;
`programs/adder.sasm` and `adder-named.sasm` are exactly that, and the suite
compares their bytes.

**Two checks that used to be the loader's.** `outer 0` and a depth past the
outermost frame are now refused at assembly time, at both ends, matching
`serialize.c`'s `d < 1 || d > ancestor_count`. So is a slot past the frame it
addresses, `outer` included. Every rule in SolVM's `verify_chunk` is now either
guaranteed by construction or checked here, except the stack-height dataflow,
which a walk over a tree cannot do.

**Notation:** `|` became an expression operator, for awk's `cmd | getline`
([1.6](COMPLETED.md#16--as-an-expression-operator-for-getline)).

**Tool:** a field that shadows a thread or a synthesised attribute is now an
error rather than a silent win; a failed check complains once rather than
twice.

**Settled against:** scope graphs, from Statix
([2.3](COMPLETED.md#23-scope-graphs--from-statix)). Turbo Pascal's units were
described to test it and resolution stayed an association list.

**Documentation.** A manual, reference and cheatsheet for Phoenix and for the
assembler, three tutorials, and a website at
[hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
assembled from `docs/` on every push rather than committed. The tutorials are
executable: `make test` runs each one and holds the page to what actually
happens. Doing that the first time found eight defects in them.

**This page, and two corrections it caused.** Written from the `stage-*` tags,
it found [COMPLETED.md](COMPLETED.md)'s stage table disagreeing with them at
rows 4 to 6 — and then found that the [README](../README.md#where-it-is) holds
a *second* stage table which is the original plan rather than the delivery.
Both now say which they are. This page was itself wrong within the hour, and
that correction is recorded in [journal.md](journal.md) rather than hidden.

**Measured, a fourth time.** [ROADMAP 1.2](ROADMAP.md#12-compiling-the-tables-to-code)
— whether the tables should be compiled to code — came out the same way again,
now with the control it had been missing. The assembler's grammar has no
expression ladder, so it is what the matcher costs when a grammar asks nothing
of it: **11–25 match-steps per token**, against Pascal's 12–31 and awk's
221–2,638. Three grammars, 240× apart in constant and identical in curve, over
nine shapes. [performance.md](performance.md) has every number and the command
that reproduces it.

**[ROADMAP 1.2 is closed](COMPLETED.md#12-compiling-the-tables-to-code),
settled against building.** The fourth measurement is what settled it: three
flat curves with no control could not say *why* they were flat, and the
assembler supplied one. Generating code buys a constant factor on a matcher
already within 2× of a grammar that asks nothing, and costs a second
implementation of ordered choice, floored division and pattern matching.
**The roadmap now has no open entries at all** — sections 1 and 2 are empty,
and what remains is what the project has decided not to have.

**Fixed in the benchmark:** `bench/run.sh` did not check whether `phx` had
succeeded, so a failed run was parsed out of the error message and printed as a
measurement — two numbers on that page came from it. It checks now.
`bench/generate-awk.awk` and `bench/generate-solvm.awk` are new; before them
nothing in the repository could reproduce the awk figures at all.

**Tests:** 176 → 189, of which 186 need nothing outside the repository.

## 2026-09-02 — awk, and five notation entries

**A third language: [`languages/awk/`](../languages/awk/).** POSIX awk —
grammar, a call check, and a compiler to C. It is the first grammar here that
was not vendored from a specification, and the oracle carries the whole weight:
programs that e2fsprogs, ncurses and vim ship compile and print what
`/usr/bin/awk` prints.

**Notation, all five argued for by a language that needed them:**

| | |
| --- | --- |
| `%include` | a *target* language's own includes, spliced by the reader ([1.0](COMPLETED.md#10-a-reader-level-mechanism-for-a-target-languages-imports)) |
| `%embed` | a file's bytes under a name, frozen at read time ([1.5](COMPLETED.md#15-a-runtime-that-is-not-a-literal)) |
| `$pos` | where a node came from ([1.1](COMPLETED.md#11-a-nodes-position-reachable-from-a-clause)) |
| `$pos` as a **span** | `Position(line, column, file, endline, endcolumn)` — a node is a stretch of source, not a point ([1.4](COMPLETED.md#14-where-a-node-ends)) |
| `%rewrite` | `topdown`, `bottomup`, `innermost` — replacing a node rather than decorating it ([2.2](COMPLETED.md#22-strategies--from-stratego)) |

**Settled by something already built:**
[1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation), *a way
for a description to share a computation*, closed with **no new notation** —
`otherwise` had shipped at stage 2, and `languages/pascal/pascal.phx` was
already using it twenty-one times with a comment saying why. The entry had
framed the problem as a map over a list; it was an attribute every node has.

**Fixed:** a literal holding a NUL was frozen with `strlen`, so `-o` wrote a
compiler that disagreed with `phx` for any description with a NUL in a literal
— which every binary backend has. The generated `main` also had no `--raw`.

**Settled against:** reference attributes, from JastAdd
([2.1](COMPLETED.md#21-reference-attributes--from-jastadd)). awk needed a
forward reference and two passes gave it.

**[semantics.md](semantics.md) was made executable** — the arithmetic
specification is now checked rather than asserted.

## 2026-09-01 — stages 0 to 7, the tool itself

Eight tags in one day. Each is the end of a stage rather than a release.

| tag | what it delivered |
| --- | --- |
| `stage-0` | read a grammar, scan and match a file, print the tree |
| `stage-1` | `->` actions: what a production **builds**, with no host-language splices |
| `stage-2` | `%pass`, clauses keyed on the vocabulary the actions build, and `otherwise`. `docs/semantics.md` specifies the meta-language's arithmetic in its own terms |
| `stage-3` | `%driver`, passes that read each other's work, `%import`, `%require`, and `lib/expression.phx` |
| `stage-4` | actions on Wirth's Pascal, taken from the published grammar unmodified |
| `stage-5` | `-o`: a description written out as a C program that is its own compiler. **Tables, not code** — one implementation of the notation rather than two |
| `stage-6` | Pascal that typechecks and compiles to C; `fpc` as an oracle, which found six bugs on its first run and four more on the next; one directory per language; the notation described in itself; a Solveig front end |
| `stage-7` | a binary target — Solveig to `.sob` bytecode, held against `solas` byte for byte |

**The oracle is the method, and it is worth stating once.** Every language here
is checked against an existing implementation of it — `fpc` for Pascal,
`/usr/bin/awk` for awk, `solas` and `solvm` for Solveig — comparing what the
two produce rather than only what they print. The `fpc` oracle found ten bugs
in its first two runs, none of which reading the code had found.

---

## Compatibility

**None promised.** The notation is still being decided; entries leave
[ROADMAP.md](ROADMAP.md) with a verdict, and some of those verdicts change how
a description is written. Two changes so far would break an existing
description:

- `$pos` became a **span** — `Position` gained `endline` and `endcolumn`.
  Reading `$pos.line` is unaffected, and both landed on 2026-09-02 hours apart,
  so only a description written between the two commits is affected at all.
- A field that shadows a thread or a synthesised attribute is now an **error**.
  A description relying on the old silent behaviour will be refused, with a
  position.

The `.sob` format version is an equality rather than a floor: a SolVM build
reads exactly its own and refuses every other in both directions. Phoenix
writes 14, and `tests/run.sh` checks that against `SOL_SOB_VERSION` whenever a
Solveig checkout is to hand.
