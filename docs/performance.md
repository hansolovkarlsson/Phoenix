# What it costs

*Measured on this machine with `bench/run.sh` and `phx --stats`. **Every number
here is reproducible**, and the command that produces it is beside it. The step
counts are exact; the times are not.*

The question worth asking was never *how fast*. It was **whether the work grows
in proportion to the input** — because a PEG with no memoisation need not, and
Phoenix has no memoisation at all. A constant factor is a decision; a bad
complexity is a defect.

**Measured four times now**, on three grammars that are as unalike as the
project has: Pascal's shallow ladder, awk's fourteen rungs and juxtaposition,
and SolVM assembly, which has no expression grammar at all.

---

## Nine shapes, three grammars, one curve

A step is one attempt to match one grammar node at one position. Steps are
deterministic, so this is the shape of the curve exactly rather than a
measurement of it.

### Pascal — `sh bench/run.sh`

| shape | what it is | steps per token | depth |
| --- | --- | --- | --- |
| `width` | *n* statements one after another, n = 100 → 1600 | 23.8 → 23.8 | 37 |
| `expr` | one *n*-term expression, n = 100 → 1600 | 12.6 → 11.6 | 37 |
| `nest` | *n* nested parentheses, n = 100 → 800 | 30.1 → 30.9 | 1,127 → 8,827 |
| `blocks` | *n* nested `begin`/`end`, n = 100 → 800 | 22.0 → 22.0 | 827 → 6,427 |

### awk — `sh bench/run.sh languages/awk/awk.phx bench/generate-awk.awk "width expr" "..."`

| shape | steps per token | depth |
| --- | --- | --- |
| `width`, n = 50 → 800 | 416.0 → 408.5 | 60 |
| `expr`, n = 25 → 200 | 285.7 → 221.4 | 60 |
| the corpus (awk other people wrote) | 370 – 2,638 | ≤ 150 |

### SolVM assembly — `sh bench/run.sh languages/solvm/solvm.phx bench/generate-solvm.awk "width labels blocks"`

| shape | steps per token | depth |
| --- | --- | --- |
| `width`, *n* instructions, n = 100 → 1600 | 25.5 → 25.3 | 13 |
| `labels`, *n* labels each jumped to, n = 100 → 1600 | 11.7 → 11.6 | 13 |
| `blocks`, *n* nested `.block`s, n = 100 → 1600 | 11.0 → 10.7 | 410 → 6,410 |

**Sixteen times the input, the same work per token, in every shape of every
grammar.** Two of the nine get *cheaper* per token as they grow. Nothing rises.

## The constant spans 240×, and the curve does not move

| grammar | steps per token | what its grammar is |
| --- | --- | --- |
| SolVM assembly | **11 – 25** | no expression grammar at all; the first token settles which rule matches |
| Pascal | **12 – 31** | a shallow ladder, and an LL(1) shape |
| awk | **221 – 2,638** | fourteen rungs, concatenation with no operator, and a `print` needing six rungs duplicated |

That is the useful result of measuring a third grammar. **The constant tracks
how deep the ordered choice has to go before it commits; the curve does not
track anything.** The assembler is the control: it is what this matcher costs
when a grammar asks nothing of it, and it is not meaningfully cheaper per token
than Pascal.

The depth column says the same thing from the other side. A flat grammar reaches
depth 13 on 4,803 tokens and depth 13 on 300 — **depth is a fact about the
input's nesting, not its length**.

## Where the depth limit actually binds

`nest` and `blocks` do not reach n = 1600, and the reason is worth stating
precisely because the number is easy to misread. The limit is **10,000
levels of grammar recursion**, and a construct costs more than one:

| construct | levels each | limit reached at |
| --- | --- | --- |
| a nested parenthesis in Pascal | 11 | ~900 |
| a nested `begin`/`end` | 8 | ~1,200 |
| a nested `.block` | 4 | ~2,500 |

So ten thousand *levels* is about nine hundred *parentheses*, not ten thousand
of them. Both are far past anything written by a person — `gcd.pas` reaches 62,
`features.pas` 67, `primes.pas` 99 — and `--stats` reports the depth a file
reached, so the headroom is a thing anybody can check rather than a thing this
page claims.

## What it takes in time

20,000 lines of Pascal, all the way from source to a running program:

| | |
| --- | --- |
| `phx`, parse + typecheck + emit C | **189 ms** |
| parse alone | 90 ms |
| `gcd.pas`, 94 lines, end to end | 6 ms |
| the largest awk anybody else wrote — `et_c.awk`, 269 lines, 1,452 tokens, 2.9M match-steps | **50 ms** to running C |

The node count for `et_c.awk` is the more surprising figure: **70,204 values
built for 1,452 tokens**, most of them made and dropped inside alternatives that
failed. That is what ordered choice costs, and what memoisation would save.

### Against `fpc`

Not like-for-like and should not be read as one: `fpc -Miso` does native code
generation and linking, and Phoenix emits C and hands both to `cc`. On 2,000
lines `fpc` takes about 290 ms of CPU for all of that, and Phoenix takes 31 ms
to reach C — after which `cc` takes 156 ms.

The one comparison that *is* fair: on the 20,000-line file, **`fpc` fails** —
*"Procedure too complex, it requires too many registers"* — and Phoenix does
not, because register allocation was never Phoenix's problem.

---

## What measuring found

**A segmentation fault**, the first time. Matching is recursive descent, so the
C stack is proportional to how deeply the *input* nests, and about 3,400 nested
parentheses exhausted it. The program died with a signal, which tells the person
nothing and cannot be caught — and input is not a thing a compiler gets to
trust. There is a depth limit now, and past it a message with a position.

**A benchmark that could not fail**, the fourth time. `bench/run.sh` did not
check whether `phx` had succeeded. On error `--stats` prints nothing and the
diagnosis arrives on the same stream, so `awk '{print $9}'` picked a word out of
the error message and the row looked like a measurement. Two numbers on this
page came from exactly that — `nest` and `blocks` at n = 1600, for shapes that
cannot complete.

> **A measurement harness that cannot report failure will report something
> else.** The numbers it invented were plausible, which is why they survived
> three readings of this page.

It checks the exit status now, prints the reason where the numbers would go,
and refuses a `--stats` line whose fields are not numbers — so a change to that
format is a loud failure rather than a quiet one.

**And a generator that did not exist.** The awk figures had no generator in
`bench/`; nothing in the repository could reproduce them. `bench/generate-awk.awk`
is that, now, and its constant differs from what the page used to claim because
the grammar has since gained a rung — `|` as an expression operator, for
`getline`. That is the sort of drift a reproducible number shows and an
unreproducible one hides.
