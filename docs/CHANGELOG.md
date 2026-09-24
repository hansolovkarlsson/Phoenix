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

## 2026-09-24: a test that never finishes fails instead of hanging

**`make test` can no longer hang.** Every program the suite runs, `phx`
itself and everything `phx` or `cc` has just made, runs under a limit of
20 seconds, and each of the harnesses the suite calls under one of 600. A
program that loops forever is stopped and its check fails with `did not
finish` in the reason. So is one that **prints** forever, which is the
likelier regression and which time alone did not catch: it wrote so much
that the shell capturing it ran out of memory and took the suite down with
it. A program is stopped after 16 MB of output as well. The limit is
[`tests/limit.c`](../tests/limit.c), built by `make` as `bin/limit`,
because macOS has no `timeout`. `PHX_LIMIT` and `PHX_HARNESS_LIMIT` change
the two numbers. The suite takes as long as it did.

**Tests:** 317 → 320. Three for the limit itself, which everything else now
runs through: a program that finishes keeps its exit status, one that never
finishes is stopped and says so, and so is one that never stops printing.

---

## 2026-09-23: `typedef`, a struct copied and returned whole, and the first thing a parse remembers

**The notation changed.** `%names` is a new directive: a table of names the
parse keeps while it matches, and one rule that may ask it.

```
%names typedef-names
    declare Typedef.name
    hide    Param.name Local.name LocalInit.name LocalArray.name
    scope   block function
    guard   typedef-name .

typedef-name = name .
```

A node the grammar builds **declares** a name or **hides** one, at the moment
the name is read; a **scope** rule ends what was bound inside it; and a
**guard** rule matches a name only when the table says it is declared. A
failed alternative takes back what it bound, so ordered choice behaves as it
did before. It is written into compilers made with `-o` as well. Five
mistakes in a `%names` are refused when the description is read, with the
line.

**The C subset has `typedef`**, which is what the directive is for. `typedef
int number;`, `typedef int *intp;`, a typedef of a typedef, and `typedef
struct node *list;` all compile, and a typedef can be a parameter's type, a
member's and a `sizeof`'s. `x * y;` is a declaration when `x` is a typedef
and a multiplication when it is not, and a variable declared with a
typedef's name hides it until its block or function ends, as C says. A
typedef declared twice for two different types is refused. Not yet: a
typedef inside a function and a typedef of an array. `sizeof` and the difference of two pointers are
still `int`s, because what C makes them is a `long`, which the subset does
not have. Thirteen more oracle programs, 156 in all, and 58 refusals.

**A struct is copied whole**: `a = b`, `struct t u = s;`, and a struct
passed to a function, all of which were refused. Passing follows the
machine's calling convention, so a struct goes between code Phoenix compiled
and code `cc` compiled, in either direction, and a new test links the two to
make sure. A struct of one kind copied into another is refused, as `cc`
refuses it. So is a struct used where C wants a number: in arithmetic, a
comparison, a condition, a `return` from a function that returns an `int`,
or put into an `int` or a pointer.
**Those compiled before today**, into the struct's address used as a
number, and `cc` refuses every one. Nothing in Phoenix itself changed for
any of this. Nineteen more oracle programs, 175 in all, and 73 refusals.

**A function can return a struct**: `struct point make(int x, int y)`, and
a typedef of a struct or of `int` as the return type. It follows the
machine's calling convention, so a struct comes back from `cc`'s code to
Phoenix's and the other way, and the same test that links the two for
arguments now does it for returns. A call that returns a struct can be
copied, passed on, or have a member read, `make(1, 2).y`, but not have one
assigned or its address taken, which `cc` refuses too. So is returning one
kind of struct from a function declared to return another, or declaring a
function twice with two return types. A function returning a `char` or a
pointer is refused by name, although `cc` compiles both, and so is a `main`
that returns a struct, which `cc` only warns about. Ten more oracle
programs, 185 in all, and 82 refusals.

