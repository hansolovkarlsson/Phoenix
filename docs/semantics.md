# What Phoenix's own expressions mean

*The meta-language has values and does arithmetic on them. This page says
exactly what that arithmetic is, in Phoenix's terms and not in any host's.*

**Why this page exists.** As long as Solveig is the only backend, `+` can
quietly mean whatever Solveig's `add` means and nothing breaks. The moment a
second backend exists, every ambiguity here becomes a divergence between two
generated compilers — the worst place in the system to find one, because the
symptom appears in somebody else's program. So the semantics are fixed here,
and a backend that cannot honour them is wrong.

**The conformance rule, which is what this page is for:**

> The same `.phx`, run through `--run` and through every backend, produces
> identical output. A backend disagreeing with this page is a defect in the
> backend.

**And this page is executable.**
[`tests/grammars/semantics.phx`](../tests/grammars/semantics.phx) is every
claim below as a check, in the order they are made, and
[`semantics-refused.phx`](../tests/grammars/semantics-refused.phx) is every
refusal. Both are run by `make test`, through `phx` *and* through a compiler
`phx` wrote — which has to produce the same complaints byte for byte, since
that is what the rule above says.

A check that fires names the sentence it came from. Editing a claim here
without editing `eval.c` fails the suite, and so does the reverse, which is
what "the two are changed together or not at all" has to mean if it is to mean
anything.

---

## The most important thing on this page

**Phoenix's arithmetic is not the target language's arithmetic, and a pass that
folds target constants must say so.**

A pass that computes `2 + 2` while compiling Pascal is doing Phoenix's
arithmetic. If it folds a Pascal `maxint + 1`, the answer must be Pascal's — and
Pascal's integers trap where another language's would wrap. Silently using
Phoenix's rules gives a compiled program that disagrees with the same program
interpreted, which is the classic constant-folding bug and it is very hard to
find.

Phoenix will not guess. Its arithmetic is for the compiler's own bookkeeping —
counters, offsets, sizes, table indices. A pass that models a target's
arithmetic writes that model out.

---

## Values

Six kinds, and no others.

| | |
| --- | --- |
| **integer** | 64-bit, signed, two's complement |
| **float** | IEEE 754 binary64 |
| **text** | a sequence of bytes |
| **boolean** | `true`, `false` |
| **nil** | one value meaning absence |
| **node** and **list** | as stage 1 builds them |

`45` is an **integer** and `45.0` is a **float**. *(Solveig writes these `#45`
and `45`. Phoenix does not follow it: the unmarked number being a float is a
choice Solveig made for reasons of its own, and a compiler description mostly
counts things.)*

## No implicit conversion, anywhere

`1 + 1.0` is an error, not `2.0`. `int(x)` and `float(x)` convert, and are the
only things that do.

This is the single rule that most protects the conformance rule above: implicit
conversion is where host languages differ from one another most, and most
quietly.

`float(x)` on an integer above 2^53 loses precision and says so. `int(x)` on a
float is refused — narrowing has a direction, so it is `floor`, `ceiling`,
`round` or `truncate`, named.

## Integers

**Overflow is an error, not a wrap.** A wrapped label counter or a wrapped
structure offset is a bug that emits wrong code silently, and this is a tool
whose output is other programs. Every backend checks; the error names the
position in the `.phx` that computed it.

**Division and modulo are floored**, so that `a mod b` always carries the sign
of `b` — which is what makes `x mod n` an index into `n` things without a
correction:

```
 7 div  2 =  3       7 mod  2 =  1
-7 div  2 = -4      -7 mod  2 =  1
 7 div -2 = -4       7 mod -2 = -1
-7 div -2 =  3      -7 mod -2 = -1
```

