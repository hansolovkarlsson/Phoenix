# Postmortem

*Written against the predictions the [roadmap](ROADMAP.md) and
[journal](journal.md) made before there was evidence. A prediction that held is
worth as little as one that failed unless both are written down; this file is
where the scoring happens. [COMPLETED.md](COMPLETED.md) is what exists;
this is what was **believed** about it.*

*Revised after awk, which is the first language described here that was not
chosen to suit the tool.*

Phoenix is ~12,900 lines of C11 with no dependencies. The descriptions written
against it come to ~4,100 lines: Pascal in 1,434 (56 node types, a checker and
two backends), Solveig in 1,108 (15 node types) with a bytecode backend, awk in
968 with a 682-line C runtime it embeds, calc in 362, and Phoenix's own
notation in 256.

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

### Held, and then failed, and then held: one implementation of the notation

A generated compiler runs the same `lex.c`, `parse.c`, `eval.c` and `run.c`
that `phx` runs, over frozen tables. There is nothing for the two to disagree
about, because there is only one of them.

**That was said here, and it was not true.** `emit.c` froze every string with
`strlen`, so a literal holding a **NUL** arrived short while the length beside
it still said otherwise — and the generated compiler read past the end of a
string `phx` never had. Any description with a NUL in a literal, which is every
description that emits a binary format, and `languages/solveig/solveig-sob.phx`
had one from the day it was written.

Nothing noticed for two stages, and the reason is the more useful half: **the
test only ever compared text.** The one backend emitting bytes had never been
written out as a compiler at all.

> "There is only one implementation" is a claim about the code. That it
> **holds** is a claim about the tests, and it is only as strong as the widest
> thing they compare.

The suite compares `.sob` files now, and a description whose literals hold a
NUL in a grammar, a pattern and a template at once.

### Held: tables-as-conditionals, in place of an `if`

Roadmap 3.5 called this "the assumption in the design most likely to be
wrong" and asked to have its first failure recognised as a decision arriving.
**It has not arrived.** `lookup(t, k, default)` carried an entire bytecode
backend — three-way choices between a local slot, an outer slot and a global;
an append-if-absent on four threaded tables at once — and never once wanted an
`if`.

**awk found the shape of it, and the shape is not an `if`.** `lookup` is a
function, so *both* answers are worked out before it chooses — fine until one
of them cannot be, which an omitted `for` part is. The fix was in the
**grammar**: an omitted part builds a node that renders as nothing, so every
part is emitted the same way and the question stops being asked. Third time the
answer to *"the notation cannot say this"* has been *"say something else,
earlier"*.

### Failed: the flat target would make `%rewrite` urgent

The design memo predicted that a flat target (assembly, bytecode) would be
"what pure attribute grammars are worst at" and would make a second mechanism
— rewriting with a traversal strategy — urgent rather than eventual.

**It did not.** The `.sob` backend is attribute clauses and nothing else. A
length-prefixed table is `size` of what the children emitted, so it is
synthesised. A name is an index into a table that grows as the walk goes, so
the table is threaded.

**`%rewrite` was built two stages later, and not for a flat target.** What
wanted it was an *optimisation*: `solas` compiles the block of an `ifTrue:`
into the enclosing chunk, and written as clauses that meant conditioning thirty
of `Block`'s on whether its parent inlined it. Taking the node out of the tree
costs nothing instead. So the prediction was right that a rewrite would be
wanted and wrong about every reason — which is the most common shape of a wrong
prediction on this page.

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
why both exist for every language: `fpc -Miso` for Pascal, `solas` + `solvm`
for Solveig, `/usr/bin/awk` for awk.

**awk demonstrated the round trip's blind spot a second time**, in a different
language and within an hour of the description being written. Fourteen programs
round-tripped to identical trees while two constructs were being written back
out as programs awk *rejects* — `if (c) { a }; else { b }` and `do { a };
while (c)`, where a `;` after a block ends the statement and orphans what
follows. Both read back as the same tree. It took running the rendering under
awk to see it.

### And a fourth kind, added since

| | catches | misses |
| --- | --- | --- |
| **comparing `phx` with a compiler `phx` wrote** | the two implementations drifting apart | anything both do wrongly — and anything in a *kind* of output the comparison does not cover |