**The C subset has `long`**: signed, eight bytes, as a variable, a
parameter, a member, a return type and behind a typedef. `int` and `long`
mix as C says, the `int` converted first, so -1 stays -1 when it is widened.
A decimal constant too big for an `int` is a `long`. `sizeof` and the
difference of two pointers are `long`s now, as they are under `cc`, so the
two programs that gave 4 where `cc` gives 8 agree, and nothing in the C
subset diverges. A `long` passes to and from `cc`'s code in either
direction. Not yet: `unsigned`, and a suffix such as `1L`. Nine more oracle
programs and the two former divergences, 196 in all, and 85 refusals.

**The notation changed again: a driver can run a pass until something
settles.**

```
%driver code = layout, relax until labels, reach, code -> out .
```

`relax until labels` runs `relax` again and again until the root's `labels`
is what the round before left, and then goes on. A stage that never settles
stops after 256 rounds with a message naming it. `until` is not a reserved
word. The Z80 assembler uses it: `br` now always picks the shortest
encoding, where it used to leave some programs a byte or two long, and
`two-rounds.z80`, which was pinned as a divergence at 130 bytes, is 129.
Compilers written out with `-o` do the same.

**`phx` refuses a name in a pass that nothing could answer**, when the
description is read. `$sig` with no binding, field, attribute or embed of
that name was accepted and then reported once for every node that reached
it, or not at all if no program did. So is a thread or an inherited
attribute read by a pass other than its own, which no later pass can see.
Every description in this repository reads as it did.

**Phoenix has a license**: MIT, in [`LICENSE`](../LICENSE). There was none
before.

**Tests:** 264 → 317. Eight for `%names`, on a small grammar made to have
C's problem and nothing else: what it parses, the same through a compiler
written out with `-o`, and five refusals and a warning about the directive
itself. Nine for `typedef`: four refusals of what C refuses too, three of
what this subset leaves out, and two of a local named in its own
initialiser, which were refused before today and are written down now.
Then sixteen for the copy: the calling convention against `cc`'s, and
eighteen new refusals, nine of them of programs that compiled into an
address, less the three refusals that became oracle programs. Then nine
refusals for a struct returned, six that `cc` makes too and three this
subset adds. Then three for a bare name: the two ways of getting one wrong,
and a grammar holding every kind that is right, so the check stays as
generous as the lookup it guards. Then seven for `until`: four refusals,
the program that needs a fourth walk and what one walk made of it, and a
compiler written out with `-o` running the loop. Then three refusals for
`long`, less the two checks that pinned the divergences it closed.

---

## 2026-09-22: `&` and `*`, and a left side that is a place

**The C subset's seventh construct**: the address of a thing, and the thing a
pointer points at. `int *p = &x; *p = 7;` compiles, and so do `int **q = &p`,
a pointer parameter a function writes through, and a `swap` written the way C
programs write one.

**What is on the left of an `=` is a place and no longer a name.** A place is
a rule with two alternatives, a name or a `*` on anything, and unary `&` goes
through the same rule. That is C11 6.5.3.2's *the operand shall be an lvalue*,
said once in the grammar. `&1` and `1 = 2` are refused by the parser with a
position, rather than by a pass asking what kind of node it was handed.

**A place is a second attribute rather than a second node.** A `Variable` and
a `Deref` each answer both the value and the address of the value, and the
parent asks for the one it meant, so `&*p` emits exactly what `p` emits and
C11's identity for it is never written down. The declarators `int *p` and
`int **q` are read and their stars counted; a name in the symbol table now
means a slot **and** a star count, as one pair in the one table that already
had a scope rule.