The identity `(a div b) * b + (a mod b) = a` holds for every pair. *(C
truncates instead, so a C backend must emit the correction rather than the bare
`/`. That is the backend's problem, which is the point of writing it down.)*

**Division by zero is an error.** So is `div` or `mod` by zero, and so is
negating the most negative integer.

## Floats

Plain IEEE 754 binary64, with its rules and not Phoenix's: division by zero
gives an infinity, `0.0/0.0` gives a nan, and a nan compares unequal to
everything including itself.

Floats do **not** trap. That asymmetry with integers is deliberate: IEEE
already defines an answer for every case, and inventing a different one would
put Phoenix at odds with every host's hardware.

## Text

**Bytes, not characters.** `size` counts bytes, indices are byte offsets, and
UTF-8 passes through untouched. Comparison is bytewise, which orders ASCII the
familiar way and orders everything else by its encoding.

Case operations are **ASCII only** — the 26 letters, nothing else touched. A
tool that case-folded Turkish correctly in one backend and not another would
break the conformance rule for no benefit any compiler description has asked
for.

**Indices are one-based**, and a range includes both ends. This follows Solveig,
and the reason is not consistency with Solveig: off-by-one in a tool that emits
code is expensive, and one-based inclusive is the convention the grammar half
already uses when it reports a column.

## Comparison

`=` and `<>` work on **any** two values and compare **structurally**: two lists
are equal when their elements are, two nodes when their type, fields and values
are. Values of different kinds are unequal rather than an error, so a guard may
ask `$x = nil` without knowing what `$x` is.

`< > <= >=` work only **within** a kind — integer with integer, float with
float, text with text. Across kinds they are an error, because there is no
order anyone would agree on.

There is no identity comparison. Two structurally equal values are
interchangeable, and a backend is free to share them.

## Booleans

`and` and `or` **short-circuit**, left to right. `not` takes a boolean.

There is no truthiness: a condition must be a boolean, and `if 0` would be an
error if there were an `if`. Nothing else converts to a boolean.

## nil

One value, meaning absence. `lookup` answers it when a name is not bound.

`nil` is not zero, not empty text and not `false`; it equals only itself.
Arithmetic on it is an error rather than a silent zero — a nil arriving where a
number was expected is a bug in a pass, and the whole value of finding it is
finding it at the node that produced it.

## Evaluation order

**Left to right, everywhere**, and the operands of an operator are evaluated
before it. Fixed because two backends evaluating in different orders would
report two different first errors on the same input.

Precedence, tightest first:

```
f(x)  $a.b                  call, attribute
not  -                      unary
*  /  div  mod              
+  -                        
=  <>  <  >  <=  >=         
and                         
or                          
of                          formatting, loosest
```

## Formatting

`"text {} {}" of a, b` fills the holes left to right. `{{` and `}}` are literal
braces. Too few or too many arguments is an error, checked when the grammar is
read rather than when the pass runs.

How each value writes itself:

| | |
| --- | --- |
| integer | decimal digits, `-` when negative, never `+`, no padding |
| float | the **shortest decimal that reads back as the same value** — so `0.1` is `0.1` and not `0.1000000000000000055` |
| text | itself, unquoted |
| boolean | `true` or `false` |
| nil | an error |
| node, list | an error |

The last two are deliberate. A default rendering for a node is a thing that
would silently appear in generated code, and a pass that wants one says what it
is.

## Lists

`[a, b]` builds one; `...x` inside a list spreads it. **`...` of anything that
is not a list is an error**, because the likeliest way to write one is
miscounting an item — `[$e, ...$3]` where `$3` is the third item rather than
the repetition builds the first element twice, and nothing downstream can tell.

## Where a node came from

`$pos` answers a node, and reading part of it is an ordinary field read:

```
Position(line, column, file, endline, endcolumn)
```

**A node is a stretch of source and not a point**, so it says where it ends as
well as where it starts. That matters wherever something is emitted after the
things it is about: a send's own bytes go in after its arguments, so the line
they belong to is `endline`.

`line` and `column` count from one; `file` is the file that stretch of source
came from, which after an `@include` is not necessarily the file the command
line named. It is the one name in a pass that is not a field, an attribute or a
binding: it resolves **before** all of those, so that it means the same thing
in every clause of every pass, and a description with a field or an attribute
of that name is refused when it is read.

`.` over a list already means "that of each", so `$body.pos.line` is a column
of line numbers — which is what a table in a binary format is written out of.

## Patterns

A pattern tests and binds at once, and there is one for every kind a value can
be:

| | |
| --- | --- |
| `Binary`, `Binary(op: "+")` | a node of that type; a field written with a value tests it, with a name binds it, left out is not looked at |
| `[ a, b ]`, `[]` | a list of **exactly** that many, each element matching |
| `"text"`, `45`, `true`, `nil` | that value |
| `name` | anything, bound to that name |
| `_` | anything |

Rules are tried **in order and the first match wins**, in a pass and in a
rewrite alike — which is why a general pattern above a specific one is refused
rather than silently taking every case the specific one was for.

## Rewriting

A `%pass` works out attributes and leaves the tree as it is. A `%rewrite`
replaces a node with what its `=>` builds:

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(text: a), right: Number(text: b))
    => Number(text: text(int($a) + int($b))) .
