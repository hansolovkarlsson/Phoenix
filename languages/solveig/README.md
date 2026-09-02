# Solveig

[Solveig](https://github.com/hansolovkarlsson/Solveig) is a prototype-based
language in which everything is an object and everything that happens is a
message send. Its compiler `solas` produces `.sob` bytecode for the `solvm`
virtual machine.

**What is here so far is the conformance suite**, and that is deliberate: the
target exists before anything aims at it.

## The conformance suite

[`tests/conformance/`](tests/conformance/) holds programs and the output each
must produce. It is **a suite for the language rather than for one
implementation of it** — Solveig's own `tests/*.c` check the internals of
`solas` and `solvm`, which is a different job. These programs can be handed to
anything claiming to compile Solveig.

```sh
tests/conformance/run.sh            all of them
tests/conformance/run.sh arrays     one of them
tests/conformance/run.sh --accept   write what the compiler produces
```

**The expectations record what `solas` and `solvm` do, read against
`docs/CHEATSHEET.md` and `docs/REFERENCE.md` rather than taken on trust.** Where
the two disagree that is a finding, not a fixture. Each program asserts
something the documentation claims the language *is*:

| | |
| --- | --- |
| `integers` | arithmetic that traps rather than wraps, division that floors so `#-7:div(#2)` is `#-4`, and a remainder whose sign follows the divisor |
| `floats` | the unmarked number is the float; dividing by zero answers `infinity` rather than failing |
| `narrowing` | the whole reason there is no `asInteger` on a float — four operations, and a name that did not say which would be choosing one silently |
| `strings` | bytes and not characters, so `"café":size` is `#5`; one-based and both ends included |
| `arrays` | one-based, `add` answers the array so it chains, `join` is strict about strings |
| `dictionaries` | `at` fails on a missing key and `at(key, default)` does not |
| `blocks` | `whileTrue`, `doUntil` which runs its body first, `onError`, `ensure` |
| `control` | there is no `if`: these are messages taking blocks |
| `objects` | `new`, `via` where another language has `super`, and reflection that reads and never writes |
| `strictness` | no implicit conversion anywhere, with `equals` the one exception; and a message wanting a block says so when it is *sent* |
| `boundaries` | both ends included, one-based throughout, `first`/`last` clamping where `at` does not, `indexOf` answering `nil` and not `#0` |
| `iteration` | how many times, exactly — a `loop` inclusive at its end, a `doUntil` that runs its body first, and every zero case |

### Why `narrowing` is its own program

There is no `asInteger` on a float because there are four answers:

| | 1.5 | −1.5 | 2.5 | −2.5 |
| --- | --- | --- | --- | --- |
| `truncated` | 1 | **−1** | 2 | −2 |
| `rounded` | 2 | −2 | **3** | **−3** |
| `floor` | 1 | **−2** | 2 | −3 |
| `ceiling` | 2 | −1 | 3 | −2 |

`truncated` goes toward zero and `floor` goes down, so they differ only on a
negative. `rounded` goes **away from zero** at a half rather than toward even,
so it differs from `truncated` only at one. Two pairs that agree on the obvious
cases and part on the awkward ones is exactly the shape of thing a
reimplementation gets subtly wrong, so the suite asserts all sixteen cells and
the refusal:

```
float does not understand 'asInteger'
```

### The shape these programs are looking for

A test that samples the middle of a range agrees with an implementation that is
off by one at its ends. So the programs above assert the ends:

| | |
| --- | --- |
| `copyFrom(#2, #2)` | a range of one element is one element, not none and not two |
| `first(#99)` on four | **clamps** to four, where `at(#5)` is an error — the difference between the two is the point of having both |
| `[#1, #7, #3]:loop` | reaches 7 exactly; `[#1, #6, #3]` stops at 4, because the end is reached only if the step lands on it |
| `[#3, #1]:loop` | no iterations, not one |
| `doUntil({ true })` | runs **once** — the body comes first, which is the whole difference from `whileTrue` |
| `indexOf` when absent | `nil`, not `#0`, which a language counting from one cannot use as "absent" anyway |

Every one of these passes for an implementation that is subtly wrong if the
test only ever asks about the middle.

## The description

[`solveig.phx`](solveig.phx) is the published grammar —
`programs/check_syntax/solum.bnf`, kept unmodified in
[`tests/grammar/`](tests/grammar/) — with `->` clauses added. **Eighteen node
types**, where Pascal needed fifty-one, because Solveig has one thing that
happens and Pascal has many.

The operators are built as **the sends they read as**: `@expr(a + b * c)`
produces `Send(a, add, [Send(b, mul, [c])])` and there is no operator anywhere
in the tree, because the language says they are a second spelling and never a
second semantics. `&` and `|` wrap their right-hand side in a block, since
`and` and `or` short-circuit — the one place the lowering is more than
renaming.

### The round trip is the test

[`tests/roundtrip.sh`](tests/roundtrip.sh) parses every `.sol` file there is,
writes the tree back out as Solveig, and parses that: **the two trees must be
identical.** Seventy-five files, including a 2,800-line compiler written in
Solveig. It catches a node built with the wrong shape, an argument list
dropped, a chain folded the wrong way — over the whole corpus rather than over
the files somebody thought to look at.

The conformance programs get the stronger form: what comes out is compiled by
`solas`, run, and must print what the original printed.

### The one place it departs from the published grammar

`solum.bnf` lets the operator ladder take a leading minus, so `-1.5:truncated`
reads as `negated(1.5:truncated)`. `solas` reads it as `(-1.5):truncated`,
because outside an `@expr` region its scanner makes no minus at all — *'-' must
be followed by digits* is what it says. The two differ: `#-1` in the language,
`#1` in the grammar.

**The grammar file names this itself** — *"that is the looseness this ladder
costs"* — and a grammar checked against files rather than against a compiler
can afford it. A compiler cannot, so this description follows `solas`. It was
found by the round trip, on the two conformance programs that write a negative
float.

What emitting `.sob` would need is written down in
[the roadmap](../../docs/ROADMAP.md): length-prefixed tables fall out of
synthesised sizes, jump offsets fall out of the same, constant pools are a
threaded attribute, and the one thing missing is a way to write an integer as
bytes.