**A third pass, `types`, which exists to refuse what would otherwise
mis-compile.** Every value here is eight bytes, so a pointer taken for an
`int` is harmless, except that C11 6.5.6 counts `p + 1` in what `p` points
at, and nothing in this subset has a size yet. So pointer arithmetic is
refused by name until arrays and `sizeof` bring a size, `*` on an `int` is
refused as 6.5.3.2 requires, and `-` and `*` on a pointer with it. Whether an
assignment or an argument has the type it was given is **not** checked: the
one program that would show the eight-byte `int`, a pointer put in an `int`
and taken out again, is one `cc` refuses to compile.

**Sixteen more oracle programs and seven more refusals**, 58 and 18 in all.
Every one of the sixteen agreed with `cc` on the first run.

**Later the same day: `int` is thirty-two bits.** It had been sixty-four,
which is a conforming implementation and was left open on 09-21 for the oracle
to settle. The oracle had never been asked: `int a = 2000000000; int b = a + a;
return b / 1000000;` exits 218 under `cc` and had exited 160 here, in a program
the subset could compile since its second construct. `sizeof(int)` is 4 and a
pointer stays 64 bits wide. On arm64 this costs one letter per instruction,
`w` or `x` chosen from the star count the `types` pass already had, because
`w0` is the low half of `x0` and writing it zeroes the half above; the stack
machine, the calling convention and the frame are all untouched. Three more
oracle programs, 61 in all, two of them written to catch a half-finished
narrowing and checked by half-finishing one.

**Later again: `sizeof`.** Both shapes, `sizeof(int)` and `sizeof(int **)`
and `sizeof x` and `sizeof *p`, and the operand is **not evaluated**, which
C11 6.5.3.4 requires and which two oracle programs check by putting an
assignment and a side-effecting call inside one. It wanted nothing from the
passes: while `int` is the only base type a star count already is a size, so
this reads the table the register letter comes from for its other column.

**One number disagrees with `cc`, and is written down rather than refused.**
C makes `sizeof` worth a `size_t`, which is a typedef, and this subset stops
before `typedef`, so `sizeof` is worth an `int` and `sizeof(sizeof(int))` is
8 under `cc` and 4 here. `languages/c/tests/divergent/` holds the program and
the suite pins **both** answers, so closing the gap fails with the old numbers
in it.

**Later still: an array, and a frame measured in bytes.** `int a[10]` and
`int *a[10]`, `sizeof a`, and the decay C11 6.3.2.1 requires: a name that is
an array is a pointer to its first element everywhere except under `sizeof`,
so `*a` is element zero and `int *p = a;` is the same address. A local now
lives at a **byte offset** rather than in a numbered slot, because forty bytes
do not fit in a slot, which is the first time a declaration's type reaches the
frame. Everything is still given a multiple of eight, because the distance
between two separate objects is not something a C program can observe.
Assigning to an array is refused, as `cc` refuses it; a zero-length array is
refused where `cc` takes it as an extension, which is what keeps a count of
zero free to mean *not an array*; and indexing, `a[i]` and `a + 1`, is the
rest of the roadmap item and is refused by name until it arrives. Eight more
oracle programs, 79 in all.

**And last: indexing, which closes the item.** `a[i]`, `a + 1`, `p - 1`,
`2[a]`, `m[1][1] = 4` and `&a[2]`. A subscript is C11 6.5.2.1's
`*((E1)+(E2))`, built as exactly that by the grammar, so it needs no node of
its own and anything the passes already said about `*` and `+` holds for it.
Pointer `+` and `-` now count in elements, as C11 6.5.6 says, with one arm64
`add` that sign-extends a 32-bit index, scales it by the element's width and
adds it to the pointer. Adding two pointers and taking a pointer from a number
are refused, as `cc` refuses them. **The difference of two pointers is an
`int`**, the count of elements between them. C makes it a `ptrdiff_t`, which
is a typedef, so it takes the decision `sizeof` took and is pinned the same
way: `sizeof(&a[1] - a)` is 8 under `cc` and 4 here, and both answers are
asserted. Subtracting pointers to different types is refused, as C requires.
Twenty more oracle programs, 99 in all, 25 refusals and two divergences.

