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
| `floats` | the unmarked number is the float; narrowing names its direction; dividing by zero answers `infinity` rather than failing |
| `strings` | bytes and not characters, so `"café":size` is `#5`; one-based and both ends included |
| `arrays` | one-based, `add` answers the array so it chains, `join` is strict about strings |
| `dictionaries` | `at` fails on a missing key and `at(key, default)` does not |
| `blocks` | `whileTrue`, `doUntil` which runs its body first, `onError`, `ensure` |
| `control` | there is no `if`: these are messages taking blocks |
| `objects` | `new`, `via` where another language has `super`, and reflection that reads and never writes |
| `strictness` | no implicit conversion anywhere, with `equals` the one exception; and a message wanting a block says so when it is *sent* |

## What is not here yet

A Phoenix description of Solveig. The grammar half is ready to start from:
`programs/check_syntax/solum.bnf` in the Solveig repository is the published
grammar, and **Phoenix reads it unmodified and parses all 63 `.sol` files in
that repository** — every example, every program, every library file.

What emitting `.sob` would need is written down in
[the roadmap](../../docs/ROADMAP.md): length-prefixed tables fall out of
synthesised sizes, jump offsets fall out of the same, constant pools are a
threaded attribute, and the one thing missing is a way to write an integer as
bytes.
