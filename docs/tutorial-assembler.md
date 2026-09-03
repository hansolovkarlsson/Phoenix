# Tutorial: two passes, and a forward reference

*The second tutorial. It assumes [tutorial-picture.md](tutorial-picture.md) —
the lexical half, `->`, a pass, a driver — and is about the mechanism that one
did not need: **what to do when a node's answer depends on something further
down the file.***

Every command and every piece of output on this page was run exactly as written.

The subject is an assembler for a tiny stack machine:

```
# add two numbers and print the answer, unless it is zero
    push 3
    push 4
    add
    jz  done
    print
done:
    halt
```

Save that as `sum.asm`. `jz done` names a label that appears **four
instructions later**, which is the whole point: a pass is one walk over the
tree, and nothing in a walk can look ahead.

---

## 1. The grammar

Nothing new. Create `asm.phx`:

```ebnf
%fragment letter digit .

letter  = "a" .. "z" .
digit   = "0" .. "9" .

word    = letter { letter | digit } .
number  = digit { digit } .
space   = ( " " | "\t" | "\n" ) { " " | "\t" | "\n" } .
comment = "#" { ! "\n" } .
symbol  = ":" .

%skip space comment .

%syntax .
%start program .

program = { item } -> Program(items: $1) .

item = n:word ":"       -> Label(name: $n)
     | "push" v:number  -> Push(value: $v)
     | "jz"   t:word    -> Jz(target: $t)
     | "jmp"  t:word    -> Jmp(target: $t)
     | "add"            -> Add
     | "print"          -> Print
     | "halt"           -> Halt .
```

Two small things worth noticing.

**`Label` comes first, and it has to.** Alternatives are **ordered choice**:
`a | b` tries `a`, and tries `b` only if `a` failed. `n:word ":"` fails on
`push` because there is no colon after it, and the parser moves on — but were
the alternatives the other way round, `done:` would match nothing.

**A node with no fields is written bare** — `-> Add`, no parentheses. A capital
starts a node type and a lower-case letter starts a function call, which is what
lets `Halt` be a node and `empty` be a call with no arguments.

```sh
$ phx --tree asm.phx sum.asm
Program
`- items: [7]
   |- Push
   |  `- value: "3"
   |- Push
   |  `- value: "4"
   |- Add
   |- Jz
   |  `- target: "done"
   |- Print
   |- Label
   |  `- name: "done"
   `- Halt
```

`push`, `jz`, `add` and the rest became reserved words by being written as
literals in the syntactic half, so a program cannot have a label called `add:`.
Nothing declared that.

## 2. The attempt that does not work

The obvious thing is one pass that counts addresses, collects the labels it
passes, and writes the jumps out. Try it:

```
%pass assemble
  thread pc = 0

  Push : pc = $pc + 2 .
  Jz   : pc = $pc + 2 .
  Jmp  : pc = $pc + 2 .
  otherwise pc = $pc + 1

  Label : entry = [[$name, $pc]] .
  otherwise entry = []

  Program : labels = flatten($items.entry)
          : down table = $labels
          : out = join($items.out, "\n") .
```

```sh
$ phx asm.phx sum.asm
asm.phx:39:11: error: this reads 'labels', which this rule computes on the way out -- and an inherited clause runs on the way in
            : down table = $labels
            ^
phx: write the expression out here, or compute 'labels' in an earlier pass
```

**That is the whole lesson of this tutorial, and Phoenix says it before any
program is read.** A pass is one walk with two phases at each node:

| | |
| --- | --- |
| `: down attr = e` | **entering**, before the children, and visible to everything below |
| `: attr = e` | **leaving**, after the children |

Gathering the labels happens on the way *up*. Handing the table to the jumps
happens on the way *down*. One walk cannot do both, and no amount of rearranging
the clauses changes that. So it is two passes — which is exactly why
`languages/pascal/pascal.phx` has a `symbols` pass and a `typecheck` pass rather
than one.

## 3. Pass one: where does everything sit?

```
%pass layout
  thread pc = 0

  Push : pc = $pc + 2 .
  Jz   : pc = $pc + 2 .
  Jmp  : pc = $pc + 2 .
  otherwise pc = $pc + 1

  Label : entry = [[$name, $pc]] .
  otherwise entry = []

  Program : labels = flatten($items.entry) .
```

Three mechanisms, and each is doing something a hand-written assembler spends a
loop and a variable on.

