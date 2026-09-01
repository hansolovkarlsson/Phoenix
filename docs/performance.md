# What it costs

*Measured, on this machine, with `bench/run.sh`. Every number here is
reproducible; the step counts are exact and the times are not.*

The question worth asking was never *how fast*. It was **whether the work grows
in proportion to the input** — because a PEG with no memoisation need not, and
Phoenix has no memoisation at all. A constant factor is a decision; a bad
complexity is a defect.

---

## It is linear, in all four shapes

A step is one attempt to match one grammar node at one position. Steps are
deterministic, so this is the shape of the curve exactly rather than a
measurement of it.

| shape | what it is | steps per token, n = 100 → 1600 |
| --- | --- | --- |
| `width` | *n* statements one after another | 24.1 → 24.2 |
| `expr` | one *n*-term expression | 12.6 → 11.6 |
| `nest` | *n* nested parentheses | 30.6 → 31.4 |
| `blocks` | *n* nested `begin`/`end` | 22.3 → 22.3 |

Sixteen times the input, the same work per token. **There is no bad case in
Pascal's grammar**, which is the thing that had never been checked.

The constant is about **24 match-steps per token** — the price of ordered
choice, most of it `factor` trying an identifier three ways before settling.
Memoisation would cut it and cost a table per position; nothing yet suggests
that trade is worth making.

## What it takes in time

20,000 lines of Pascal, all the way from source to a running program:

| | |
| --- | --- |
| `phx`, parse + typecheck + emit C | **238 ms** |
| the generated compiler, same input | **195 ms** |
| parse alone | 141 ms |
| reading `pascal-c.phx` and stopping | 5 ms |
| `gcd.pas`, 94 lines, end to end | 6 ms |

**The generated compiler is about 18% faster, and the saving is a fixed cost**
— it neither reads a description nor checks one, because both were done when it
was written. On a small program that fixed cost is most of the run; on a large
one it is noise. The generated compiler's value is that it stands alone, not
that it is quick.

### Against `fpc`

Not a like-for-like comparison and it should not be read as one: `fpc -Miso`
does native code generation and linking, and Phoenix emits C and hands both to
`cc`. On 2,000 lines `fpc` takes about 290 ms of CPU for all of that, and
Phoenix takes 31 ms to reach C — after which `cc` takes 156 ms.

The one comparison that *is* fair: on the 20,000-line file, **`fpc` fails** —
*"Procedure too complex, it requires too many registers"* — and Phoenix does
not, because register allocation was never Phoenix's problem.

---

## What measuring found

**A segmentation fault.** Matching is recursive descent, so the C stack is
proportional to how deeply the *input* nests, and about 3,400 nested
parentheses exhausted it. The program died with a signal, which tells the
person nothing and cannot be caught — and input is not a thing a compiler gets
to trust.

There is a depth limit now, and past it a message with a position:

```
nested too deeply here -- more than 10000 levels, which is past anything
a person writes
```

Ten thousand is two orders of magnitude above what real programs reach —
`gcd.pas` gets to 62, `features.pas` to 67, `primes.pas` to 99 — and well below
where the stack actually goes. `--stats` reports the depth a file reached, so
the headroom is a thing anybody can check rather than a thing this page claims.

**That is what the measurement was for.** The linearity result confirmed what
was hoped; the crash was not suspected by anyone, and would have been found by
somebody else's malformed input instead.
