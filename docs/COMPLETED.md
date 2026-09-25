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

C11, no dependencies, **9,466 lines** hand-written.

The figure usually quoted is ~13,900, and both are right about different
things: `phoenix/` also holds `runtime.h`, 4,425 generated lines which are the
seven runtime files re-emitted as a C string literal so that a compiler `phx`
writes is one file. Counting it measures what is in the directory; not counting
it measures what anybody wrote. The runtime is in both numbers, once or twice.

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
| [`solveig/`](../languages/solveig/) | 1,129 lines, 15 node types | a front end and a `.sob` bytecode backend. **Every `.sol` file in that repository** prints what `solas`'s bytecode prints — byte for byte, tracebacks included, nothing normalised |
| [`awk/`](../languages/awk/) | 993 lines + a 682-line C runtime, 51 node types | POSIX awk: grammar, a call check, and a compiler to C. 6 programs that e2fsprogs, ncurses and vim ship compile and print what `/usr/bin/awk` prints |
| [`solvm/`](../languages/solvm/) | 860 lines, 32 node types | an assembly language for SolVM and an assembler producing `.sob` bytecode. Two passes, because a jump names a label below it. Every program is held against `solas` instruction by instruction, and against the bytes it made last time when no Solveig is to hand |
| [`calc/`](../languages/calc/) | 494 lines, 15 node types | the smallest language worth a compiler. **Three backends** — C, awk, and Solveig parked — and the conformance rule is checked on it. The first two both run in the suite, so a program with a loop in it is checked by two implementations rather than against an expectation somebody typed |
| [`z80/`](../languages/z80/) | 396 lines, 19 node types | a Z80 subset, an assembler making raw bytes, and a listing backend. **The customer [2.5](#25-circular-attributes--from-jastadd) was waiting for**: `br` picks between a two-byte relative jump and a three-byte absolute one, which is a size that depends on a distance that depends on sizes. `layout` assumes every forward `br` long, and `relax`, the first walk **written out a second time**, decides both directions against the last walk's table; the driver runs it `until labels` settles, since 2026-09-23, so [`two-rounds.z80`](../languages/z80/tests/oracle/two-rounds.z80) reaches its minimum on the third walk and [`three-rounds.z80`](../languages/z80/tests/oracle/three-rounds.z80) on the fourth. Until then it ran once and the first missed by a byte. 10 programs agree with `z80asm` byte for byte, six through the listing, because `z80asm` has no `br` |
| [`c/`](../languages/c/) | 2,196 lines, 46 node types | a C subset, every construct of step one of [ROADMAP 6](ROADMAP.md#6-a-c-compiler), which is [complete](#61-step-one--a-subset-that-runs-and-cc-as-its-oracle): `int main(){return 42;}`, then `+ - * /` with parentheses, then unary minus and the six comparisons, then a local `int` with a symbol pass that gives it a frame slot, then `if`, `while`, `for` and blocks with the scoping C11 6.2.1 asks for, then functions with up to eight parameters, prototypes and calls under AAPCS64, then `&` and `*` with the pointer declarators, where the left of an `=` becomes a **place**: a rule with two alternatives, so that C11 6.5.3.2's lvalue is the grammar's job rather than a pass's. A `types` pass counts stars, which does two jobs: it refuses what would otherwise mis-compile, and it says which half of the register a value lives in, an `int` being 32 bits in a `w` and a pointer 64 in an `x`, as this machine's C has them. Then `sizeof`, in both its shapes, which does not evaluate its operand, and an array of `int` or of pointers, which decays to a pointer to its first element everywhere but under `sizeof`, and which moved the frame from numbered slots to byte offsets. Then indexing, which builds no node: `a[i]` is C11 6.5.2.1's `*((a)+(i))` written as the grammar action, and pointer `+` and `-` count in elements, with one multiply-add that sign-extends the index. The difference of two pointers is an `int`, as it was in K&R's first edition, because C11's `ptrdiff_t` is a typedef. Then `char`, signed as Apple's arm64 has it, which made a type two numbers: the stars, and the width of what is under them. Then character constants, printable ASCII and six escapes, each worth an `int`. Then string literals, arrays of `char` in `__TEXT,__cstring`, their length counted in the description and their bytes written by the assembler, so programs print through a declared `puts` and the oracle compares what they print. Then `struct`, with `.` and `->`, defined at file scope with a tag: members are laid out by a thread with C's alignment and padding, a declaration's base became a node that looks its width up in a table of layouts holding `int` and `char` as two structs with no members, and `->` is built as `(*p).x` as a subscript is built as a `*` of a `+`. A struct is copied whole since 2026-09-23, by `=`, by an initialiser and as an argument under AAPCS64, which `tests/abi/` holds against `cc`'s own code by linking each compiler's caller to the other's callee; a copy between two kinds of struct is refused, and so is a struct wherever C wants a number. A struct is returned whole the same day, in `x0` and `x1` or through the caller's `x8`, and `tests/abi/` holds that against `cc` in both directions too. **Nothing in `phoenix/` changed through all of it**, which was the arc's first prediction. **Then `typedef`, which is where it did**: a typedef names a base and some stars, at file scope, and an ordinary name declared in a block or as a parameter hides it until that scope ends, which the parse is told by `%names` ([1.8](#18-names-the-parse-keeps)) and not by a pass, because `x * y;` has to be built as one thing or the other before any pass runs. The arc's second prediction. **Then signed `long`**, eight bytes, with the usual arithmetic conversions sign-extending an `int` wherever it meets one, and `sizeof` and a pointer difference `long`s as C has them. **Then a function that returns a pointer** ([6.2](#62-a-function-that-returns-a-pointer)), which is what let `malloc` be declared and gave a `long` index its witness. **Then `%`**, the first of [6.3](#63-the-operators)'s operators, as a division and a multiply-subtract, **and `!`, `&&` and `||`**, the second, whose right side runs only when the left has not decided, **and `++`, `--` and the compound assignments**, the third, one node that reads a place once and writes it back, **and the bitwise operators, the shifts, `?:` and the comma**, the fourth, which leaves every expression operator C has except the cast. **Then `break`, `continue`, `do` and the empty statement**, the first of [6.4](ROADMAP.md#64-the-statements)'s statements. Compiled to arm64 assembly that `cc` assembles and links by a stack machine with no register allocator. **The one language on the roadmap as a goal rather than a mechanism.** 228 programs exit with what `cc` makes them exit with, 111 are refused with a position, none diverges, and nothing in the directory has a hand-written expected result |
| [`phx/`](../languages/phx/) | 274 lines | the notation described in itself. It parses itself and every other description here |

**Nine directories, eight rows.** [`languages/units/`](../languages/units/) —
229 lines, 11 node types, and two checks in the suite — is deliberately not
here. It was written to answer a question rather than to be compiled: *do
Pascal units need a scope graph?* The answer is under
[2.3](#23-scope-graphs--from-statix), which is where it is described, and this
table is what the tool is *for* rather than everything it has read.

## The notation

Everything below is built, and each line names the entry that argued for it.

| | |
| --- | --- |
| `%tokens` `%syntax` | the two halves, declared and never guessed — [3.3](ROADMAP.md#33-guessing-the-lexicalsyntactic-seam) |
| `%fragment` `%skip` `%require` `%start` `%ignorecase` | the lexical vocabulary |
| `%import` | a description assembled from modules, each read once |
| `%embed` | a file's bytes under a name, frozen at read time — [1.5](#15-a-runtime-that-is-not-a-literal) |
| `%include` | a *target* language's own includes, spliced by the reader — [1.0](#10-a-reader-level-mechanism-for-a-target-languages-imports) |
| `%names` | names the parse keeps while it matches, declared and hidden by the nodes it builds, and asked by one rule: [1.8](#18-names-the-parse-keeps) |
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

### 1.8 Names the parse keeps

`%names typedef-names declare Typedef.name hide Local.name scope block guard
typedef-name .`: a table of names kept **while** matching, bound by the nodes
the actions build, ended by the rules that are scopes, and asked by one rule
that matches a name only when the table says it was declared.

**The failure, written down first.** C's `x * y;` declares `y` when `x` names
a type and multiplies when it does not, so the grammar has to know, and
before this it could not be told. The one thing a description could do was
let a declaration's base be any name and leave the rest to ordered choice.
That was tried on a copy of `c.phx` against all 143 programs then in
`tests/oracle/`, and one moved: `sizeof(x)` in `sizeof-parens.c`, `x` a
variable, was read as the type named `x` and refused with *'struct x' is not
defined*. `x * y;` became a declaration of `y`. Both are refusals rather than
wrong answers, which is the best the description could do and is the
**tool's** limit, since no pass runs before the tree has taken one shape or
the other.

*Predicted since 2026-09-06, as the arc's second prediction: that this is the
first change the tool needs, and at `typedef` and not before.* Held, and
[postmortem 20](postmortem.md#20-prediction-two-held-and-the-predicate-was-a-table)
scores it. What was predicted as a **predicate** on the identifier rule
arrived as a **table** with one guarded rule asking it. The predicate is the
small half; the part the prediction did not name is that the table needs
writing to, from the declarations, and undoing, on every backtrack. Rats!
calls this stateful parsing ([lineage](lineage.md)).

**Written down rather than programmed.** Which nodes declare a name is a fact
the actions already state, so the directive names node types and fields and
adds nothing inside a production. The checks find, in each action that builds
such a node, the factor the field is filled from, and the matcher binds that
factor's text **the moment it is matched**: C11 6.2.1p7 starts a name's scope
at the end of its declarator, so in `int T = sizeof(T);` the second `T` is
the variable. The first version bound when the node was finished, after the
initialiser, and compiled that program to 1 where `cc` says 4. The table is
one stack shared by every `%names`, and a failed match truncates it to where
it stood when that match began, so a backtracking choice leaves it as it
found it. Five refusals: a node nothing builds, a field it has not got, a
field an action computes rather than takes from a factor, a scope or guard
that is not a rule, and a guard over more than one token.

Four breakages of the matcher, each asserted applied, each red on
`tests/grammars/names.phx`: no undo, no scope, no guard, and binding when
the node is built. The table is on
the generated compiler's rules too, and `-o` is held to `phx` on the same
file.

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

### 2.5 Circular attributes — from JastAdd

*Built 2026-09-23*, as a driver stage rather than an attribute:

    %driver code = layout, relax until labels, reach, code -> out .

A stage marked `until` is run again and again until the attribute of the root
it names comes out of a round equal to what went in. The pass is one walk, as
every pass is; the tool owns the loop, the test, which is the structural `=`
a clause already has, and a bound of 256 rounds with a message naming the
stage and the attribute that were still moving. JastAdd puts the fixpoint on
the attribute. Here it went in the **driver**, because a driver is already
the claim about what runs in what order, and running one thing until it
settles is a claim of that kind; and because a pass that iterated would be
an interpreter that loops, which [3.1](ROADMAP.md#31-an-interpreter-that-can-loop)
refuses, where this repeats a whole walk with a termination test the tool
owns.

*The customer was `languages/z80/`'s `br`*, which picks a two-byte relative
jump when the target is in reach and a three-byte absolute one when it is
not. `relax` had been written out once by hand since 2026-09-05, and that
workaround settled everything but the word: the step is the pass as written,
the bottom is `layout`'s table with every forward `br` long, the direction is
shrink only, which is why it terminates. The pass hands down the table it is
about to replace, `layout`'s on the first round and its own after, and
defines `labels` under the same name so that the round can be compared.

**Two checks had to learn the shape**, and each waives exactly the attribute
the driver names: a `down` clause reading what its own rule computes is
reading last round's answer, and two passes defining one attribute is the
start and the step. Four things are refused when the description is read: a
rewrite given `until`, a stage that does not define the attribute, an
attribute nothing before the stage defines for the first round, and, when
it runs, a stage that has not settled by the bound. A compiler written out
with `-o` runs the loop, because it lives in the runtime.

`two-rounds.z80`, pinned at 130 bytes in `divergent/` since 2026-09-05, is
129 and an oracle program. `three-rounds.z80` is three nested `br`s that need
a fourth walk, 134 bytes after one and 131 after four, worked round by round
in its comment and simulated before it was run. `languages/units/`'s two
divergences, a three-unit cycle and initialisation order, are the other
customer the entry named and are **not** converted: `fpc` already refuses
the first, and nobody has asked for either.

### 6.1 Step one — a subset that runs, and `cc` as its oracle

`languages/c/`, in the shape [`languages/README.md`](../languages/README.md)
prescribes: `c.phx` holds the grammar, the tree and the symbols and has no
opinion about a target; `c-arm64.phx` imports it and adds one emit pass. The
target is **arm64 assembly text**, assembled and linked by `cc`, because that
is the machine under this repository and because borrowing the assembler and
linker is what every C compiler except tcc does.

**The emit pass is a stack machine.** Every expression leaves its value in
`x0`, every operand is pushed and popped, every local lives in the frame at an
offset the symbol pass assigned, and there is no register allocator. That is
chibicc's and tcc's shape, it is what `examples/asm.mx` in Metaxis sketched for
a smaller subset, and it is the route the workspace document names first. The
output is slow and correct, and slow is not a divergence.

**The subset grows in chibicc's order**, one construct at a time with the
suite green at each: `int main(){return 42;}`; then `+ - * /` and
parentheses; unary minus and comparison; a local `int`; `;`-separated
statements and `return`; `if`, `while`, `for`; blocks; a function with
parameters and a call under the arm64 calling convention *(prediction three
is scored in [postmortem 16](postmortem.md#16-the-calling-convention-cost-the-most-and-not-for-the-reason-given))*;
`&` and `*`; arrays and
`sizeof` *(done 2026-09-22, indexing and the difference of two pointers
last; ninety-nine programs against `cc`, twenty-five refused and two
divergences pinned)*; **`char` and string
literals** *(done 2026-09-22; 123 programs against `cc`, and the oracle
compares what they print as well as how they exit)*; **`struct`** *(done
2026-09-22, which completes the list; 143 programs against `cc`, 49
refused)*. It stopped before `typedef`
on purpose, because that was where the tool was expected to need a change,
and the change was to arrive with the construct that wanted it and not
before. *It did, on 2026-09-23*: see step two below.

**The width, decided 2026-09-22: `sizeof(int)` is 4, and `int` narrows to
thirty-two bits.** Until that day the value was sixty-four bits wide in a
register C calls a 32-bit `int`, left open on 2026-09-21 with the note that
the oracle would settle it at `char`. It was settled two constructs earlier
and by a program that had been available since the second construct:
`int a = 2000000000; int b = a + a; return b / 1000000;` exits 218 under `cc`,
which wraps at thirty-two bits, and 160 here, which does not. A 64-bit `int`
would have been a **conforming** implementation, the standard asking only for
sixteen bits, so this was a choice and not a defect; what it would have cost
is `cc` as the oracle for everything size-shaped, which is `sizeof`, `struct`
offsets and array layout, or in other words the rest of the arc.
[postmortem 17](postmortem.md#17-left-to-the-oracle-is-not-a-decision-until-somebody-writes-the-program)
scores the expectation and the journal has the reasoning.

*Built the same day.* The emit pass picks `w` or `x` from the star count the
`types` pass already had, which came to nine clauses and a table with one row
in it. On this machine `w0` is the low half of `x0` and every write to a `w`
register zeroes the upper half, so the stack machine, the calling convention
and the frame were all unchanged; a scalar keeps its eight-byte slot and is
stored into it with `str w0`. `tests/oracle/overflow.c` went from 160 to 218,
and two programs were added that a **half-finished** narrowing fails, which
was checked by half-finishing it on purpose.

*`sizeof` came next, the same day, and wanted nothing.* A star count already
says how many bytes a value takes while `int` is the only base type, so the
two `sizeof` shapes read that table for its other column and the `types` pass
did not grow. What `sizeof` did want was a decision: C11 6.5.3.4 makes it
worth a `size_t`, `size_t` is a **typedef**, and this arc stops before
`typedef` on purpose, so it is worth an `int` here and
`tests/divergent/sizeof-of-sizeof.c` pins the one program that shows the
difference, 8 against 4.

*An array's declaration, size and decay went in the same day, and the frame
moved with them.* `int a[10]` is forty bytes and no slot holds forty, so a
local now lives at a **byte offset** rather than in a numbered slot, which is
the first time a declaration's type reached the frame. A name that is an array
decays to a pointer to its first element, C11 6.3.2.1, everywhere except under
`sizeof`, which is why a node answers a `type` that decays and a `size` that
does not.

*Indexing closed the item, the same day.* A subscript is C11 6.5.2.1's
`*((E1)+(E2))` built by the grammar action and no node of its own, and
`sxtw` arrived where predicted, inside one `add` that sign-extends the index,
scales it by the element and adds it to the pointer.

*The difference of two pointers, decided the same day: an `int`.* C11 6.5.6
makes it a `ptrdiff_t`, which is a typedef, so it was the `sizeof` question
again and got the `sizeof` answer. It is also what K&R's first edition said
the difference was, before ANSI C gave it a name.
`tests/divergent/sizeof-a-pointer-difference.c` pins the one program that
shows it, 8 against 4. **Both are to be revisited when `typedef` arrives**,
together: `size_t` and `ptrdiff_t` are the two typedefs this subset already
owes an answer to.

*`struct` closed the list, the same day.* Tagged, at file scope, with `.`
and `->`, arrays of structs, structs in structs, and a pointer from a struct
to its own kind, which is what a list is made of. Members are laid out by a
thread in the `locals` pass, each at the next offset its alignment allows,
and the struct rounded to its widest member, so `cc`'s `sizeof` is this
subset's. A declaration's base became the node the standup expected a type to
become: `int`, `char` and a tag are all looked up in one table of layouts. A
type stayed numbers, three of them now, the tag being the third.

What is **not** here, and each is a refusal or a syntax error rather than a
wrong answer: a struct defined in a function, or with no tag; and a pointer
to a struct nobody defines.

*A struct copied whole, done 2026-09-23*, by `=`, by an initialiser and as
an argument. A copy is a byte loop in the emitted code rather than a store
or a call to `memcpy`, and nothing in `phoenix/` changed for it. An argument
follows AAPCS64: up to sixteen bytes in one register or two, and anything
larger copied by the caller and passed by address. That is held against
`cc`'s own code by `tests/abi/`, where a caller and a callee in two files
are compiled by each compiler in turn, because the oracle can only ever see
Phoenix agree with itself. A copy between two kinds of struct is refused,
and so is a struct anywhere C wants a number: nine such programs, all of
which `cc` refuses, **compiled** until that day into the struct's address,
in a pass whose header says it refuses whatever it would otherwise
mis-compile. 175 programs against `cc`, 73 refused.

*A struct returned, done the same day*, and AAPCS64 again: up to sixteen
bytes packed into `x0` and `x1`, and anything larger written by the callee
where the caller's `x8` points, the caller giving it a place in its frame
either way so that a call is worth the struct's address, as any struct is.
A function that returns a large struct keeps `x8` from its prologue, since
a call in its body may use `x8` for one of its own; that has one witness in
the oracle and one in `tests/abi/`, which now links returns in both
directions as well as arguments. A function's return type became a `base`,
so a `char` or a pointer returned is refused by name, since nothing here
narrows or widens what comes back, and so is `main` returning a struct. A
member of a call is a value, as a member of an assignment is. 185 programs
against `cc`, 82 refused.

**The oracle is `cc` itself**, the way `fpc` is Pascal's and `/usr/bin/awk` is
awk's. `tests/oracle/` holds programs compiled twice — once through `cc` and
once through Phoenix's output through `cc` — and their standard output and
exit status compared. Nothing in this arc has a hand-written expected result.
`tests/refused/` holds what must not compile, with the message, once the
subset has anything to refuse. There is no vendored grammar and no need of one:
the subset is described directly, and the C11 grammar in Annex A is what to
check the description's *shape* against when it is large enough to matter.

**What it borrows, written down so the borrowing is visible**: `cc -E` for
anything with a `#` in it, which the first dozen constructs do not need; `cc`
to assemble and link, and the assembler to turn a string literal's escapes
into bytes, which the notation cannot do; the system libc, reached through a
`puts` or a `putchar` declared in the program rather than included, until the
preprocessor exists. *Not `printf`, since 2026-09-22*: it is variadic, and
Apple's arm64 passes variadic arguments on the stack rather than in
registers, which is a calling convention this subset does not have.

*The predictions, for [postmortem.md](postmortem.md) to score.* One: the
subset reaches `struct` with **no change to the tool** — `%import`, the symbol
pass, `thread` for frame offsets and one emit pass are enough. Two: the first
change the tool needs is the typedef predicate, and it is wanted at `typedef`
and not before. Three: the arm64 calling convention costs more than any
construct before it, because it is the first place the emit pass has to know
something the tree does not say. Each of these can be wrong in a way the
journal would record.

*The condition for the next step* is the first: a subset through `struct`
whose oracle tests pass. **Met on 2026-09-22**, and with prediction one
holding: [postmortem 19](postmortem.md#19-prediction-one-held-and-the-node-went-somewhere-else)
scores it. Steps two to seven live in the workspace document and
are not repeated here; the one that comes back to this page is the predicate,
which will be an entry under section 1 with the failure written down first, as
this page requires.

**Step two, `typedef`, done 2026-09-23**, and with it the predicate:
[1.8](COMPLETED.md#18-names-the-parse-keeps), whose failure was measured on a
copy of `c.phx` before the tool was touched. Prediction two held, and
[postmortem 20](postmortem.md#20-prediction-two-held-and-the-predicate-was-a-table)
scores it. A typedef names a base and some stars, a struct's included, at
file scope, and an ordinary name declared in a block or as a parameter hides
it until that scope ends. 156 programs against `cc`, 58 refused.

*`size_t` and `ptrdiff_t`, revisited as promised, stay `int`s.* `typedef`
gives C a way to name them and gives this subset nothing to name them as:
both are `long`s on this machine, and `long` is step four of the workspace
document. The two divergent programs stay pinned.

What is **not** here, each a refusal or a syntax error: a typedef in a block,
as a struct is at file scope only; a typedef of an array, whose count belongs
to a declaration here and not to a type; and a local named in its own initialiser,
`int x = sizeof(x);`, because the `locals` pass binds a name at the end of its
declaration and C at the end of its declarator. That last one was always so,
and `typedef` gave it a second spelling. A typedef as a function's return
type was a fourth until the same day, when a struct could be returned and a
function's return type became a base.

*It stayed open for one afternoon, and then `long` closed it.* Every
construct step one listed was built by 2026-09-23, with `typedef`, a struct
copied and a struct returned, and what kept the entry on the roadmap was the
two divergences pinned in `tests/divergent/`: `sizeof` and the difference of
two pointers were `int`s here and `long`s under `cc`. **`long` arrived the
same day**, signed and eight bytes, with C11 6.3.1.8's usual arithmetic
conversions: an `int` meeting a `long` is sign-extended into the whole
register first, at an operand, a comparison, a store, an argument and a
`return`, and a `long` put into an `int` keeps its low half. A decimal
constant too big for an `int` is a `long`, and `1L` is a syntax error.
`sizeof` and a pointer difference are `long`s, and both pinned programs
agree with `cc` and moved into the oracle, which is the condition this
entry set for itself. `tests/abi/` holds `long` arguments and returns
against `cc` in both directions. 196 programs against `cc`, 85 refused, and
no divergence left.

### 6.2 A function that returns a pointer

*Opened and closed 2026-09-25.* A function here returned an `int`, a `long`
or a struct, and the first function any C program meets, `malloc`, returns
a pointer. **The entry named three places that refused one, and each was
real**: the grammar had no stars between a function's base and its name, so
`int *f()` was a syntax error and only a typedef of a pointer reached the
second place, the `locals` pass, which refused it by name; and the `types`
pass typed every call from a table of tag and width, with no stars, so a
call was an `int` whatever it returned.

So a function's stars are written in the grammar, summed with its typedef's
as a declaration's are into `rptrs`, and carried in the table of what each
function returns, which now holds the three numbers an expression's type is.
A call reads its type off that table. `char` is still refused by name,
because nothing narrows `x0` on the way out.

*The emit pass was predicted to need nothing, and needed three guards, all
for the same reason*: **a pointer to a struct has a tag and is not a
struct**. Three questions asked "does it have a tag?" to mean "is it a
struct?": whether a `return` must be a struct, whether a call's result is
copied into the caller's frame, and whether a function's `return` copies
bytes out. Each now asks for no stars as well, and
`struct-pointer-returned.c` fails if any one of the three is put back: a
refusal, a wrong exit status and a crash. For a plain pointer the emit pass
needed nothing, as predicted, because a pointer is not `wide` and the
`return` template already leaves all of `x0` alone.

**The witness the entry existed for works.** The comment at `madd` in
`c-arm64.phx` had said since 2026-09-23 that a `long` index had no program
to tell it from `smaddl`, because only an object over 2 GB could, and the
only way to get one was a `malloc` this subset could not declare.
`long-index-past-two-gigabytes.c` now `malloc`s three billion bytes and
indexes near the end; with `smaddl` put in place of `madd` it is the one
program in the oracle that disagrees. Six programs came in, one of them the
refused typedef program moved across and made to use what it returns: 202
against `cc`, 84 refused, no divergence. `void`, and so `void *`, is not in
this step; a `char *` prototype is C that `cc` compiles.

### 6.3 The operators

*Opened and closed 2026-09-25, in four parts.* The subset had `+ - * /`,
unary `-`, the comparisons, `=`, `&`, `*`, `sizeof`, `[]`, `.` and `->`, and
every oracle program was written around the rest: `n - (n / 10) * 10` for
`%`, an `if` inside an `if` for `&&`, `i = i + 1` in every loop. It now has
every expression operator C has **except the cast**, which went to the types
it converts between. It came before the statements because they lean on it.

**Part 1, `%`**, is `sdiv` and then `msub`, C11 6.5.5p6's identity written
as two instructions, so a remainder has its dividend's sign. The `types`
pass needed nothing: its general `Binary` clause already refused a pointer
or a struct on any operator but `+` and `-`.

**Part 2, `!`, `&&` and `||`.** `&&` and `||` are one template that differs
in one letter, `cbz` against `cbnz`, and whose right side runs only when the
left has not decided. **Writing the witnesses found that `&&` already
lexed**, as two `&` tokens, so a binary `&` built first would have parsed
`a && b` as `a & (&b)`; that is why the part came before the bitwise one.
And checking the register it tests found a defect older than it: an `int`
returned by a function `cc` compiled can have its upper half set, which is
the row in *Defects found* below, fixed the same day.

**Part 3, `++`, `--` and the compound assignments**, is one node, `Update`,
since C11 6.5.3.1 defines `++a` as `a += 1`. It works out the place's address
once, so `x[k++] += 10` moves `k` once, and does its arithmetic at the wider
of the two sides. **Postfix `++` became a suffix** in the fold with `[ ]`,
`.` and `->`, because `q++->c` is C and a `++` outside the fold ended the
chain. Two of seven deliberate breaks passed at first, and both times the
witness was at fault, agreeing in the bits it looked at: every `long`
divisor left the low half alone, and the only `char` update whose value was
used went out through an exit status of eight bits.

**Part 4, the bitwise three, the shifts, `~`, unary `+`, `?:` and the
comma**, with `&=`, `|=`, `^=`, `<<=` and `>>=`, which the entry had not
listed and `Update` took with a line each. A shift is the type of its *left*
side, C11 6.5.7, so `1 << (long)3` is an `int`; `>>` is `asr`, as `cc` has
it. The comma became the top of `expression`, and an argument and an
initialiser moved down to `assignment`, as the entry said they must; putting
`arg` back is 24 programs that no longer compile. `?:` takes two numbers, two
pointers to one type, or one struct twice. **Two things `cc` takes are
declined by name**: a pointer beside `0`, which needs a null pointer constant
this pass cannot tell from any other `int`, and pointers to two types, which
`cc` only warns about.

Seven node types came in with it: `Logical`, `Not` and `Update`, and in the
last part `Comma`, `Choose`, `Invert` and `Plus`. Twenty-one programs joined
the oracle, 223 in all, and 24 refusals, 108; nothing diverges. Every part
had its templates broken on purpose, twenty-six ways in all, and each break
that was not the same instruction under another spelling failed a witness.

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
the benchmark row of *Defects found* below.

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

Every one of these but the last was found by a test comparing Phoenix
against something outside it, and the last was confirmed by one. Only the last
was found by reading the code. Several rows before it widen what *outside it*
has meant, and the entries after the table say how.

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
| **a syntax error named a token that was legal** | `parse_run` reported a leftover-input failure at the first token left over while keeping the *expected* list recorded wherever the match had really got stuck. `print a +;` blamed the `print`. A start rule that is a repetition never fails outright, so **every** syntax error in every language here took that path. Found by [reference.md](reference.md) disagreeing with the program |
| **a `thread` declared below its updates was not a thread** | clauses are classified as they are read, so a rule above the declaration got an ordinary synthesised attribute and one below it got the thread — two attributes of one name, and the thread reached every node with the value it started at. **No diagnostic.** Found by [`languages/z80/`](../languages/z80/)'s *second backend*: the listing printed `jp` for a backward jump that `jr` reaches |
| **a bare `$name` nothing could answer was read without a word** | `$x.attr` was checked when a description was read and a bare `$name` only as the pass ran, node by node, so it was reported once per node that reached it, or never if no program in hand did. Found **twice in two days by the C description while its passes were being written**: a `types` check naming a `locals` thread, printed six times over a struct of six members, and a `$sig` nothing defined, which read cleanly. Refused at read time since 2026-09-23, generously: only a name no binding, field, pass or embed could ever answer |
| **the suite could not say that a program did not finish** | `tests/run.sh` and every harness ran what they had just compiled with no limit, so a program that looped hung `make test`, and one that looped around a print ran the capturing shell out of memory and ended the run with no report. Found by a breakage harness that ran for two hours and forty minutes on 2026-09-23, until Hans asked why the background jobs were still going. Fixed 2026-09-24 by [`tests/limit.c`](../tests/limit.c), a time and output limit every harness runs its programs under, and a log of every stop that fails the run |
| **an `int` a call returned was trusted to be zero-extended** | the C emit pass tests all of `x0` in every condition, on the header's promise that an `int` sits there zero-extended, and AAPCS64 leaves the upper half of a returned `int` unspecified. A callee `cc` compiled, `int lnarrow(long x) { return x; }`, hands back the whole `long` even at `-O0`, so `if (lnarrow(4294967296))` was taken. `tests/abi/` linked Phoenix to `cc` from the start and never tested more than the low half of what came back |

**The rule this repeats**: a round trip can be green while the parse is
consistently wrong, because what is written back out is wrong in the same way.
[journal.md](journal.md) records that three times, in two languages.

The benchmark row is the same rule about the *instrument* rather than the
subject: a harness that cannot report failure reports something else, and a
number nobody can reproduce is where that hides.

**The syntax-error row is a fourth kind of finder, which is why the claim
above it is hedged.** Nothing outside this project was consulted and no test failed. The
thing Phoenix was compared against was **its own reference manual**, which said
the position reported is the one the match got furthest — and a two-line
experiment said otherwise. The code was then read to find out which was right,
but reading is not what found it.

That only works on a document precise enough to be contradicted.
[reference.md](reference.md) earns its place here by saying something a
five-minute test can disagree with, which is the same property
[semantics.md](semantics.md) has and the reason that page became a suite.

> A specification nothing runs is a document about a program. A specification
> precise enough to be *wrong* is a test nobody has written yet.

**And the `thread` row is a fifth kind, which is the cheapest of them.** The z80
description has two backends — bytes and a listing — and both were built
because `z80asm` cannot be handed a `br`. Neither is a test. What found the
defect is that one of them **says out loud what the other encodes**: `jp top`
where `jr top` was expected, in a program short enough to read. The bytes were
a correct jump and would have stayed correct forever, three bytes at a time.

That is the argument `calc/` already makes for keeping a second backend, met in
a place it was not being made for. A second view of one tree is not redundancy;
it is the cheapest instrument in this repository.

**The bare-name row is a sixth: the tool's own user.** No test and no second
view found it. A description being written did, twice, because writing a
pass is when a mistaken name is made and the only time anybody is reading
the one clause it is in. The tool had the answer all along, since it
already knew every attribute each pass defines for the `.attr` check. What
it lacked was the question, and the roadmap entry that asked it is the
[ROADMAP](ROADMAP.md) § 5 paragraph this row replaces.

**The suite row is the benchmark row a second time, and a seventh kind of
finder: a person asking why something was still running.** No check could
have found it, because what was missing was the check's ability to finish.
The fix had two faults of its own on its first day, and neither was found
by a test either. A reaping order that let a finished program sit until its
deadline, so that checks passed late at random, was found by timestamping
every line of an old run and a new one. And a 16 MB cap that cut both sides
of a 49 MB `solvm --trace` comparison to a match was found by the log of
stops, the day it was added. An instrument is checked by measuring the
instrument, which is [postmortem.md](postmortem.md) § 18 again.

**The call-return row is an eighth kind of finder, and the first on this
page that is reading**: a promise in a comment, *`x0` always holds the
zero-extended `w0`*, read against the rule it depends on, while building the
two operators that relied on it most. It was true of everything the file
emits and false of the one thing it does not, a value another compiler
made. The reading was the hypothesis and not the finding: a four-line pair
of files, one compiled by each, is what showed it, and that pair is now in
`tests/abi/`. The harness had the right shape for this fault from the day
it was written, 2026-09-23, and asked it nothing.

**A test was holding the defect in place**, and that is worth its own line
because it looked like the opposite. `languages/awk/tests/divergent/spaced-regex.awk`
asserted the message contained `and found "BEGIN"` — a file's first token
blamed for a fault 34 columns into line 13 — from a directory named for genuine
divergences, next to two of them. An expectation pasted from a run records the
behaviour; only one written from the intent records the intent.

## The specification, made to run

[semantics.md](semantics.md) says what the meta-language's arithmetic,
comparison, text and formatting *are*. Nothing checked that until
[`tests/grammars/semantics.phx`](../tests/grammars/semantics.phx): every claim
as a check, every refusal as a clause, run through `phx` **and** through a
compiler `phx` wrote — which has to complain in the same words.

> A specification nothing runs is a document about a program, and it drifts
> from it one sentence at a time.

## The arithmetic, made to run too

The section above is about prose. These documents also make claims that are
**numbers** — how many lines a description is, how many node types it has, how
big the tool is, how many checks the suite runs — and those rot differently.
A sentence goes wrong when somebody writes it. A number goes wrong when
somebody changes something *else*.

A sweep on 2026-09-05 found **nine stale**. Four had drifted over three days as
awk, `solvm` and Solveig each grew after their counts were filed;
[`ee5c993`](CHANGELOG.md) — `|` as an expression operator — is what turned
awk's fiftieth node type into its fifty-first. Two were **two hours old**,
written that morning and false by lunchtime, by somebody who had just measured
them. That last pair is the argument: care is what wrote them, so more care is
not the fix.

[`tests/counts.sh`](../tests/counts.sh) holds every count in
[COMPLETED.md](COMPLETED.md) and [postmortem.md](postmortem.md) against `wc
-l`, `--nodes` and the tree. It would have caught all nine.

**And the one count it refuses.** A test that asserts how many tests there are
changes the answer. The suite's own total is checked in
[`tests/run.sh`](../tests/run.sh) *after* the summary line, where the number is
final and nothing is still counting — so it can fail the run without being in
it. It is judged only on a full run: a machine without `fpc` or Solveig is
right to report a smaller number, and failing there would make the check a
claim about the machine rather than about the records.

That needed the suite to know what it had **not** run, which it did not. Skips
are counted now, and a guard says how many checks are behind it rather than how
many lines it prints — so an incomplete run says `193 passed, 0 failed, 4
skipped` instead of quietly saying 193.

> A number in a document is a promise to keep it right. The only promises worth
> making are the ones something checks.