**Then `char`, as a type.** Locals, parameters, arrays and pointers of
`char`, `sizeof(char)`, and the conversions C11 6.3.1 asks for. A plain `char`
is **signed** on Apple's arm64, where Apple departs from AAPCS64, so it is
loaded with `ldrsb`; a store keeps the low byte, so `char c = 300;` holds 44;
and an assignment to a `char` is worth what the `char` holds afterwards.
Anything that is not a place or a pointer is promoted to `int`, so
`sizeof(c + 1)` is 4. A type is now two numbers, the stars and the width of
what is under them, and two pointers are the same type only when both agree.
Eleven more oracle programs, 110 in all, and 26 refusals.

**Then character constants.** `'a'`, and six escapes, `\n \t \\ \' \" \0`.
Each is an `int`, as C11 6.4.4.4 says, so `sizeof 'a'` is 4. Printable ASCII
only: a hex or octal escape, two characters between the quotes and a tab typed
between them are C, and are refused by the lexer as outside the subset. One
oracle program checks all ninety-five printable characters. Five more oracle
programs, 115 in all, and 29 refusals.

**And string literals, which close the item.** `"hello, world"` is an array
of `char` in static storage, one longer than its characters, decaying to a
`char *`: `sizeof "abc"` is 4 and `"abc"[1]` is `'b'`. **Programs can print
now**, through a `puts` or `putchar` declared in the program, and the oracle
compares what they print as well as how they exit. The escapes are five of
the six character constants have: `\0` is refused in a string, because C
reads octal digits after it. Two literals side by side, which C joins, are
refused too. `printf` is not reachable yet: it is variadic, and Apple's arm64
passes variadic arguments on the stack. Eight more oracle programs, 123 in
all, and 31 refusals.

**Last: `struct`, which completes step one.** `struct point { int x; int y; };`
at file scope, then `p.x`, `q->y`, arrays of structs, structs inside structs,
member arrays, `sizeof(struct point)`, and a struct holding a pointer to its
own kind, so a linked list compiles and walks. Members are laid out as `cc`
lays them out, each at the next offset its alignment allows and the whole
rounded to its widest member, so `sizeof` agrees for every struct the oracle
tried. A step through a pointer to a struct counts in structs of any size.
**A struct is never copied whole here**: assigning one, initialising one from
another and passing one to a function are refused, and a pointer to one is
the way to hand it around. A struct defined inside a function, one with no
tag, one with no members and a pointer to one nobody defined are refused too;
`cc` compiles all four. Twenty more oracle programs, 143 in all, and 49
refusals. **Nothing in Phoenix itself changed through the whole subset**,
which is what the C arc predicted when it began.

**Tests:** 224 → 264, forty-two in and two retired. The first thirteen were
all but one a refusal: the address of
something that is not a place and an assignment to one, both from the grammar;
a `*` on an `int` and on a name nothing declared; a `-` and a `*` on a
pointer; and pointer arithmetic, which after the ninth parameter is the
second thing in the C subset refused for being outside the subset rather than
outside the language. Then a `sizeof` of a name nothing declared and a `*` on
what a `sizeof` is worth, and the pin on `sizeof(sizeof(int))`, which asserts
both answers so that closing the gap fails with the old numbers in it. Last,
the two refusals of pointer arithmetic were retired by indexing, and four came
in: two pointers added, a pointer taken from a number, a subscript on an
`int`, and two pointers to different types subtracted. And a second pin
beside the first, on the size of a pointer difference, and a refusal of a
`char *` less an `int *`, three of character constants outside the
subset, and two of string literals. Then eighteen for `struct`: two from the
grammar, seven about a definition, four about a member asked of the wrong
thing, one about pointers to two different structs, and four about copying
a struct whole.

---

## 2026-09-21: a C subset begins, with `cc` as its oracle

