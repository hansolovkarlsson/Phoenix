# Tutorial: writing SolVM bytecode by hand

*About half an hour. You build one program in seven steps, make four of the
mistakes on purpose, and finish by checking your bytecode against the one
`solas` emits for the same program in Solveig.*

Every command and every piece of output on this page was run exactly as it is
written. Nothing is added to this repository — the files go in a directory of
your own.

You need `bin/phx` (`make` at the top of the repository builds it) and, for the
last step only, a [Solveig](https://github.com/hansolovkarlsson/Solveig)
checkout for `solas` and `solvm`.

Set these up once, in the directory you are working in — the commands below
use both:

```sh
$ export PATH=/path/to/Phoenix/bin:/path/to/Solveig/bin:$PATH
$ asm=/path/to/Phoenix/languages/solvm/solvm-sob.phx
```

`$asm` is the assembler: a description Phoenix reads. It stays the same for
every command on this page.

---

## 1. There is no add instruction

SolVM is a stack machine in which **nearly everything is a message send.** Put
this in `sum.sasm`:

```
.slots 1
        const   #2
        const   #40
        send    add, 1
        send    display, 0
        pop
        halt
```

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
42
```

Read it as a stack. `const #2` pushes a receiver. `const #40` pushes an
argument. `send add, 1` pops **both** — one argument and a receiver — sends
`add`, and pushes the reply. Then `display` is sent to that reply with no
arguments at all.

That is not an example of arithmetic. **It is the only arithmetic there is:**
no add instruction, no compare instruction, no conditional instruction. Twenty-
one opcodes cover the machine and one of them does most of the work.

`--raw` is not optional. A `.sob` is bytes, and without it the file gains a
trailing newline and will not load.

### The first mistake: forgetting an argument

Take out the `const #40`:

```
.slots 1
        const   #2
        send    add, 1
        ...
```

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
solvm: cannot load 'sum.sob': bytecode is internally inconsistent -- an instruction takes more from the stack than is on it
```

**The assembler said nothing**, and that is worth understanding now rather than
later. Whether the stack has enough on it depends on which *paths* reach an
instruction, which is dataflow rather than a walk over the program — so it is
SolVM's verifier that catches it, at load, before a single instruction runs.
[The manual](manual.md#9-getting-the-stack-wrong) has the discipline that keeps
you out of trouble; the short version is coming up next.

Put the `const #40` back.

---

## 2. A statement is an expression and a `pop`

Every expression leaves exactly one value. A **statement** is an expression
whose value nobody wants — so it is followed by `pop`. That is the `pop` before
`halt`: `display` answered something, and nothing wanted it.

Take it out and the program still runs:

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
42
```

Nothing objects, because nothing requires the stack to be empty at `halt`. But
try the same omission inside a loop, which you will write in step 4, and:

```
solvm: cannot load 'sum.sob': bytecode is internally inconsistent -- two paths reach one instruction with different stack depths
```

A loop that leaves one extra value per pass arrives back at the top a different
height each time, and *that* the verifier does see. **Write the `pop`.** Put it
back.

---

## 3. Somewhere to keep things

`setglob` binds a name; `global` looks one up. Both are ordinary instructions,
and `global` is the one thing in the machine that is a lookup rather than a
send.

```
.slots 1
        const   #0
        setglob total
        pop
        const   #1
        setglob i
        pop
        halt
```

Two statements, two `pop`s — and here is why. **Every assignment leaves its
value on the stack**: `setglob`, `setlocl`, `setoutr` and `setslot` all bind
*and* leave what they bound. That looks wasteful until you want `c := b := 45`,
which then costs nothing. A statement that does not want the value says so.

---

## 4. A label, and the two directions

Now the loop: add up 1 to 5.

```
.slots 1
        const   #0
        setglob total
        pop
        const   #1
        setglob i
        pop
top:
        global  i
        const   #6
        send    lessThan, 1
        exitf   done
        global  total
        global  i
        send    add, 1
        setglob total
        pop
        global  i
        const   #1
        send    add, 1
        setglob i
        pop
        loop    top
done:
        nil
        pop
        global  total
        send    display, 0
        pop
        halt
```

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
15
```

Three things to notice.

**The condition is inside the loop.** `top:` is above it, and `loop top` goes
back to it — so it is re-evaluated every pass. Put the condition above the
label and it is tested once.

**`exitf` pops what the condition answered** and leaves when it is false. It is
a jump like any other; the label it names is the way out.

**`loop` is a different instruction from `jump`.** An offset is unsigned, so
forward and backward are separate opcodes. Which one a label needs is a fact
about the program, and the assembler will tell you when you get it wrong. Try
`jump top` instead:

```sh
$ phx --driver check "$asm" sum.sasm
sum.sasm:23:9: error: 'top' is behind this, and a backward jump is `loop`
          jump    top
          ^
```

`--driver check` assembles and throws the bytes away — the exit status is the
answer, which is what you want in a Makefile.

The `nil` after `done:` is `whileTrue`'s answer in Solveig, and the `pop` after
it discards that. Keeping it makes step 7 work; the next step explains why it
has to be there at all.

---

## 5. A branch, and the rule that makes branches work

There is no conditional instruction either. `jumpf` pops a boolean and jumps
when it is false. Here is `c:ifTrue({ ... })`, which is the shape `solas`
emits — try it in a file of its own:

```
.slots 1
        global  true
        jumpf   otherwise, ifTrue
        string  "yes"
otherwise:
        send    display, 0
        pop
        halt
```

```sh
$ phx --raw "$asm" t.sasm > t.sob
$ solvm t.sob
solvm: cannot load 't.sob': bytecode is internally inconsistent -- two paths reach one instruction with different stack depths
```

**Look at what reaches `otherwise:`.** Falling through, the stack has the
string on it. Jumping, it has nothing. One instruction, two heights, and the
verifier refuses the file.

> **Both arms of a branch have to leave the same number of values.**

Which usually means the arm with nothing to say still has to say something:

```
        global  true
        jumpf   otherwise, ifTrue
        string  "yes"
        jump    endif
otherwise:
        nil
endif:
        send    display, 0
        pop
        halt
```

```sh
$ phx --raw "$asm" t.sasm > t.sob
$ solvm t.sob
yes
```

That `nil` is not decoration — it is the else-arm's value, and it is why
`ifTrue` answers nil when its condition is false. The same rule is why step 4's
loop has a `nil` after `done:`.

**The `ifTrue` on the `jumpf` is a selector**, and it is carried for one reason:
an inlined message has to complain exactly as the real send would. Write the
message the jump stands in for and a non-boolean says *does not understand
`ifTrue`*, which is what somebody reading the error needs. [The manual](manual.md#7-control-flow)
has all six shapes `solas` inlines.

---

## 6. A block

A block is a nested chunk. Add one to the bottom of `sum.sasm`, and use it
before the `halt`:

```
        block   twice
        global  total
        send    value, 1
        send    display, 0
        pop
        halt

.block twice arity 1 slots 2
        local   1
        local   1
        send    add, 1
        return
.end
```

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
30
```

`block twice` pushes the block; `global total` pushes the argument;
`send value, 1` calls it. Inside, `local 1` is its first argument — because
**slot 0 is the receiver**, always, and `slots 2` is the whole frame: the
receiver and one argument.

A `.block` occupies no space where it stands, so it can sit after the `halt`.
It fills a slot in the enclosing chunk's method table, and the name is resolved
once the whole chunk has been read — so you may push a block above its own
definition.

**A block ends with `return`**, not `halt`; `return` answers the top of the
stack. The assembler insists on both, and will say so.

`solvm --dump` shows the nesting:

```sh
$ solvm --dump sum.sob | tail -6
== twice ==
0000   35 LOCAL       1
0002   36 LOCAL       1
0004   37 SEND        0 'add' (1 args)
0008   38 RETURN
30
```

The `30` on the end is the program itself: **`--dump` disassembles and then
runs**, which is usually what you want and occasionally a surprise.

Two more things worth seeing there. The second column is the line of **your
assembly** that each instruction came from, so a traceback points at what you
wrote. And the chunk is called `twice` — `solas` names every block `block`, so
naming them is something writing assembly buys you.

### Name the frame, and say `local n`

`local 1` twice tells you nothing about what slot 1 holds. Declare the frame as
its slots' names instead of a count, and the instruction can say it. Change the
block's header and its two `local`s:

```
.block twice arity 1 slots self, n
        local   n
        local   n
        send    add, 1
        return
.end
```

```sh
$ phx --raw "$asm" sum.sasm > sum.sob
$ solvm sum.sob
30
```

**The name is resolved here, not in the machine.** `self` is slot 0 and `n` is
slot 1, because the list is positional and slots count from zero — so `local n`
*is* `local 1`, one byte, and the disassembly does not change at all:

```sh
$ solvm --dump sum.sob | tail -6
== twice ==
0000   35 LOCAL       1
0002   36 LOCAL       1
0004   37 SEND        0 'add' (1 args)
0008   38 RETURN
30
```

Two things it buys. The first is the mistake it makes impossible: `local 0` in
this frame is a perfectly valid instruction that pushes the receiver instead of
the argument, and nothing would tell you — `local nn` is refused by name, and
the refusal says what the frame does have.

The second is that the names go into the chunk, where `solvm --trace` finds
them:

```sh
$ solvm --trace sum.sob | tail -3
  [sum.sasm:29] value(n: #15)
  -> #30
30
```

`value(n: #15)` rather than `value(#15)` — which is also what `solas` produces
from the Solveig in the next step, and one of the things the two are compared
on.

---

## 7. Check it against the compiler

This is the step that makes the rest trustworthy, and it is the habit worth
taking away.

Write the same program in Solveig, as `sum.sol` — the block included, so that
the two really are the same program:

```
total := #0.
i := #1.
{ i:lessThan(#6) }:whileTrue({
  total := total:add(i).
  i := i:add(#1)
}).
{ n | n:add(n) }:value(total):display.
```

```sh
$ solas sum.sol -o solas.sob
$ solvm solas.sob
30
```

Same answer — which proves less than it looks like. **Two wrong encodings can
print the same thing.** So compare what each one *compiled to*:

```sh
$ norm() { solvm --dump "$1" | sed -E -e 's/^== .* ==$/== chunk ==/' \
                                      -e 's/^([0-9]{4})[[:space:]]+([0-9]+|\|)[[:space:]]/\1 /'; }
$ norm solas.sob > a ; norm sum.sob > b
$ diff a b && echo "identical"
identical
```

The `sed` takes out the two things two producers of one program are entitled to
disagree about: the source-line column and the chunk's own name. Everything
else — every byte offset, every opcode, every side-table index — matches.

**You wrote by hand exactly what the compiler emits.** Not something
equivalent: the same bytes.

That works because side-table indices are assigned **where a name is first
seen**, and `solas` follows the same rule — so writing the instructions in the
order the Solveig runs them gets the same tables. It is also how this assembler
is tested: `languages/solvm/oracle/` holds a `.sol` for every program in
`programs/`, and `make test` compares them exactly this way.

---

## What you now know

| | |
| --- | --- |
| `send` | the receiver first, then the arguments. It is the whole of arithmetic |
| `pop` | one per statement, because every expression leaves a value and every assignment leaves what it bound |
| `global` / `setglob` | the one lookup in the machine |
| a label, `loop`, `exitf` | forward and backward are different opcodes, and the assembler checks which you need |
| `jumpf` | and the rule that both arms leave the same number of values |
| `.block` / `block` / `return` | a nested chunk, its method-table slot, and slot 0 being the receiver |
| `slots self, n` and `local n` | naming a frame, and addressing it by name — the same byte, and a wrong slot becomes a refusal |
| `solvm --dump` | the only disassembler — Phoenix can emit `.sob` and cannot read one |

## What is left

**`outer`, and blocks that read the frame they were written in.** That is the
one part of the machine this tutorial skipped;
[`programs/adder.sasm`](programs/adder.sasm) is the smallest honest example,
and [the manual](manual.md#8-blocks) explains the capture flag the assembler
derives for you — and the run-time error it cannot prevent.

**The other five inlined constructs.** You built `ifTrue` and `whileTrue` by
hand; `ifFalse`, `ifElse`, `and` and `or` are in
[the manual](manual.md#7-control-flow), and
[`programs/control.sasm`](programs/control.sasm) is all six written out and
checked against `solas`.

| | |
| --- | --- |
| [manual.md](manual.md) | the machine, in the order it is learned |
| [reference.md](reference.md) | every mnemonic, directive and diagnostic |
| [cheatsheet.md](cheatsheet.md) | one page |
| [README.md](README.md) | how the assembler is built, and how it is tested |
| [`../../docs/tutorial-assembler.md`](../../docs/tutorial-assembler.md) | the other side: writing an assembler like this one, in Phoenix |
