# SolVM assembly reference

*Every mnemonic, every directive, every diagnostic. For an explanation rather
than a lookup read [manual.md](manual.md); for one page,
[cheatsheet.md](cheatsheet.md).*

The instruction set is SolVM's, defined in `solum/include/solum/bytecode.h`,
and the container is `solum/include/solum/serialize.h`. Where this page and
those disagree, they are right.

---

## Contents

1. [Running the assembler](#1-running-the-assembler)
2. [The text of a program](#2-the-text-of-a-program)
3. [Directives](#3-directives)
4. [Labels](#4-labels)
5. [The instruction set](#5-the-instruction-set)
6. [Operands](#6-operands)
7. [The side tables](#7-the-side-tables)
8. [Jumps](#8-jumps)
9. [Blocks](#9-blocks)
10. [What the assembler writes](#10-what-the-assembler-writes)
11. [Every diagnostic](#11-every-diagnostic)
12. [What the assembler does not check](#12-what-the-assembler-does-not-check)

---

## 1. Running the assembler

```sh
phx --raw languages/solvm/solvm-sob.phx prog.sasm > prog.sob
solvm prog.sob
```

`--raw` is not optional for the `sob` driver: it writes the answer exactly,
adding no trailing newline, and a `.sob` is bytes.

| Driver | |
| --- | --- |
| `sob` | the bytecode. The default |
| `check` | assemble and throw the bytes away — the exit status is the answer |
| `render` | write the program back out, from `solvm.phx` |

```sh
phx --driver check  languages/solvm/solvm-sob.phx prog.sasm   # does it assemble?
phx --driver render languages/solvm/solvm.phx     prog.sasm   # normalised source
phx --tree          languages/solvm/solvm.phx     prog.sasm   # the tree
phx --nodes         languages/solvm/solvm.phx                 # the node types
```

To see what came out, use SolVM's own disassembler — **Phoenix cannot read a
`.sob`**, and [§10](#10-what-the-assembler-writes) says why:

```sh
solvm --dump prog.sob
```

---

## 2. The text of a program

**Comments** run from `;` to the end of the line.

**Whitespace is not significant.** The indentation in these examples is a
convention, not a rule.

| | |
| --- | --- |
| a name | a letter or `_`, then letters, digits and `-`. `and-done` is one name |
| an integer | `0`, `42` — a slot, a depth, an argument count, a slot count |
| an integer constant | `#42`, `#-7` |
| a float constant | `3.5`, `-1.25`. A digit, a point, and a digit — `.5` and `5.` are not floats |
| a named constant | `#true`, `#false`, `#nil` |
| a text literal | `"hello"`, with the escapes below |
| a directive | `.slots`, `.block`, `.end` |

**Escapes in a text literal** are `\n`, `\t`, `\r` and `\"`. A **doubled
backslash is refused** rather than guessed at, so everything accepted is
unambiguous. A literal newline inside the quotes is allowed and means itself.

### Reserved words

**Every mnemonic is a reserved word**, worked out from the grammar rather than
declared. So are `arity` and `slots`. A label, a global, a block or a selector
cannot be spelled as any of:

```
const    nil      global   setglob  local    setlocl  outer    setoutr
block    string   symbol   send     setslot  jump     jumpf    exitf
chkbool  loop     pop      return   halt     arity    slots
```

**A selector or a name that collides is written in quotes**, which is what the
text form of an operand is for:

```
        send    "return", 0
        global  "block"
```

`true`, `false` and `nil` are **not** reserved as names — only `nil` is, as a
mnemonic. That is why the named constants carry a `#`: Solveig reaches its
booleans *as globals*, so `global true` and `global false` have to work.

---

## 3. Directives

### `.slots n`

How many frame slots the **script** addresses, at least 1 and at most 255.
Default 1. Only valid at the top level; a block declares its own frame in its
header.

```
.slots 3
```

The count is the whole frame: slot 0, then the arguments, then any locals.
A script has no receiver, so its slot 0 is unused but still counted.

Said more than once, the last one wins. That is a consequence of how it is
gathered rather than a feature; write it once, at the top.

### `.block name arity a slots s` … `.end`

A nested chunk, which is what a Solveig block compiles to. It occupies no space
where it stands — it fills a slot in the enclosing chunk's method table, and
[`block name`](#5-the-instruction-set) is what pushes it.

```
.block adder arity 1 slots 2
        outer   1, 1
        local   1
        send    add, 1
        return
.end
```

| | |
| --- | --- |
| `name` | what the method is called. It is what `solvm --dump` prints as the chunk's title and what a traceback names, so it is worth spelling properly |
| `arity` | how many arguments, 0 to 255. A `value` send with a different count is a run-time arity error |
| `slots` | the whole frame: 1 for the receiver, then the arguments, then locals. At least `arity + 1`, at most 255 |

Definitions **nest**, and a definition may appear anywhere in the chunk that
owns it — before or after the `block` that pushes it, since a block name is
resolved after the whole chunk has been read.

Two blocks of one name in one chunk are refused. Blocks in *different* chunks
may share a name.

**SolVM follows at most 16 frames**, so a block nested more than 16 deep is
refused.

---

## 4. Labels

```
top:
        global  i
        ...
        loop    top
```

A label names the address of whatever instruction follows it, and occupies no
space. It is **local to its chunk**: a jump cannot leave the chunk it is in,
and a block's labels are invisible from outside it.

A label may be used before it is defined — that is the whole reason the
assembler is two passes.

Two labels of one name in one chunk are refused. Both would have resolved to
the first and nothing downstream could have told.

---

## 5. The instruction set

`Byte` is the opcode's value. `Bytes` is the whole instruction. `Stack` reads
*before* → *after*, with the top on the right.

### Pushing values

| Mnemonic | Byte | Operands | Bytes | Stack | |
| --- | --- | --- | --- | --- | --- |
| `const K` | 0 | u16 constant index | 3 | → v | Push a constant |
| `nil` | 1 | — | 1 | → nil | Push nil |
| `string T` | 9 | u16 name index | 3 | → s | Build a string from interned text. A literal's bytes ride in the **names** table, because a string needs a VM to allocate it and the assembler has none |
| `symbol S` | 10 | u16 name index | 3 | → 'y | Intern text as a symbol |
| `block B` | 8 | u16 method index | 3 | → b | Make a block over that method, capturing the current frame as its home |

### Names and slots

| Mnemonic | Byte | Operands | Bytes | Stack | |
| --- | --- | --- | --- | --- | --- |
| `global N` | 2 | u16 name index | 3 | → v | Push the named global. A lookup, not a send |
| `setglob N` | 3 | u16 name index | 3 | v → v | Bind the name, **leaving the value** |
| `local S` | 4 | u8 slot | 2 | → v | Push a frame slot. Slot 0 is `self` in a block, unused in a script; 1..arity are the arguments |
| `setlocl S` | 5 | u8 slot | 2 | v → v | Store into a slot, leaving the value |
| `outer D, S` | 6 | u8 depth, u8 slot | 3 | → v | Read a slot `D` frames out along the **lexical** chain |
| `setoutr D, S` | 7 | u8 depth, u8 slot | 3 | v → v | Write one, leaving the value |
| `setslot N` | 12 | u16 name index | 3 | o v → v | Pop a value and an object, bind the name on the object, leave the value |

**All four assignments leave their value on the stack.** That is what makes
`c := b := #45` fall out for free; a statement boundary discards it with `pop`.

### Sending

| Mnemonic | Byte | Operands | Bytes | Stack | |
| --- | --- | --- | --- | --- | --- |
| `send N, argc` | 11 | u16 name index, u8 argc | 4 | r a₁..aₙ → v | Pop `argc` arguments and a receiver, send, push the reply |

The receiver goes on the stack **first**, then the arguments in order.

### Jumps

| Mnemonic | Byte | Operands | Bytes | Stack | |
| --- | --- | --- | --- | --- | --- |
| `jump L` | 13 | u16 offset | 3 | — | Skip **forward** |
| `jumpf L, S` | 14 | u16 offset, u16 name index | 5 | b → | Pop a boolean, skip forward when false |
| `exitf L` | 15 | u16 offset | 3 | b → | Pop what a condition answered, leave an inlined loop when false |
| `chkbool S` | 16 | u16 name index | 3 | b → b | Require a boolean on top, **leaving it there** |
| `loop L` | 17 | u16 offset | 3 | — | Jump **backward** |

Three carry a selector they never push, and it is there for one reason: **an
inlined message must complain exactly as the real send would.** `jumpf` names
the selector it stands in for, so a non-boolean reports the same *does not
understand*; `exitf` differs from it only in the complaint, since there the
boolean came out of a block; `chkbool` examines and leaves the value because
that value *is* an inlined `and`'s reply.

### Leaving

| Mnemonic | Byte | Operands | Bytes | Stack | |
| --- | --- | --- | --- | --- | --- |
| `pop` | 18 | — | 1 | v → | Discard the top. A statement boundary |
| `return` | 19 | — | 1 | v → | Return the top from the current method |
| `halt` | 20 | — | 1 | — | Stop the machine |

**A script has to end with `halt` and a block with `return`.** SolVM's verifier
accepts either at the end of any chunk; the assembler is stricter, because
those are what `solas` emits and a chunk ending the other way is almost always
a mistake.

---

## 6. Operands

| In an instruction | Written as |
| --- | --- |
| a **constant** | `#42`, `#-7`, `3.5`, `-1.25`, `#true`, `#false`, `#nil` |
| a **selector** or a **global name** | a name, or a text literal: `add`, `"return"` |
| the text a `string` builds | a text literal: `"hello, world"` |
| a **slot** | an integer, 0 to 255 |
| a **depth** | an integer, 0 to 255. 0 is this frame, 1 is the frame it was written in |
| an **argument count** | an integer, 0 to 255 |
| a **label** | a name |
| a **block** | the name a `.block` declared |

A `symbol` takes a selector-shaped operand: `symbol greeting` interns
`greeting`, with no leading quote — the `'` in Solveig's `'greeting` is source
syntax and does not reach the table.

---

## 7. The side tables

A chunk carries two, and which one a thing goes in is not a detail: **a name is
not a value.**

| | |
| --- | --- |
| **constants** | integers, floats, booleans and nil — values a `.sob` can carry whole |
| **names** | selectors, global names, slot names, and **the bytes of string literals**, because a string object needs a VM to allocate it |

Both **intern**, and both are per chunk: a block's tables are its own.

**An index is assigned where the text is first seen**, in the order the
assembler walks the program — which is the order it is written. That is worth
knowing for one reason: it is the same rule `solas` follows, so an assembly
program written in the same order as the Solveig it came from gets **the same
indices**, and `solvm --dump` of the two can be compared line for line.

Interning is by value. An integer `#1` and a float `1.0` do not share an entry:
the key includes the tag byte.

A chunk holds at most 65536 of each.

---

## 8. Jumps

**An offset is counted from the byte after the instruction**, and it is
**unsigned**.

```
target = address_of_label
here   = address_of_this_instruction

jump  L, jumpf L, exitf L    offset = target - (here + bytes)
loop  L                      offset = (here + bytes) - target
```

so `jump` and `jumpf` and `exitf` go forward and `loop` goes back, and **which
one a label needs is a fact about the program**. The assembler refuses a `jump`
whose target is behind it and a `loop` whose target is ahead, naming the other
mnemonic. An offset of 0 — a jump to the very next instruction — is legal and
accepted either way.

A jump cannot leave its chunk, and the verifier requires every one to land on
an **instruction boundary**. Since the assembler only ever resolves a label,
that holds by construction.

---

## 9. Blocks

A block is a nested chunk plus three numbers in the enclosing chunk's method
table.

**`block B` captures the running frame as the block's home**, which is what
makes `self` and the enclosing locals still mean the right thing whenever the
block is eventually run. `outer D, S` walks that chain: depth 1 is the frame
the block was written in, 2 is the one outside that.

### The flags, and the one the assembler works out

A method record carries `1` for *is a block* and `2` for *captures its home
frame*. The assembler sets the first always and the second **when this chunk's
own code contains an `outer` or a `setoutr`** — which is exactly what `solas`
does, and its comment says why a nested chunk is not consulted:

> a nested chunk is not consulted: its depths are counted from its own frame,
> so whether it reaches past this one is its business, recorded on its own flag

So you never write the flag, and you cannot get it wrong.

### A block cannot outlive its home frame

`block outlived the frame it was written in` is a **run-time** error, and no
flag prevents it. Frames live on the stack; a block that escapes the send that
made it and is called afterwards finds its home gone. That is SolVM's
behaviour, not the assembler's, and the assembler cannot see it coming.

---

## 10. What the assembler writes

The container, from `serialize.h`. Little-endian throughout.

```
header      "SOLB", u16 version, u16 script slot count (at least 1)
names       u32 count, then each: u16 length + bytes
constants   u32 count, then each: u8 tag + payload
                                  (0 nil, 1 i64, 2 f64, 3 bool as u8)
code        u32 length, then that many bytes
lines       u32 run count, then each: u32 run length + u32 line
files       u32 count, then each: u16 length + bytes
fileruns    u32 run count, then each: u32 run length + u32 file index
slotnames   u16 count, then each: u16 length + bytes
methods     u32 count, then each: u16 name length + bytes, u16 arity,
                                  u16 slot count, u16 flags, then that
                                  method's chunk, recursively
```

What this assembler puts in each:

| | |
| --- | --- |
| **lines** | one run per item, so a diagnostic from `solvm` names the line of **assembly** it came from. A label contributes a run of no bytes, which the loader accepts |
| **files** | one entry, the path the assembler was given, and one run covering the whole chunk |
| **slotnames** | none. SolVM prints `slot 3` rather than a name in a traceback; naming them is not yet expressible in this syntax |

### The version is an equality, not a floor

**A build reads exactly its own version and refuses every other, in both
directions.** Version 15 will refuse everything 14 wrote, and the whole
diagnosis is `unsupported bytecode version` — the file is not inspected
further, so nothing else about it is reported.

The version is written into `solvm-sob.phx`, and `languages/solvm/tests/run.sh`
checks it against `SOL_SOB_VERSION` whenever a Solveig checkout is to hand.
After a bump: change the one number, then `REGOLD=1 languages/solvm/tests/run.sh`.

### And it cannot read one back

**Phoenix can emit `.sob` and cannot parse it.** The format is length-prefixed
— a count, then that many things — so reading one needs the match to depend on
a number it has just read, and there is no computed repetition in the notation.
That is a limit of the meta-language rather than of this description, and it is
why `solvm --dump` is the only disassembler.

---

## 11. Every diagnostic

Each names a line and a column of assembly, with a caret.

### About an instruction

| | |
| --- | --- |
| `no label called 'x'` | a `jump`, `jumpf`, `exitf` or `loop` naming nothing |
| `'x' is behind this, and a backward jump is` `loop` | on `jump`, `jumpf`, `exitf` |
| `'x' is ahead of this, and a forward jump is` `jump` | on `loop` |
| `no block called 'x' is defined in this chunk` | on `block` |
| `a slot has to fit one byte, and n does not` | `local`, `setlocl`, `outer`, `setoutr` |
| `a depth has to fit one byte, and n does not` | `outer`, `setoutr` |
| `an argument count has to fit one byte, and n does not` | `send` |
| `no constant is spelled 'x' -- they are #true, #false and #nil` | a fourth `#word` |
| `a doubled backslash in a text literal is not supported` | in any text operand |

### About a chunk

| | |
| --- | --- |
| `there is nothing here to assemble` | an empty script |
| `the script has to end with halt` | and a block, with `return` |
| `a block needs at least one instruction` | |
| `the script is n bytes, and a jump offset is two bytes` | over 65535 |
| `two blocks in the script have the same name` | or `two blocks in 'b' …` |
| `a chunk holds at most 65536 names` | and at most 65536 constants |

### About a frame

| | |
| --- | --- |
| `a frame has at least one slot, for the receiver` | `.slots 0` |
| `a frame reserves at most 255 slots, and this asks for n` | |
| `a block takes at most 255 arguments, and 'b' declares n` | |
| `a block reserves at most 255 slots, and 'b' asks for n` | |
| `'b' takes n arguments, so it needs at least n+1 slots -- the receiver is slot 0` | |
| `'b' is nested n deep, and SolVM follows at most 16 frames` | |
| `slot n is past this frame, which has m` | `local`, `setlocl` |
| `two labels in the script have the same name` | or `two labels in 'b' …` |

---

## 12. What the assembler does not check

**The stack.** SolVM's verifier refuses a chunk where *two paths reach one
instruction with different stack depths*, and computing that means following
control flow rather than walking a tree — which is not something a pass can do.
So a program whose branches leave different numbers of values behind assembles
cleanly and is refused at **load**:

```
solvm: cannot load 'x.sob': bytecode is internally inconsistent
       -- an instruction takes more from the stack than is on it
```

The verifier's other conditions are checked here, or hold by construction:

| Verifier condition | |
| --- | --- |
| every instruction fits inside the chunk | by construction |
| every operand indexes something that exists | by construction — indices come from the tables |
| every jump lands on an instruction boundary | by construction — offsets come from labels |
| every `local`/`setlocl` addresses a slot the frame has | checked, against the frame this chunk declared |
| the last instruction stops the machine | checked, and more strictly |
| a method has at least `arity + 1` slots | checked |
| nesting is at most 16 frames | checked |

**And nothing checks what a program means.** A `send` to a receiver that does
not understand it, an arity mismatch on `value`, a block that outlives its home
frame: all of those are run-time, and SolVM reports them with the line of
assembly they came from.
