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

## 2026-09-21: a C subset begins, with `cc` as its oracle

**A C compiler has its first three constructs: [`languages/c/`](../languages/c/).**

    phx --driver arm64 languages/c/c-arm64.phx prog.c > prog.s
    cc prog.s -o prog && ./prog

`int main(){return 42;}`, then `+ - * /` with parentheses, then unary minus
and the six comparisons: a function returning `int` with no parameters, a
block, `return` with an expression over integer constants, and the two comment
shapes. Five of C's fifteen expression levels, and a comparison is an `int`
worth 0 or 1 that chains to the left the way C11 says it does. `c.phx` is the grammar and the tree and has no opinion about a machine;
`c-arm64.phx` imports it and adds one emit pass, so the split is the one every
other language here makes. The target is arm64 assembly in the syntax `cc`
assembles on this machine, and `cc` assembles and links it.

**The emit pass is a stack machine.** Every expression leaves its value in
`x0`; a binary operator pushes the left operand, computes the right, and pops
the left into `x1`, sixteen bytes a push because `sp` must stay aligned. One
rule and a table of four instructions, because a general `Binary` rule above
`Binary(op: "+")` takes everything and `phx` refuses it at read time. The
prologue and epilogue are the ones the later constructs will fill in rather
than change. Falling off the end of a
function returns 0, which C11 5.1.2.2.3 requires of `main` and permits of the
rest.

**The oracle is `cc` itself**, the way `fpc` is Pascal's and `/usr/bin/awk` is
awk's. [`tests/oracle/run.sh`](../languages/c/tests/oracle/run.sh) compiles
each program twice and compares what the two exit with, which until a function
can be called is all a program can say. Sixteen programs, among them the
groupings the folds have to get right, a quotient that truncates toward zero,
and a signed comparison. One of them, `3 > 2 > 1`, is C11 as written and an
error to this `cc` by default, so the oracle downgrades that one warning by
name rather than lose the witness. Nothing in the directory has a
hand-written expected result, which is the rule ROADMAP 6 set for the arc.

**On the roadmap.** [6.1](ROADMAP.md#61-step-one--a-subset-that-runs-and-cc-as-its-oracle)
was written on 2026-09-06 and this is its first step taken; the entry itself is
unchanged but for a marker at the construct that exists. Its three predictions
are not yet scoreable: the first is about reaching `struct` with no change to
the tool, and the tool has not been asked for anything.

**Tests:** 211 → 213. Two new ones: that the description reads, and one that
runs the oracle programs and reports how many agree with `cc`. The first
run of the suite said 212, because the check that the records' counts match
the tree was failing on a missing row and is itself one of the 213.

---

## 2026-09-05 — a second calc backend, and a conformance rule that reaches a loop

**calc compiles to awk: [`languages/calc/calc-awk.phx`](../languages/calc/calc-awk.phx).**

    phx --run emit-awk languages/calc/calc-awk.phx prog.calc > prog.awk
    awk -f prog.awk

An `%import` line, an emit pass and three drivers — no grammar, no typechecker
and no interpreter, because those are in `calc.phx` and have no opinion about
any target. It is the same twenty-four clause lines as the C backend, and
seventeen of them are identical to it character for character.

**What it is for.** Phoenix's rule is that one description, run two independent
ways, gives one answer. One of those ways was `--run eval`, which cannot
interpret a branch or a loop — an attribute is computed once per node in one
walk. So until now every calc program with control flow in it was checked by a
single backend against an expected string somebody had typed into the suite.
There are two backends under those programs now, and the suite compares their
output with each other rather than with an expectation.

**Why awk and not the parked Solveig backend.** awk needs nothing this
repository does not already need — the Makefile itself builds
`phoenix/runtime.h` by piping through `awk` — and, more to the point, **awk's
numbers are doubles**. A second backend that shared C's arithmetic could only
catch a mistake in its own clauses; this one had to write calc's truncating
division out as `int(a / b)` in a host whose `/` is floating, which is the
divergence [semantics.md](semantics.md) exists to prevent, met a second time in
a second host.

Nothing about the tool changed. This is a description, and the language a
compiler emits was never Phoenix's business.

**Syntax errors point at the mistake.** A parse that matched its goal and left
input over used to be reported at the first leftover token, with the *expected*
list from wherever the match had really got stuck — two places in one message,
and the token named was usually legal where it stood. Since a start rule that
is a repetition never fails outright, that was every syntax error in every
language described here.

    print a +;
    ^ expected -, (, integer or name, and found "print"     (before)
             ^ expected -, (, integer or name, and found ";" (after)

`parse.c` already tracked the furthest point the match reached; one path threw
it away. The fallback is unchanged for a parse that never got past the
leftover.

**A Z80 subset, and an assembler for it:
[`languages/z80/z80.phx`](../languages/z80/z80.phx).**

    phx --driver code --raw languages/z80/z80.phx prog.z80 > prog.bin
    z80asm -o want.bin prog.z80 && cmp want.bin prog.bin

326 lines: immediate loads, `inc`, `dec`, the immediate arithmetic, the
absolute jumps and calls, the relative ones, labels, and a listing backend
beside the bytes.

**And `br`, which is the point.** It assembles to a two-byte relative jump when
the target is in reach and a three-byte absolute one when it is not — a size
that depends on a distance that depends on sizes. **The description walks the
tree twice**, and the second walk is the first one written out a second time,
because the notation has no way to say *again*: walk one has met no forward
label and assumes three bytes, walk two decides against walk one's addresses,
which over-state and therefore only shrink.

That reaches the minimum on a program one round deep — `tests/oracle/chain.z80`
goes 131 to 129 — and misses by a byte on
[`divergent/two-rounds.z80`](../languages/z80/divergent/two-rounds.z80), where
the second `br` shrinking is what brings the first into range on a **third**
walk nobody makes. No fixed number of walks is the answer, which is
[ROADMAP 2.5](ROADMAP.md#25-circular-attributes--from-jastadd) — now with the
customer, the witness, and a working prototype of the mechanism in front of
it.

**The oracle is byte for byte**, which none of the others are. `z80asm`
assembles the same four programs and the two binaries are compared whole —
where Pascal and Solveig agree about what a program *prints*, and a
consistently wrong translation can survive that.

**A thread declared below the rules that update it is refused.** It used to be
silent, and silence there is a wrong answer rather than a missing one: clauses
are classified as they are read, so the rule above the declaration got an
ordinary attribute and the rule below it got the thread, and the thread reached
every node with the value it started at. The message names the fix, and
`otherwise` is covered as well as the rules.

**Tests:** 189 → 211. Twenty-two new ones: six for the calc backend; one for `<>`
and `or`, whose clauses no calc program had ever reached; one holding the
records' own counts against the tree; and two for a claim `reference.md` had
made since `%rewrite` shipped and nothing had run — **a node built by a rewrite
keeps the position of the node it replaced**, so a diagnostic from a later pass
points at the program rather than at the rule. And seven for the Z80 subset: one
that it reads, four refusals — an undefined label, one name at two addresses,
an immediate that does not fit its byte, a hand-written `jr` that does not
reach — five pinning the two walks and the one that needs a third, and the
oracle. And one for the defect below. The calc
backend's tests need `awk` to run what it emits, in the same role `cc` already
plays for the C backend; the Makefile requires both to build `phx` at all. The
Z80 oracle needs `z80asm`, and skips without it.

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
