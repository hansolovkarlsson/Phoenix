# awk

The third language described here, and the first whose grammar is **not
vendored**.

`languages/pascal/` holds Wirth's report grammar and `languages/solveig/` holds
that project's `solum.bnf`, both character for character, so that a claim about
reading the published grammar can be checked. There is no awk grammar on this
machine. [`awk.phx`](awk.phx) is the POSIX definition **transcribed** into
Wirth's notation, and saying so is the honest version of the difference.

What carries the weight instead is the oracle. `/usr/bin/awk` decides what awk
means, and [`tests/corpus/`](tests/corpus/) is six awk programs written by other
people for reasons of their own — e2fsprogs, ncurses and vim ship them.

## Why awk

Pascal has statements, expressions and a type system, and fifty-one node types.
Solveig has one thing that happens — a message is sent — and twelve. awk has
neither shape, and forty-six:

- a program is a list of **pattern–action rules**, run over every line of input,
  with no main and no entry point;
- **nothing is declared.** A variable exists because it was mentioned, its type
  is whatever it last held, and an array springs into being on first subscript;
- **concatenation has no operator.** Two things beside each other are joined,
  which is why awk's grammar is not LL(1) and why `concat` here is a repetition
  of the rung below it;
- a function may be **called above where it is defined**, which is the forward
  reference [ROADMAP 2.1](../../docs/ROADMAP.md) has been waiting for a
  language to need.

## What is here

```
awk.phx                 the grammar, the tree, and a `show` pass
tests/
  corpus/               awk other people wrote: e2fsprogs, ncurses, vim
  conformance/          programs and the output each must produce under awk
  divergent/            two programs this reads differently from awk, on purpose
  outside/              gawk, kept for the round trip and nothing else
  roundtrip.sh          parse, render, parse, and compare the trees
  oracle.sh             run both under awk and compare what they print
```

## The one place it guesses, and it is awk's fault

**`/` is division and `/re/` is a regular expression, and which one it is
depends on the parser.** A real awk lexer asks whether the previous token could
end an expression. Phoenix's scanner is longest match over the token rules and
has no such feedback — deliberately, and
[ROADMAP 3.3](../../docs/ROADMAP.md) says why: a tool that guesses the
lexical/syntactic seam reports a correct file as broken, which is the worst
thing it could do.

So the *description* guesses instead, which is its business rather than the
tool's: `ere` requires the character after the `/` to be neither a space, a tab
nor an `=`, and requires the closing `/` on the same line. That reads every
regexp in the corpus and every division in it, because nobody writes `a/b/c`
without spaces.

**It has a shape it gets wrong**, and that shape is checked in:
[`tests/divergent/slash.awk`](tests/divergent/slash.awk) is `a/b/c`, which this
reads as `a` concatenated with the regexp `/b/` concatenated with `c`.
Rendering it puts the spaces in, so the divergence is visible rather than
silent — which is the most that can be done about a guess.

The second divergence is next to it. `f (1)` with a space is **not a call** in
awk: POSIX makes `FUNC_NAME` a name *immediately* followed by `(`. Saying that
here means putting the `(` inside the token, and then `if(`, `while(` and
`print(` become function names too. So this reads a call, and
[`spaced-call.awk`](tests/divergent/spaced-call.awk) says so.

## How it is checked

**Round trip.** Every program here is parsed, written back out and parsed
again; the two trees must be identical. It is a round trip of *structure* and
not of source — comments are gone, statements come out separated by `;` — and
it works because a parenthesis is a `Group` node, so no bracket comes back that
was not written.

**The oracle**, which is the one that matters. A round trip can be green while
the parse is consistently wrong: what is written back out is wrong in the same
way, so it re-parses to the same tree, and
[the journal](../../docs/journal.md) has that mistake twice. So each program is
*run* under `awk`, before and after rendering, and must print the same thing.

It found two bugs the round trip could not, and both are about a **terminator**
rather than a tree:

| | |
| --- | --- |
| `if (c) { a }; else { b }` | a `;` after a block ends the `if`, leaving the `else` orphaned — and is *required* when the branch is not a block. Two clauses now, chosen by the shape of the branch |
| `do { a }; while (c)` | the same thing again, and found the same way |

Each read back as the same tree and neither is awk.

## What it does not do

**Compile anything.** This is a front end: a grammar, a tree and a way to write
it back out. `languages/solveig/` was built the same way round — a conformance
suite, then a description that reads every program there is, then a backend —
and the reason is that a backend for a language whose parse is wrong is a
backend that has to be written twice.

**`getline`**, which is refused rather than mis-read: it is the one construct
in awk whose grammar depends on where it appears, and it appears nowhere in the
corpus.