That last clause is not hypothetical. The comparison existed for stages and
compared only text, and a bug that could only appear in binary output sat in
`emit.c` the whole time. A test's blind spot is the shape of what it compares,
not the shape of what it tests.

### What the numbers are

- 176 tests, 0 failing
- 35 Pascal programs agree with `fpc`; 5 out-of-subset programs are refused loudly
- 12 Solveig conformance programs, written against the documentation
- 6 awk programs other people wrote, and 7 written here, doing the same thing
  after this description rewrites them
- 13 awk programs, and the 6 in the corpus, compiled to C that prints what
  `/usr/bin/awk` prints
- every `.sol` file in the Solveig repository round-trips to an identical tree
- 76 Solveig programs compile to bytecode that prints what `solas`'s does, byte
  for byte, tracebacks included -- every one in that repository, with nothing
  normalised and nothing counted apart

---

## 3. What the design cost

**A library that grew.** 23 entries now. The rule each had to meet is written
down — *a pass for a real language needed it, and it could not be written in
the notation* — and each addition names what was missing. But roadmap 3.4 also
says a generator whose library keeps growing has failed at something, and the
last four arrived in two stages, three of them for one reason. That is the
number to watch, and what it is measuring is below.

**Repetition in the descriptions, and the thing behind it.** The
append-if-absent idiom appears six times in `solveig-sob.phx`, once per node
type that interns a name, because the notation has no way to name a shared
computation. The `.sob` line table then asked for something narrower and
sharper: **a value computed for every element of a list**. `each` applies a
template, and a template can only write an element out.

`sizes` and `bytes`-over-a-list were two cases of that answered one at a time,
and both turned out to be cases of something else. **The question was never a
map over a list**: it was an attribute every node has, of which a list of nodes
then has a column. `otherwise` is that, it is still a clause about a node, and
it took Pascal's twenty-one `type = "void"` clauses down to one.

The two library entries stay, and they are the honest cost of answering a
question one case at a time before seeing the shape of it.