**`thread pc = 0` is a fold over the tree in document order.** A threaded
attribute is computed on leaving a node, like an ordinary synthesised one, and
then *flows on to whatever the walk visits next*. So `$pc` inside a clause is
the address this node sits at, and what the clause answers is the address the
next one sits at. It is declared before the clauses that update it, so that a
clause naming it is recognisably an update.

**`otherwise` is what a node answers when its own rule says nothing.**
`otherwise pc = $pc + 1` is the one-byte instructions — `Add`, `Print`, `Halt`
— and, importantly, `Label` and `Program`, which take no space at all and must
still pass the counter along. Without it that line would be written five times.
`otherwise` runs *after* a node's own clauses and only for the attributes they
left alone.

**`flatten` is why `entry` is a list of one rather than a pair.** There is no
filter and no conditional in the notation, so a node that has nothing to
contribute contributes `[]`, and one level of flattening drops them. What comes
out is an association list — a list of `[name, value]` pairs — which is the
shape `lookup` and `bind` work on.

Look at it:

```sh
$ phx --run layout --show labels asm.phx sum.asm
phx: a list has no written form -- a pass that wants one says what it is
[1]
`- [2]
   |- "done"
   `- 8
```

`--run` runs one pass on its own and `--show` prints one attribute of the root,
which together are how you look at a pass while writing it. The complaint on the
first line is the notation refusing to invent a rendering for a list, and it
prints the structure anyway.

Eight is right: two `push`es at two bytes each, an `add` at one, a `jz` at two,
a `print` at one.

## 4. Pass two: hand the table back down

```
%pass listing
  Program : down table = $labels
          : out = join($items.out, "\n") .

  Label : out = "{}:" of $name .
  Push  : out = "    push {}" of $value .
  Add   : out = "    add" .
  Print : out = "    print" .
  Halt  : out = "    halt" .

  Jz : out = "    jz {}" of lookup($table, $target)
     ! not defined($table, $target) : "no label called '{}'" of $target .
  Jmp : out = "    jmp {}" of lookup($table, $target)
      ! not defined($table, $target) : "no label called '{}'" of $target .

%driver listing = layout, listing -> out .
```

`$labels` is readable here because **attributes stay on the nodes between
passes**. `layout` put it on `Program`; `listing` hands it down as `table`, and
every node below can see it. The forward reference is answered by there having
been an earlier walk, and by nothing else.

```sh
$ phx asm.phx sum.asm
    push 3
    push 4
    add
    jz 8
    print
done:
    halt
```

And the check earns its place the first time somebody mistypes a label. Put
`jz nowhere` and `halt` in `bad.asm`:

```sh
$ phx asm.phx bad.asm
bad.asm:1:5: error: no label called 'nowhere'
      jz nowhere
      ^
```

A check runs **before** the attributes it guards, which is why it can say
something useful instead of `lookup` quietly answering `nil` and a `nil` turning
up in the output.

### The order is a claim, and it is checked

Take `layout` out of the driver and see what happens:

```sh
$ phx asm.phx sum.asm
asm.phx:64:27: error: nothing here is called 'labels' -- not a binding, a field of Program, an attribute of it, a threaded attribute, one handed down, or a file this description embeds
    Program : down table = $labels
                            ^
```

A driver reading a *child's* attribute that nothing before it defines gets an
even more direct message, naming the driver and the pass that would have
supplied it:

```
error: driver 'bad' runs 'typecheck', which reads '.show', and nothing before
       it defines one
phx: 'show' defines 'show' -- did the driver mean to run it first?
```

**That message is the reason to declare a driver** rather than to run passes in
whatever order they were typed. The alternative is a complaint from inside a
pass about a missing attribute, naming neither the driver that got the order
wrong nor the pass that would have fixed it.

## 5. The same tree, as bytes

A target need not be text. `bytes(n, width)` writes an integer as that many
bytes, least significant first — one to eight — and it is the one thing in the
library that cannot be written in the notation, because there is no way to take
a value apart with arithmetic that answers integers and text that answers
characters.

```
%pass emit-code
  Program : down table = $labels
          : out = join($items.out) .

  Label : out = "" .
  Push  : out = join([bytes(1, 1), bytes(int($value), 1)]) .
  Add   : out = bytes(2, 1) .
  Print : out = bytes(3, 1) .
  Halt  : out = bytes(4, 1) .

  Jz  : out = join([bytes(5, 1), bytes(lookup($table, $target), 1)])
      ! not defined($table, $target) : "no label called '{}'" of $target .
  Jmp : out = join([bytes(6, 1), bytes(lookup($table, $target), 1)])
      ! not defined($table, $target) : "no label called '{}'" of $target .

%driver code = layout, emit-code -> out .
```

