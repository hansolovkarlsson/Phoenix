# SolVM assembly

An assembler for [SolVM](https://github.com/hansolovkarlsson/Solveig)'s `.sob`
bytecode: 21 mnemonics, labels, and blocks that nest.

```sh
bin/phx --raw languages/solvm/solvm-sob.phx prog.sasm > prog.sob
solvm prog.sob
```

## Writing for it

| | |
| --- | --- |
| [tutorial.md](tutorial.md) | one program in seven steps, and four mistakes made on purpose |
| [manual.md](manual.md) | the machine and how to write for it, in the order you would learn it — including the six shapes `solas` inlines |
| [reference.md](reference.md) | every mnemonic, directive and diagnostic |
| [cheatsheet.md](cheatsheet.md) | one page |

## Building it

| | |
| --- | --- |
| [`solvm.phx`](solvm.phx) | the language: the grammar, the tree, and a pass that writes it back out |
| [`solvm-sob.phx`](solvm-sob.phx) | the assembler: `layout` and `sob`, and the container |
| [`programs/`](programs/) | assembly, each with the Solveig it was written from |
| [`oracle/`](oracle/) | that Solveig, for `solas` to compile and `solvm` to run |
| [`tests/`](tests/) | files that must be refused, and the bytes each program assembled to last time |

## Why this exists

SolVM had a compiler that produced `.sob` (`solas`) and a disassembler that
read it (`solvm --dump`), and nothing in between: no way to write a chunk by
hand, and no way to check what a code generator *ought* to have emitted except
by reading its output and thinking it looked right.

It is also the thing Phoenix is most obviously for. Every hard part of
[`../solveig/solveig-sob.phx`](../solveig/solveig-sob.phx) — resolving a name
to a slot or a global, inlining `ifTrue` into jumps, lowering expressions — is
absent here, because in assembly the programmer says which. What is left is the
part that is not: **a jump names a label, and a label is very often below the
jump.**

## Phoenix can emit `.sob` and cannot read it

That is a fact about the notation rather than a gap in this description. The
format is length-prefixed — a count, then that many things — so parsing one
needs the match to depend on a number it has just read, and there is no
computed repetition in the notation. So this is the producing half, `solvm
--dump` is the reading half, and the two together are what make the oracle
below possible.

## The two passes, and why there are two

`layout` threads a byte counter to give every instruction its address, interns
the names and constants tables, and gathers the label table on the way up.
`sob` takes that table back *down* and writes the bytes.

One walk cannot do both: an inherited attribute is computed **entering** a
node and a gather finishes **leaving** it, and Phoenix says so if you try.

Both halves nest, because a block is its own chunk with its own tables, its own
code and its own addresses:

- a side-table index is assigned where a name is **first seen**, which is a
  fold over the walk in document order — a **thread**, reset for a block's
  subtree by a `down` clause naming it, and put back by the block's own leaving
  clause;
- a label is used before it is defined, so it is **gathered** instead.

Two mechanisms, because there are two questions.

## The oracle

**The same program, written twice.** Each `programs/*.sasm` has an
`oracle/*.sol` beside it that says the same thing in Solveig. `solas` compiles
one, this assembles the other, and the test compares two things:

- what each prints under `solvm`;
- and, instruction by instruction, what each compiled *to* — `solvm --dump` on
  both, with the source-line column and the chunk's name taken out, since those
  are the only two things two producers of one program are entitled to disagree
  about.

The second is the one that earns its place. `count.sasm` is the loop and
conditional whose disassembly is printed in Solveig's own `docs/BYTECODE.md`,
written back out by hand — and it assembles to that listing exactly: every byte
offset, every opcode, every side-table index, `EXITIFF 17 -> 37` and
`LOOP 30 -> 7` included. Agreeing on the *output* of four programs would be
much weaker: two wrong encodings can print the same thing.

Where there is no Solveig checkout the oracle reports itself skipped. The other
three quarters of the suite need nothing outside this repository: every program
is compared against the bytes it assembled to last time, every program is
rendered back out and re-parsed to the same tree, and every file in `tests/` is
refused with the message it is refused for.

`REGOLD=1 languages/solvm/tests/run.sh` rewrites those bytes, which is what to
do after SolVM's format version rises.

**And the tutorial is run too.** `tests/tutorial.sh` builds every file
[tutorial.md](tutorial.md) says to build, runs every command it says to run,
and then checks that the output it got **appears in the page** — so a pasted
output that drifts from the real one fails the suite rather than misleading
somebody following along. That check exists because the first version of the
page had four defects a careful read did not find: a `solvm` invoked on
bytecode nothing had assembled, three places where the source had changed and
the reader would have run the previous build, a caret line two spaces short,
and a closing comparison against a Solveig program that no longer said the same
thing.

## The format version is an equality

`.sob` carries a version, and **a build reads exactly its own and refuses every
other in both directions** — version 15 will refuse everything 14 wrote, and
the whole diagnosis is `unsupported bytecode version`. Solveig's
`docs/PRODUCING.md` says a producer should read `SOL_SOB_VERSION` at build time
rather than writing the number into its own source.

This one writes it into its own source, and the test suite checks the two agree
whenever a checkout is to hand. That is the honest trade: reading the header
would couple the description to a path outside this repository, and a failing
test says the same thing a build-time read would have, at the same moment.

## What the assembler checks, and what it cannot

It refuses a label that is not defined, a `jump` whose target is behind it
(that is `loop`) and a `loop` whose target is ahead (that is `jump`), a slot,
depth or argument count that will not fit its byte, a block named twice in one
chunk, a `block` naming no definition, a script that does not end in `halt`, a
block that does not end in `return`, a chunk too long for a two-byte offset,
and an `outer` depth past the outermost frame — the lexical chain is as long
as the nesting, so how far out a chunk can reach is knowable from the text.

It also refuses a **slot named as something the frame has not got**. A frame
may be declared as its slots' names — `slots self, n` — and where it is, an
instruction may address one by name: `local n` rather than `local 1`, and
`outer 1, n` for the frame one step out. The name is resolved against that
frame's own declaration and the same byte is written, so the two spellings are
one program: [`programs/adder.sasm`](programs/adder.sasm) and
[`adder-named.sasm`](programs/adder-named.sasm) are exactly that, and the suite
assembles both and compares the bytes.

**This is the one check the numeric spelling cannot give.** `local 0` in a
frame of two is a valid instruction that pushes the wrong thing; `local nn` is
not an instruction at all, and the refusal names what the frame does have.

**It cannot check the stack.** SolVM's verifier refuses a chunk where *two
paths reach one instruction with different stack depths*, and that is a
dataflow analysis rather than a walk over a tree — so a hand-written program
can get it wrong and hear about it from `solvm` at load time rather than from
the assembler. Nothing here pretends otherwise.

## Reserved words

**Every mnemonic is a reserved word**, worked out from the grammar rather than
declared — so a label cannot be called `loop`, a slot cannot be named `block`,
and `arity` and `slots` are spoken for too. A *selector* that collides with one is written in quotes:
`send "return", 0`.

The three named constants are `#true`, `#false` and `#nil` for exactly this
reason. Spelling them `true` and `false` would take those two names away from
every other position, and Solveig reaches its booleans **as globals** — so
`global true` is one of the first things anybody writes.
