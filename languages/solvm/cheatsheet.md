# SolVM assembly cheatsheet

*One page. [manual.md](manual.md) explains, [reference.md](reference.md) is
exhaustive.*

```sh
phx --raw          languages/solvm/solvm-sob.phx p.sasm > p.sob   # assemble
phx --driver check languages/solvm/solvm-sob.phx p.sasm           # just check
phx --driver render languages/solvm/solvm.phx    p.sasm           # write it back out
solvm --dump p.sob                                                # what came out
solvm p.sob                                                       # run it
```

`--raw` is required: a `.sob` is bytes and must not gain a trailing newline.

## The shape of a file

```
; a comment, to the end of the line
.slots 2                        ; the script's frame. 1..255, default 1

        const   #45
        setglob answer
        pop
top:                            ; a label names the next instruction
        global  answer
        send    display, 0
        pop
        halt                    ; a script ends with halt

.block name arity 1 slots 2     ; a nested chunk; occupies no space here
        local   1
        return                  ; a block ends with return
.end
```

## Instructions

`Stack` is *before* → *after*, top on the right.

| | Byte | Bytes | Stack | |
| --- | --- | --- | --- | --- |
| `const K` | 0 | 3 | → v | push a constant |
| `nil` | 1 | 1 | → nil | push nil |
| `global N` | 2 | 3 | → v | look up a global |
| `setglob N` | 3 | 3 | v → v | bind it, **leaving the value** |
| `local S` | 4 | 2 | → v | slot of this frame |
| `setlocl S` | 5 | 2 | v → v | store, leaving the value |
| `outer D, S` | 6 | 3 | → v | slot `D` frames out |
| `setoutr D, S` | 7 | 3 | v → v | store, leaving the value |
| `block B` | 8 | 3 | → b | make a block, capturing this frame |
| `string T` | 9 | 3 | → s | build a string from interned text |
| `symbol S` | 10 | 3 | → 'y | intern text as a symbol |
| `send N, argc` | 11 | 4 | r a₁..aₙ → v | receiver first, then arguments |
| `setslot N` | 12 | 3 | o v → v | bind a name on an object |
| `jump L` | 13 | 3 | — | forward |
| `jumpf L, sel` | 14 | 5 | b → | pop a boolean, go when false |
| `exitf L` | 15 | 3 | b → | leave an inlined loop when false |
| `chkbool sel` | 16 | 3 | b → b | require a boolean, **leaving it** |
| `loop L` | 17 | 3 | — | backward |
| `pop` | 18 | 1 | v → | discard — a statement boundary |
| `return` | 19 | 1 | v → | answer from this chunk |
| `halt` | 20 | 1 | — | stop |

**Everything is a send.** No arithmetic instruction, no conditional
instruction. `global` is the one lookup.

## Operands

| | |
| --- | --- |
| constant | `#42` `#-7` `3.5` `-1.25` `#true` `#false` `#nil` |
| selector, global, string | a name, or a text literal: `add`, `"return"`, `"hi"` |
| slot, depth, argc | `0`–`255`. Depth 0 is this frame, 1 is the frame it was written in |
| label, block | a name |

Text escapes: `\n` `\t` `\r` `\"`. A doubled backslash is refused.

## Jumps

Offsets count from **the byte after the instruction**, and are **unsigned**.

```
jump / jumpf / exitf   offset = target - (here + bytes)     forward only
loop                   offset = (here + bytes) - target     backward only
```

The assembler refuses the wrong direction and names the other mnemonic. A jump
cannot leave its chunk.

## Frames

> **Slot 0 is the receiver** — `self` in a block, unused in a script. Then the
> arguments, then locals.

`slots` is the whole frame: at least `arity + 1`, at most 255. Nesting is at
most 16 frames deep. **`local` is not checked against `slots`** — a slot past
the end is a load error.

## The six inlined constructs

The shapes `solas` emits. Anything else written as a message is a plain `send`.

| `c:ifTrue({b})` | `c:ifFalse({b})` | `c:ifElse({a},{b})` |
| --- | --- | --- |
| <pre>    &lt;c&gt;<br>    jumpf  else, ifTrue<br>    &lt;b&gt;<br>    jump   end<br>else:<br>    nil<br>end:</pre> | <pre>    &lt;c&gt;<br>    jumpf  body, ifFalse<br>    nil<br>    jump   end<br>body:<br>    &lt;b&gt;<br>end:</pre> | <pre>    &lt;c&gt;<br>    jumpf  two, ifElse<br>    &lt;a&gt;<br>    jump   end<br>two:<br>    &lt;b&gt;<br>end:</pre> |

| `{c}:whileTrue({b})` | `c:and({b})` | `c:or({b})` |
| --- | --- | --- |
| <pre>top:<br>    &lt;c&gt;<br>    exitf  done<br>    &lt;b&gt;<br>    pop<br>    loop   top<br>done:<br>    nil</pre> | <pre>    &lt;c&gt;<br>    jumpf  short, and<br>    &lt;b&gt;<br>    chkbool and<br>    jump   done<br>short:<br>    const  #false<br>done:</pre> | <pre>    &lt;c&gt;<br>    jumpf  long, or<br>    const  #true<br>    jump   done<br>long:<br>    &lt;b&gt;<br>    chkbool or<br>done:</pre> |

The condition of a `whileTrue` goes **inside** the loop. The selector on
`jumpf`/`exitf`/`chkbool` is the message it stands in for, and the only thing
it affects is the complaint a non-boolean makes.

## Reserved words

Every mnemonic, plus `arity` and `slots`:

```
const  nil  global  setglob  local  setlocl  outer  setoutr  block  string
symbol  send  setslot  jump  jumpf  exitf  chkbool  loop  pop  return  halt
arity  slots
```

A colliding selector or name goes in quotes: `send "return", 0`.
`true` and `false` are **not** reserved — that is why the constants are
`#true`/`#false`/`#nil`, so `global true` still works.

## The two tables

| | |
| --- | --- |
| **constants** | integers, floats, booleans, nil — values the file carries whole |
| **names** | selectors, globals, **and the bytes of every string literal**, because a string needs a VM to allocate it |

Both intern per chunk, and **an index is assigned where the text is first
seen** — the same rule `solas` follows, which is why two producers of one
program can be compared line for line.

## What is checked, and what is not

**Checked:** an unknown label · a jump in the wrong direction · a slot, depth
or argc over 255 · an unknown block · two blocks of one name · a script not
ending in `halt`, a block not in `return` · `slots < arity + 1` · nesting over
16 · a chunk over 65535 bytes.

**Not checked — the verifier's, at load:**

```
an instruction takes more from the stack than is on it
two paths reach one instruction with different stack depths
```

Which is dataflow rather than a tree walk. So: an expression leaves one value,
a statement is an expression plus `pop`, both arms of a branch leave the same
number, and a chunk ends with one value.

**Not checked at all — run-time:** a receiver that does not understand the
message, an arity mismatch, and a block that outlives its home frame.

## The format version is an equality

A build reads exactly its own and refuses every other **in both directions**;
the whole diagnosis is `unsupported bytecode version`. After a bump: change the
one number in `solvm-sob.phx`, then `REGOLD=1 languages/solvm/tests/run.sh`.