```

It sees what its pattern bound, `$pos`, and the fields of the node it matched —
and nothing a pass worked out, because it runs to change the tree rather than
to answer about one. The built node takes the position of the node it replaces,
so a later diagnostic points at the program rather than at the rule.

| | |
| --- | --- |
| `bottomup` | children first, then this node, once |
| `topdown` | this node first, then the children of whatever it became |
| `innermost` | bottom-up, and again on the result until nothing matches |

`innermost` is the only one that can fail to settle, and it stops with a
message rather than running forever.

## Attributes, and when each one runs

One walk, post-order, two phases at each node:

| | |
| --- | --- |
| `down attr = e` | entering, before the children, visible below this node |
| `attr = e` | leaving, after the children |
| `thread attr = e` | leaving, and the value flows on to what the walk visits next |

Which is why a `down` clause cannot read an attribute its own rule computes,
and a check — which runs before the attributes it guards — cannot read those
either. Both are refused when the description is read.

### `otherwise`

```
otherwise type = "void"
```

What a node answers with when the rule it matched has no clause for that
attribute — including a node that matched no rule at all. It runs **after** the
node's own clauses, so it can read what they worked out, and it may name a
threaded attribute, in which case it updates the thread the same way a clause
would.

A node with a *field* of that name reads the field, since `.name` reads a field
before an attribute. That is the node saying so itself, which is what this is
"otherwise" to.

`down` is refused: what a node hands its children is not what it answers with,
and every node hands one down already.

### `down` on a threaded attribute

A `down` clause naming a **threaded** attribute sets the thread for the
subtree rather than binding a name over it, and that is what makes a thread
nest. A thread otherwise runs in one chain along the whole walk, which is
right for anything the program has one of and wrong for anything a scope has
its own of.

The save is an ordinary `down` attribute and the restore is the node's own
leaving clause, which works because a node's scope is torn down *after* its
leaving clauses run:

```
Block : down held  = $names       (* save the enclosing table   *)
      : down names = []           (* start this scope's own     *)
      ...                         (* the children fill it in    *)
      : names      = $held .      (* and the enclosing one back *)
```

A rule that resets a thread and does not restore it lets the inner value flow
on to its siblings, which is legal and is occasionally what is wanted — a slot
counter that only ever grows, say.

---

## What a backend has to provide

The runtime beneath generated code, in whatever language it is written in:

- the six value kinds, with structural equality
- checked integer arithmetic with the floored division above
- byte text, one-based, with the ASCII case operations
- lists and the mapping used by `bind` and `lookup`
- the PEG matcher and longest-match scanner, driven by tables
- the shortest-round-trip float formatting

Everything else in a generated compiler comes from the `.phx` file.