**A C compiler has its first six constructs: [`languages/c/`](../languages/c/).**

    phx --driver arm64 languages/c/c-arm64.phx prog.c > prog.s
    cc prog.s -o prog && ./prog

`int main(){return 42;}`, then `+ - * /` with parentheses, then unary minus
and the six comparisons, then a local `int`, then `if`, `while`, `for` and
blocks, then functions with parameters and calls: functions returning `int`
with up to eight `int` parameters, prototypes, a body of declarations,
assignments, expression statements, control flow and `return`s, expressions
over constants, locals and calls, and the two comment shapes.

**The calling convention is AAPCS64 as Apple applies it**: the first eight
arguments in `x0` to `x7`, the result in `x0`. A caller pushes each argument
as it is evaluated, then loads the registers from the stack and drops it; a
callee stores each register into its parameter's slot in the prologue, after
which a parameter is a local. Recursion, mutual recursion through a
prototype, and a call nested in an argument are in the oracle. A ninth
parameter is refused by name rather than mis-compiled.

**C99 6.5.2.2 wants a declaration above every call**, and `cc` enforces it,
so the gathered table awk uses for a call above its function is not what C
needs. The declared functions are a thread; a definition binds itself on the
way in so its body can recurse. A gather pass remains for the two questions
no order can answer, a function defined twice and one declared with two
arities.
Six of C's fifteen expression levels; a comparison is an `int` worth 0 or 1
that chains to the left the way C11 says it does, and assignment is an
expression worth what it assigned, grouping to the right.

**The first pass that can say no.** `locals` is a symbol pass in `c.phx`: a
thread of what has been declared, set afresh at each function and saved and
restored around each block, and a slot counter that only grows. A name nothing
declared, one declared twice in a scope, one read after its block has closed,
a parameter declared again in the body, a call before its declaration or with
the wrong number of arguments, a function defined twice or declared with two
arities, and a ninth parameter, are refused with a position, and
`tests/refused/` holds the eleven programs that show it. A second thread holds only the current block's names,
because C11 6.2.1 lets an inner block shadow an outer one and a single table
cannot tell shadowing from redeclaring. The emit pass turns a
slot into an offset below the frame pointer and lowers `sp` past the locals in
the prologue, rounded to sixteen. `c.phx` is the grammar and the tree and has no opinion about a machine;
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
can be called is all a program can say. Forty-two programs, among them the
groupings the folds have to get right, a quotient that truncates toward zero,
a signed comparison, five locals whose slots must not overlap, a dangling
`else`, a `for (;;)` that only a `return` leaves, and two nested loops whose
labels must not collide. Every branch target is a label the program never
wrote, from a thread counted on leaving, the way `languages/z80/` numbers
nothing and `languages/solvm/` numbers its chunks. One of them, `3 > 2 > 1`, is C11 as written and an
error to this `cc` by default, so the oracle downgrades that one warning by
name rather than lose the witness. Nothing in the directory has a
hand-written expected result, which is the rule ROADMAP 6 set for the arc.

**On the roadmap.** [6.1](COMPLETED.md#61-step-one--a-subset-that-runs-and-cc-as-its-oracle)
was written on 2026-09-06 and this is its first step taken; the entry itself is
unchanged but for a marker at the construct that exists. Its three predictions
are not yet scoreable: the first is about reaching `struct` with no change to
the tool, and the tool has not been asked for anything.

**Tests:** 211 → 224. Thirteen new ones: that the description reads, one
that runs the oracle programs and reports how many agree with `cc`, and
eleven refusals from the `functions` and `locals` passes. The first
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
[`divergent/two-rounds.z80`](../languages/z80/tests/oracle/two-rounds.z80), where
the second `br` shrinking is what brings the first into range on a **third**
walk nobody makes. No fixed number of walks is the answer, which is
[ROADMAP 2.5](COMPLETED.md#25-circular-attributes--from-jastadd) — now with the
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