**No forward references** — *and it turned out not to be a cost*. An attribute
cannot refer to a node the walk has not reached, and several passes with a
`%driver` are the answer. awk was described partly because it would test this:
a function may be called above where it is defined. Checking those calls is two
passes and twenty lines, because **a leaving clause on the root runs after the
whole subtree**, so the forward reference is answered by the shape of the walk.
Reference attributes are settled *against* — see
[COMPLETED.md](COMPLETED.md#21-reference-attributes--from-jastadd).

**Seven hundred lines of C in a string literal.** The awk backend needs a
runtime, because awk's value model is a string and a number at once and C's is
not. Held as literals it could not be **compiled** — the artefact that had been
tested against awk was not the artefact in the repository. `%embed` fixed it,
and the rule it changes is worth keeping: a mechanism has to answer not only
*who else wants this* but *what can no longer be checked without it*.

---

## 4. What was open here, and how each closed

Every question this section held has been answered, which is why it is written
in the past tense. [ROADMAP.md](ROADMAP.md) holds what is open now.

**A reader-level mechanism, for `@include`.** `%include` names which node an
include is built as and which field holds the file, and the reader splices
before the first pass; a backend has no clause for one and never meets one. It
took the shape this section proposed. What it did *not* find is anything wrong
with the backend over the 22 programs it added — the more useful half.

**Debug information in a binary target**, *and it cost more than this
paragraph expected*. `$pos` answers `Position(line, column, file, endline,
endcolumn)`. "Everything needed is present" was true of *reading* a position
and false of **using** one, and it took three more entries to finish: an
attribute every node has, a span rather than a point, and inlining, before
`languages/solveig/` agreed with `solas` on every byte of every program.

**Whether a description can share a computation.** *Answered, and the question
was mis-stated.* It was never a `%pass`-level definition or a rule other rules
call — either would have been the first thing in the notation that is not a
clause about a node. It is `otherwise`, which is the **most general** clause
about a node, and the evidence that settled it was already in
`languages/pascal/pascal.phx` before the question was asked.

---

### What replaced them

The questions that arrived while these were being answered are a different
kind, and worth naming because the shape repeats:

> Every time this project has predicted a **new mechanism**, the answer has
> been the mechanisms already there, used in an order nobody had tried.

- a map over a list → an attribute every node has
- a way to compile a block differently → take the block out of the tree
- a reference that points forward → a leaving clause on the root
- a conditional that skips a branch → a node that renders as nothing

Four for four. The question a new entry now has to answer first is *what does
the walk already know, and when does it know it?*

---

## 5. What has not been retracted

The plan was staged so that a wrong direction could be backed out to the last
stage that was right. **Nothing has been backed out.** Every stage still
stands, and the two designs most likely to fail — actions as a notation
Phoenix owns rather than host-language splices, and one walk rather than
demand-driven evaluation — are the two that made the later stages cheap.

awk is the strongest evidence for both, because it is the first language here
that was **not chosen to suit the tool**. It has pattern-action rules and no
main, no declarations, concatenation with no operator, a value that is a string
and a number at once, and a grammar that is not LL(1). It reads, round-trips,
type-checks its calls and compiles — and the six programs in its corpus were
written by people who had never heard of this.

The ratio is the claim, and it is now measurable on somebody else's code: **800
lines of awk in the corpus, 1,650 lines of description that compiles it, and
the description works on awk nobody has written yet.**

---

## 6. What the documentation week scored

Four kinds of page were made executable in one week — three tutorials and one
reference section — and the results split cleanly enough to be a rule.

### The prediction that failed: that reading a page verifies it

Every tutorial here was checked by its author while it was being written. That
turned out to be worth nothing, and the reason is not carelessness:

> An author runs the commands against files that already exist, in a directory
> that already has state. **Neither is what a reader has.**

Eight defects across three tutorials, and the shape of them is the tell. Three
were a command run on an artefact nothing had rebuilt after the source changed
— which does not fail, it silently answers about the previous build. One was
the closing comparison of a page, the step the whole tutorial builds to,
comparing two things that were no longer the same program. One was a command
naming a driver the page never told the reader to write. One was a line number
captured from a file that had a later section appended. One was a caret line
two spaces short.

Not one would have been found by reading. All were found in a single pass by
running.

### The prediction that held: that a reference is different

`docs/reference.md` § 11 had eighteen of the library's twenty-two functions
unchecked. 66 claims were written from it, in the order the page makes them.
**All 66 held.**

That is the more useful half of the week, because it says *which* pages need
this:

> A tutorial's claims are about a sequence of commands in a directory, and go
> stale when anything around them moves. A reference's claims are about the
> tool, and the tool has tests.

So the rule is not *run your documentation*. It is **run the documentation
whose claims are not already held by something else** — and a tutorial is
always in that category, because its subject is a session rather than a
program.

### What the checker did not catch, and now does

A field with a **threaded** attribute's name was silent. A field is read before
an attribute, so the clause meant to update the thread read the field instead:
the thread never passed through that node, and every node after it carried on
from a value that never went through. The chunk it produced was three bytes
wrong with no diagnostic, and it took a byte-level diff against a golden to
find.

The synthesised case had been warned about since the check was written. The
threaded case is the sharper one — the synthesised attribute is merely
invisible from outside, while the threaded one takes a value out of the fold
and puts a different one back — and it is an error now rather than a warning,
because there is no reading of it that is correct.

Settling the remaining case of that family turned up a documentation bug of
exactly the kind § 6 is about: `docs/manual.md` stated the name-resolution
order backwards. A binding wins over a field; the page said the reverse.

### And two entries left the roadmap with evidence rather than opinion

**2.3** had been open on scepticism for three languages. Describing Turbo
Pascal's units settled it against: resolution stayed an association list, and a
cycle between two implementations costs nothing because visibility does not
compose — *there is no traversal for a cycle to be a cycle in*. The entry's
leading criterion turned out not to be sufficient, which is a better result
than closing it would have been, because it names what to look for instead.

**1.6** was the last unfinished work in any language described here. Its
prediction was half wrong in the useful direction: `printargs` needed no
telling where to stop, because awk itself keeps `|` as the redirect inside a
print.

Section 2 of the roadmap is now empty and section 1 holds one entry, which is a
measurement rather than work.