`int($value)` because `$value` is the **text** the number rule matched, and
nothing in this notation converts implicitly.

`--raw` writes the answer exactly, adding no trailing newline — which is what a
description emitting a binary format needs:

```sh
$ phx --driver code --raw asm.phx sum.asm > sum.bin
$ xxd sum.bin
00000000: 0103 0104 0205 0803 04                   .........
```

Nine bytes, and the `05 08` in the middle is the jump, resolved to the address
pass one worked out.

`bytes` also takes a **list** of numbers and answers a list of encodings, which
is what a column of a table in a binary format is:

```
Program : lines = join(bytes($items.pos.line, 2)) .
```

```sh
$ phx --driver lt --raw asm.phx sum.asm | xxd
00000000: 0200 0300 0400 0500 0600 0700 0800       ..............
```

`$items.pos.line` is the line each instruction came from — `.` over a list means
*that of each*, and `$pos` answers a node
(`Position(line, column, file, endline, endcolumn)`) whose fields are read like
any other. **A node is a stretch of source and not a point**, which matters
wherever something is emitted after the things it is about: the line a jump's
own bytes belong to is where its operand *ends*.

That one clause is a line-number table.

**And this whole tutorial exists at full size.**
[`languages/solvm/`](../languages/solvm/) is an assembler for that same
bytecode — 21 mnemonics, labels, and blocks that nest — built out of exactly
the two passes above: a threaded byte counter and a gathered label table,
plus `down` on a *threaded* attribute where a block restarts its chunk's
tables. It assembles the loop-and-conditional listing printed in SolVM's own
documentation to that listing exactly, offset for offset.
[`languages/solveig/solveig-sob.phx`](../languages/solveig/solveig-sob.phx) is
the harder direction: a whole language down to the same format.

## 6. Writing it out, and what that proves

```sh
$ phx asm.phx -o asmc.c
$ cc asmc.c -o asmc
$ ./asmc --driver code --raw sum.asm > sum2.bin
$ cmp sum.bin sum2.bin && echo "byte for byte identical"
byte for byte identical
```

The generated compiler takes the same options as `phx` does, because it *is*
`phx`'s machinery with your description frozen into it.

**That comparison is not a formality.** The version of this test that compared
only text passed for months while a description emitting bytes had never been
written out as a compiler at all — so nothing noticed that a literal holding a
NUL was frozen with `strlen` and arrived short, while the length beside it still
said otherwise. "There is only one implementation" is a claim about the code;
that it holds is a claim about the tests, and it is only as strong as the widest
thing they compare.

---

## What you now know

| | |
| --- | --- |
| `thread` | a fold over the tree in document order — counters, offsets, symbol tables |
| `down` | an inherited attribute: computed entering, visible below |
| `otherwise` | what a node answers when its own rule says nothing |
| two passes | because gathering runs on the way up and handing down runs on the way in |
| `! cond : message` | a check, which runs before the attributes it guards |
| `flatten`, `lookup`, `defined`, `bytes` | the library entries this needed |

## What is left

**Nesting a thread.** A thread runs in one chain along the whole walk, which is
right for anything the program has one of and wrong for anything a scope has its
own of. A `down` clause naming a *threaded* attribute sets the thread for the
subtree instead, so the save is an ordinary `down` attribute and the restore is
the node's own leaving clause:

```
Block : down held  = $names       (* save the enclosing table   *)
      : down names = []           (* start this scope's own     *)
      ...                         (* the children fill it in    *)
      : names      = $held .      (* and the enclosing one back *)
```

**`%rewrite`.** A pass decorates; a rewrite replaces a node with a different
one. See [reference.md § 7](reference.md#7-rewrites) and
[`tests/grammars/fold.phx`](../tests/grammars/fold.phx), which is a constant
folder in six lines and shows why the traversal strategy has to be said out
loud.

**`%embed` and `%include`.** A backend that emits a language needs that
language's runtime, and a description has nowhere to put one:
[`languages/awk/awk-c.phx`](../languages/awk/awk-c.phx) embeds seven hundred
lines of C. And a *source* language with its own imports needs a reader-level
mechanism, because a pass walks a tree that has already been read:
[`languages/solveig/solveig.phx`](../languages/solveig/solveig.phx) declares one
in two lines.

| | |
| --- | --- |
| [manual.md](manual.md) | the whole notation, explained in order |
| [reference.md](reference.md) | every directive, clause form and library function |
| [semantics.md](semantics.md) | what the meta-language's own arithmetic means, executably |
