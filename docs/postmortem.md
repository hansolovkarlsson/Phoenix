# Postmortem

*Written after seven stages, against the predictions the
[roadmap](ROADMAP.md) and [journal](journal.md) made before there was
evidence. A prediction that held is worth as little as one that failed unless
both are written down; this file is where the scoring happens.*

Phoenix is ~10,000 lines of C11 with no dependencies. The descriptions written
against it come to ~2,900 lines: Pascal in 780 (53 node types, a checker and
two backends), Solveig in 312 (15 node types) with a 372-line bytecode
backend, and Phoenix's own notation in 242.

---

## 1. What was predicted, and what happened

### Held: a compiler is a grammar plus a sequence of walks

The whole premise. Four real passes exist — a renderer, a symbol collector, a
type checker, and several emitters — and none of them contains traversal code.
The Pascal checker follows records, `with` blocks and forward declarations
through **four hops** of an environment that is an ordinary list of pairs.

That worked for a reason worth naming: **every hop points backwards**, at a
node the single post-order walk has already finished with. Nothing needed a
second walk, a worklist, or a fixed point.

### Held: one implementation of the notation, not two

A generated compiler runs the same `lex.c`, `parse.c`, `eval.c` and `run.c`
that `phx` runs, over frozen tables. The conformance test says the output is
identical byte for byte. **There has never been a disagreement between the
interpreter and generated code**, because there is nothing to disagree.

The cost was measured rather than assumed: about 24 match-steps per token,
20,000 lines of Pascal to running C in 238 ms. Nothing has asked for faster.

### Held: tables-as-conditionals, in place of an `if`

Roadmap 3.5 called this "the assumption in the design most likely to be
wrong" and asked to have its first failure recognised as a decision arriving.
**It has not arrived.** `lookup(t, k, default)` carried an entire bytecode
backend — three-way choices between a local slot, an outer slot and a global;
an append-if-absent on four threaded tables at once — and never once wanted an
`if`.

### Failed: the flat target would make `%rewrite` urgent

The design memo predicted that a flat target (assembly, bytecode) would be
"what pure attribute grammars are worst at" and would make a second mechanism
— rewriting with a traversal strategy — urgent rather than eventual.

**It did not.** The `.sob` backend is attribute clauses and nothing else. A
length-prefixed table is `size` of what the children emitted, so it is
synthesised. A name is an index into a table that grows as the walk goes, so
the table is threaded. `%rewrite` is still unbuilt and still unneeded, seven
stages in.

### Failed: the missing thing would be expressiveness in expressions

What actually gave way was a **combination of two mechanisms that had no
meaning**. A threaded attribute accumulates left to right along the walk; an
inherited one is scoped to a subtree. A `.sob` method chunk wants both — its
own name and constant tables, accumulated in walk order, started empty on the
way in and put back on the way out.

The fix was eleven lines: a `down` clause naming a threaded attribute sets the
thread for the subtree. The save is then an ordinary `down` attribute, the
restore is the node's own leaving clause, and it nests because a stack nests.
`run.c` still knows nothing about chunks.

**The lesson is about where to look, not about what to add.** Six stages of
attention went to the expression language, and the gap was in the walk.

---

## 2. What the tests prove, and what they do not

Three kinds of check exist here, and they are not interchangeable. Ranked by
what they can catch:

| | catches | misses |
| --- | --- | --- |
| **round trip** — parse, render, parse, compare trees | a node built with the wrong shape, a dropped argument, a chain folded the wrong way | anything wrong *consistently*, because the renderer inherits the parser's mistake |
| **reading the output** | anything wrong on its face | anything that looks right and is not |
| **an oracle** — compile it, run it, compare what it prints | a wrong answer, whatever produced it | a right answer reached wrongly (see below) |

**The round trip's blind spot was demonstrated, not theorised.** `group`
parsed `("ran":display. { nil })` as `("ran":display. "ran":display)` — the
first statement twice, every later one dropped. The parse was wrong, the tree
was wrong, and what `show` wrote back was wrong *in the same way*, so it
re-parsed to an identical tree and the round trip passed. 75 files, every one
of them green, for as long as the bug existed.

**And an oracle has a blind spot too**, also demonstrated: `array [5..9]` had
one subtracted instead of five, so it wrote outside itself — and `fpc`
**agreed with it**, because the write and the read used the same wrong offset.
The answers matched and the memory did not. An oracle proves the answers
agree, not that the program is correct.

The conclusion is that neither is optional and neither is sufficient, which is
why both exist for both languages: `fpc -Miso` for Pascal, `solas` + `solvm`
for Solveig.

### What the numbers are

- 113 tests, 0 failing
- 35 Pascal programs agree with `fpc`; 5 out-of-subset programs are refused loudly
- 12 Solveig conformance programs, written against the documentation
- 75 Solveig files round-trip to an identical tree
- 50 Solveig programs compile to bytecode that prints what `solas`'s does

---

## 3. What the design cost

**A library that grew.** 22 entries now. The rule each had to meet is written
down — *a pass for a real language needed it, and it could not be written in
the notation* — and each addition names what was missing. But roadmap 3.4 also
says a generator whose library keeps growing has failed at something, and two
of the 22 arrived in one stage, with a third gaining an argument. That is the
number to watch.

**Repetition in the descriptions.** The append-if-absent idiom appears six
times in `solveig-sob.phx`, once per node type that interns a name, because
the notation has no way to name a shared computation. Not wrong, but the
clearest place where a description is longer than the thing it describes.

**No forward references.** An attribute cannot refer to a node the walk has
not reached. Several passes and a `%driver` are the answer, which is what a
hand-written compiler does anyway — but it is a real constraint and it is why
reference attributes stay on the roadmap.

---

## 4. Open, and worth deciding before building

**A reader-level mechanism, for `@include`.** 24 of the Solveig files in the
repository use it, and the bytecode backend refuses all 24. Splicing another
file in before compiling is something a **reader** does, and a pass is a walk
over one tree that has already been read. Phoenix has `%import` for its own
descriptions and nothing for a *target* language's imports. Any language with
a module system wants the same thing, so this is the first gap that is about
the shape of the tool rather than about expressions.

**Debug information in a binary target.** The `.sob` backend emits one line
run per chunk and no file table, so a traceback says `[line 1]` where `solas`
says the file and the line. Everything needed is present — a node carries its
position — and nothing in the notation reaches it. `$pos` does not exist.

**Whether a description can share a computation.** See the repetition above. A
`%pass`-level definition, or a rule that other rules can call, would remove
it — and would be the first thing in the notation that is not a clause keyed
by node type.

---

## 5. What has not been retracted

The plan was staged so that a wrong direction could be backed out to the last
stage that was right. **Nothing has been backed out.** Every stage still
stands, and the two designs most likely to fail — actions as a notation
Phoenix owns rather than host-language splices, and one walk rather than
demand-driven evaluation — are the two that made the later stages cheap.
