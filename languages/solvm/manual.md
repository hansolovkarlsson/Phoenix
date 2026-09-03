# The SolVM assembly manual

*The machine, and how to write for it, in the order you would learn it. For a
lookup read [reference.md](reference.md); for one page,
[cheatsheet.md](cheatsheet.md).*

---

## Contents

1. [The machine](#1-the-machine)
2. [The shape of a program](#2-the-shape-of-a-program)
3. [Two tables, and why a name is not a value](#3-two-tables-and-why-a-name-is-not-a-value)
4. [Frames and slots](#4-frames-and-slots)
5. [Sending](#5-sending)
6. [Statements, and the discard](#6-statements-and-the-discard)
7. [Control flow](#7-control-flow)
8. [Blocks](#8-blocks)
9. [Getting the stack wrong](#9-getting-the-stack-wrong)
10. [Working on a program](#10-working-on-a-program)
11. [Idioms and pitfalls](#11-idioms-and-pitfalls)

---

## 1. The machine

SolVM is a **stack machine in which nearly everything is a message send.**

```
        const   #2
        const   #40
        send    add, 1
```

Push a receiver. Push an argument. `send` pops both, sends `add`, and pushes
the reply — 42.

That is not an example of arithmetic; **it is the only arithmetic there is.**
There is no add instruction, no compare instruction, no conditional
instruction, and no instruction that knows what a class is. Twenty-one opcodes
cover the whole machine, and one of them does most of the work.

The one exception is worth knowing early: **`global` is a lookup, not a send.**
Resolving a name has to bottom out somewhere.

### Operand widths follow one rule

It is about what bounds the number, not about the instruction:

| | |
| --- | --- |
| an index into a side table — a constant, a name, a method | **u16**, because those tables grow with the program |
| a frame slot, a nesting depth, an argument count | **u8**, because the machine bounds those: a frame of more than 255 slots is refused before it runs |

Jump offsets were sixteen bits from the start, so u16 is the only width the
format has.

---

## 2. The shape of a program

```
; a comment runs to the end of the line
.slots 1

        string  "hello, world"
        send    display, 0
        pop
        halt
```

Four lines of instruction, and every one of them earns its place:

- `string` builds a string and pushes it;
- `send display, 0` pops it as the receiver, sends `display` with no arguments,
  pushes the reply;
- `pop` throws that reply away, because this was a statement and nothing wants
  its value;
- `halt` stops the machine, and **a script has to end with it.**

`.slots 1` says how big the script's frame is. One is the minimum and the
default, so this program could leave it out; it is written here because a
program that grows will need it.

Assemble and run:

```sh
phx --raw languages/solvm/solvm-sob.phx hello.sasm > hello.sob
solvm hello.sob
```

`--raw` matters: a `.sob` is bytes, and without it a trailing newline is added
to the file.

---

## 3. Two tables, and why a name is not a value

A chunk carries two side tables, and which one a thing goes in is not
bookkeeping — it is the difference between something the file can carry whole
and something only a running VM can make.

**Constants** are values: integers, floats, booleans, nil. A `.sob` writes them
out as a tag byte and a payload, and the loader has them back before the first
instruction runs.

**Names** are text: message selectors, global names, and — this is the one that
surprises people — **the bytes of every string literal.**

```
        string  "hello, world"
```

`hello, world` goes in the *names* table, and `string` builds a `SolString`
from it at run time. It cannot be a constant, because a string is an object on
a heap and the thing that writes the file has no VM to allocate one in.
`symbol` works the same way and for the same reason.

### Both tables intern, and the order is the order you write

An index is assigned **where the text is first seen.** Write `send add, 1`
three times and `add` occupies one entry, used three times.

That matters for exactly one reason, and it is a good one: **`solas` follows the
same rule.** So an assembly program written in the same order as the Solveig it
came from gets the *same indices*, and `solvm --dump` of the two can be laid
side by side and compared line for line. That is how this assembler is tested
([reference.md § 7](reference.md#7-the-side-tables)).

Interning is by value, and the tag is part of the key — so `#1` and `1.0` are
two entries, not one.

---

## 4. Frames and slots

A frame is an array of slots, and every slot is reached by number.

> **Slot 0 is the receiver.** In a block it is `self`; in a script there is no
> receiver, so slot 0 is unused — and still counted.

After slot 0 come the arguments, in order, and then any locals the code needs.
That is the whole layout, and `.slots n` (or a block's `slots n`) is how many
there are. A frame of more than 255 is refused.

### Naming the slots

A frame may be written as its slots' names instead of a count:

```
.slots self, total, i
.block twice arity 1 slots self, n
```

Three slots either way. The names go into the chunk, and **`solvm --trace`
reads them to name a call's arguments** — `value(n: #41)` rather than
`value(#41)`, which is what `solas` produces and what this matches. They are
for reading only: an instruction still says `local 1`.

The table is positional, so the first name *is* slot 0 — the receiver, which
SolVM never reads a name for. `self` is the convention.

### Three ways to reach a variable, and they are different instructions

| | |
| --- | --- |
| `global n` | a name in the global environment. A lookup |
| `local s` | slot `s` of **this** frame |
| `outer d, s` | slot `s` of the frame `d` steps out along the **lexical** chain |

A compiler for a language would have to *work out* which of the three a name
needs; that is most of what `solveig-sob.phx` is. **In assembly you say which**,
which is why an assembler is a much smaller description than a compiler.

`outer 1, 1` is *the frame I was written in, slot 1*. Depth 0 is this frame, so
`outer 0, s` is a roundabout `local s`.

### Every assignment leaves its value

`setglob`, `setlocl`, `setoutr` and `setslot` all bind **and leave the value on
the stack.**

```
        const   #45
        setlocl 1
        pop
```

That looks wasteful until you want `c := b := #45`, which then costs nothing:
the inner assignment's value is exactly what the outer one stores. A statement
that does not want the value writes `pop`, and that is the pattern you will
write more than any other.

---

## 5. Sending

```
        <receiver>
        <argument 1>
        ...
        <argument n>
        send    selector, n
```

**The receiver goes on first**, then the arguments in order. `send` pops `n + 1`
values and pushes one.

They are already laid out contiguously on the stack, which is why the callee's
frame can point straight at them — slot 0 *is* the receiver where it already
sits, and nothing is copied to make the call.

A selector is written as a name, or in quotes when it collides with a mnemonic:

```
        send    add, 1
        send    "return", 0
```

Nothing checks that the receiver understands the message, or that the count
matches. Both are run-time errors, and `solvm` reports them against the line of
assembly they came from.

---

## 6. Statements, and the discard

Every expression leaves one value. A **statement** is an expression whose value
nobody wants, so it is followed by `pop`.

```
        global  obj
        send    size, 0
        send    display, 0
        pop
```

Three sends chained — each reply becoming the next receiver — and one `pop` at
the end, because only the last value is left over.

**A chunk's answer is its last value.** A block ends with `return`, which
returns the top of the stack, so the last statement of a block is *not* popped:

```
.block answer arity 0 slots 1
        const   #1
        const   #2
        send    add, 1
        return
.end
```

Get this wrong in either direction and the verifier notices — see
[§9](#9-getting-the-stack-wrong).

---

## 7. Control flow

There is no conditional instruction. What there is: a jump, a jump that pops a
boolean, and a jump that goes backward.

```
        jump    L           forward, always
        jumpf   L, sel      pop a boolean, go to L when it is false
        exitf   L           the same, for leaving an inlined loop
        loop    L           backward, always
        chkbool sel         require a boolean on top, and leave it there
```

**Forward and backward are different opcodes**, because an offset is unsigned.
Which one a label needs is a fact about the program, so the assembler checks it
and names the other mnemonic when you get it wrong.

### The selector three of them carry

`jumpf`, `exitf` and `chkbool` take a selector they never push. It is there for
one reason: **an inlined message has to complain exactly as the real send
would.** `c:ifTrue({ ... })` compiled to a jump must still say *does not
understand `ifTrue`* when `c` is not a boolean — so the jump carries the name
the programmer wrote.

Write the selector the construct stands in for, and the diagnostics come out
right.

### The six recipes

These are the shapes `solas` emits, and there is no better source for them:
these six messages are the ones it inlines, and anything else written as a
message is an ordinary `send` with none of these instructions in it.

**`c:ifTrue({ body })`** — the answer when false is nil.

```
        <c>
        jumpf   otherwise, ifTrue
        <body>
        jump    endif
otherwise:
        nil
endif:
```

**`c:ifFalse({ body })`** — the mirror; the nil is in the fall-through.

```
        <c>
        jumpf   body, ifFalse
        nil
        jump    endif
body:
        <body>
endif:
```

**`c:ifElse({ a }, { b })`** — two arms and no nil.

```
        <c>
        jumpf   second, ifElse
        <a>
        jump    endif
second:
        <b>
endif:
```

**`{ c }:whileTrue({ body })`** — the condition is emitted *inline* at the top,
`loop` goes back to it, and the whole thing answers nil.

```
top:
        <c>
        exitf   done
        <body>
        pop
        loop    top
done:
        nil
```

The `pop` is `whileTrue` discarding what the body answered, once per pass.
Neither block is ever built — no `block`, no frame, no send.

**`c:and({ b })`** — short-circuits to `#false`, and the block's answer *is* the
reply, which is why it is checked and left rather than consumed.

```
        <c>
        jumpf   short, and
        <b>
        chkbool and
        jump    done
short:
        const   #false
done:
```

**`c:or({ b })`** — the same with the arms swapped and `#true` as the
short-circuit.

```
        <c>
        jumpf   long, or
        const   #true
        jump    done
long:
        <b>
        chkbool or
done:
```

Notice that `#true` and `#false` here are **constants**, while a Solveig program
reaching `true` gets a `global`. Both spellings turn up in real bytecode, and
that is why the assembler's named constants carry a `#` — so `global true`
still works.

---

## 8. Blocks

A block is a nested chunk plus three numbers in the enclosing chunk's method
table.

```
.block adder arity 1 slots 2
        outer   1, 1
        local   1
        send    add, 1
        return
.end
```

- `arity 1` — one argument, so a `value` send with one argument;
- `slots 2` — the receiver in slot 0 and the argument in slot 1;
- `outer 1, 1` — slot 1 of the frame this block was written in;
- `local 1` — its own argument.

`block adder` is what pushes it, and **it captures the running frame as the
block's home** — which is what makes `self` and the enclosing locals still mean
the right thing whenever the block is run.

A definition occupies no space where it stands, and may sit before or after the
`block` that pushes it: a block name is resolved once the whole chunk has been
read.

### The flag you do not write

A method record says *is a block* and *captures its home frame*. The assembler
sets the second when **this chunk's own code** contains an `outer` or a
`setoutr` — which is exactly what `solas` does, and its comment is the reason a
nested chunk is not consulted:

> a nested chunk is not consulted: its depths are counted from its own frame,
> so whether it reaches past this one is its business, recorded on its own flag

I got that wrong on the first attempt, propagating it up from nested blocks on
the reasoning that a frame read from below has to survive too. Both spellings
run the same program and print the same answer; only comparing the *bytes*
against `solas` found it.

### A block cannot outlive its home frame

```
solvm: block outlived the frame it was written in
```

Frames live on the stack. A block that escapes the send that made it and is
called afterwards finds its home gone — and **no flag prevents that.** It is a
run-time error, it is SolVM's, and the assembler cannot see it coming. If you
return a block from a block, call it before the outer one returns.

---

## 9. Getting the stack wrong

This is the one class of mistake the assembler cannot catch, so it is worth its
own section.

SolVM's verifier follows control flow and computes the stack height at every
instruction. Two things make it refuse a file:

```
solvm: cannot load 'x.sob': bytecode is internally inconsistent
       -- an instruction takes more from the stack than is on it
```

```
two paths reach one instruction with different stack depths
```

The first is a `send` with fewer values beneath it than `argc + 1`. The second
is a branch whose arms do not balance — which is why every recipe in
[§7](#7-control-flow) leaves exactly one value on both paths, and why `ifTrue`
has a `nil` in its else-arm rather than nothing.

**Count as you write.** Each instruction's effect is in
[reference.md § 5](reference.md#5-the-instruction-set), and the discipline is
just:

- an expression leaves **one** value;
- a statement is an expression and a `pop`;
- both arms of a branch leave the same number;
- a chunk ends with one value and `return`, or with `halt`.

Computing this is dataflow rather than a walk over a tree, which is precisely
why a Phoenix pass cannot do it: an attribute is worked out once per node, and
this needs the *paths*.

---

## 10. Working on a program

The loop, in the order you will want it.

| | |
| --- | --- |
| `phx --driver check solvm-sob.phx p.sasm` | does it assemble? The exit status is the answer |
| `phx --raw solvm-sob.phx p.sasm > p.sob` | the bytes |
| `solvm --dump p.sob` | what came out: offsets, opcodes, and the table entry each operand names |
| `solvm p.sob` | run it |
| `phx --driver render solvm.phx p.sasm` | the program written back out, normalised |
| `phx --tree solvm.phx p.sasm` | the tree, when the parse is what is in doubt |

**`solvm --dump` is the tool to reach for**, and not only when something is
wrong. It prints the resolved side-table entry beside every operand — `SEND 1
'display' (0 args)` — so it answers "did I intern what I meant" and "did that
label land where I thought" in one look. Phoenix cannot read a `.sob`, so this
is the only disassembler there is
([reference.md § 10](reference.md#10-what-the-assembler-writes)).

**Write the Solveig too.** The most useful thing in this directory is
`oracle/*.sol`: the same program in the language, for `solas` to compile. Then
`solvm --dump` both and compare. It is how the assembler is tested and it is
how a program of your own is best checked — and it catches things that
comparing output never will, because two wrong encodings can print the same
answer.

---

## 11. Idioms and pitfalls

### Every mnemonic is a reserved word

Worked out from the grammar rather than declared, so a label cannot be called
`loop` and `arity` and `slots` are spoken for too. A selector that collides
goes in quotes: `send "return", 0`.

### `#true`, not `true`

The three named constants carry a marker precisely so that `true` and `false`
stay available as *names* — because Solveig reaches its booleans as globals, and
`global true` is one of the first things anybody writes.

### One `pop` per statement, and none after the last

The commonest mistake in a first program, in both directions. A missing `pop`
leaves the stack growing; an extra one takes something a later instruction
needed.

### Both arms of a branch leave the same number

Which usually means a `nil` in the arm that has nothing to say. Look at
`ifTrue` in [§7](#7-control-flow) — that `nil` is not decoration.

### The condition of a loop goes inside the loop

`whileTrue` re-evaluates it every pass, so it is emitted after the label that
`loop` goes back to, not before it. Putting it above `top:` tests once.

### Declare the frame you actually use

`local 4` in a frame of 2 is refused, and named — but the assembler can only
check against the number you wrote, so `.slots` being too *large* costs a
little stack and nothing tells you.

### Write the selector an inlined jump stands for

`jumpf done, ifTrue` rather than `jumpf done, x`. Nothing checks it, and the
only thing it affects is the complaint a non-boolean produces — which is
exactly the thing you will want to be right when it happens.

---

## Where to go next

| | |
| --- | --- |
| [reference.md](reference.md) | every mnemonic, directive and diagnostic |
| [cheatsheet.md](cheatsheet.md) | one page |
| [programs/](programs/) | four programs, each with the Solveig it was written from |
| [README.md](README.md) | how the assembler itself is built, and how it is tested |
| [`../../docs/tutorial-assembler.md`](../../docs/tutorial-assembler.md) | the two-pass shape this is built out of, from nothing |
