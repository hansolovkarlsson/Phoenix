# Roadmap

*What is coming, what is borrowed, and what is deliberately absent. An entry
here names **why** rather than when.*

**This page is what is *not* built.** [COMPLETED.md](COMPLETED.md) is the other
half — the tool, the languages, the notation, and every entry that has left
here with a verdict. [journal.md](journal.md) records what each stage cost and
what it got wrong first; [postmortem.md](postmortem.md) scores the predictions;
[CHANGELOG.md](CHANGELOG.md) answers the *when* this page deliberately does
not.

Three languages are described and compiled: Pascal against `fpc`, Solveig
against `solas`, awk against `/usr/bin/awk`, and a fourth description targets
SolVM's bytecode.

**Two entries were opened this way, and one is still open.** Section
1 and section 2 stood empty from 2026-09-03, every stage and every borrowed
idea having left with a verdict and three of them settled *against* building.
What re-opened them was not a survey of what other tools have — that survey was
done, and most of what it found is either already here or already refused. It
was that **two descriptions in this repository have a failure written down**,
in a `divergent/` directory and in a changelog, and each names a thing the
notation cannot say:

| | |
| --- | --- |
| [1.7](#17-a-repetition-that-counts) | `languages/solvm/` **emits `.sob` and cannot read it** |
| [2.5](COMPLETED.md#25-circular-attributes--from-jastadd) | *built 2026-09-23, for `languages/z80/`, as a driver stage run `until` an attribute settles.* `languages/units/` cannot refuse `A -> B -> C -> A`, and cannot order initialisation |

Neither is new. Both have been true for days and were recorded as costs rather
than as work; what changed is [lineage.md](lineage.md) naming the prior art, so
each is now *somebody's solved problem* rather than an open question.

The rest of the page is section 3, what this project has decided **not** to
have and why; section 4, what a description is checked for; section 5, the
warts it knows about; and section 6, **a C compiler** — the one arc here that
is a language rather than a mechanism, opened 2026-09-06 with its first step
named and the rest deliberately not.

---

## 1. The stages

**Eight have left, and one is open.** [COMPLETED.md](COMPLETED.md) has the
eight, with what each predicted against what it cost. Three of the first seven
predicted wrong, which is the more useful half, and one left **settled against
building it** after four measurements. The eighth, 1.8, arrived and left on
the same day, 2026-09-23, with its failure measured before any code: ROADMAP 6
said the predicate would be an entry here, and it was one for as long as it
took to build.

### 1.7 A repetition that counts

`{ x }` matches `x` until it stops matching. That is the only repetition the
notation has, and it is the wrong one for a **length-prefixed** format, where
what follows a count is *that many* of something and the thing after them is
not an `x` that failed — it is the next field.

**This is written down as a limit already**, in the entry that shipped the
assembler: Phoenix can emit `.sob` and cannot read it. The reading half is
`solvm --dump`, which is another project's binary doing a job this notation
cannot ask for — and that makes the oracle for the one backend emitting
**bytes** depend on a tool outside this repository.

*What it would take is not obvious, and that is the entry.* A count is a value
a pass computes, and the grammar runs before any pass does. So either a
repetition may read a **field of the node being built** — which makes the
parser depend on the tree in a way nothing here does yet — or the notation
grows a separate binary-reading half, which is a second mechanism and the thing
[3.4](#34-a-library-that-grows-without-deciding) says to be afraid of.

**Kaitai Struct has the vocabulary settled**: `repeat-expr` for a computed
count and `repeat-until` for a predicate, over a field already read.
[lineage.md](lineage.md) has the family. Borrow the words before inventing any.

*The condition for building it* is a second format that wants it. One is a
workaround; two is a mechanism. `.sob` is the one.

| | |
| --- | --- |
| [1.0](COMPLETED.md#10-a-reader-level-mechanism-for-a-target-languages-imports) | `%include` — a target language's own imports |
| [1.1](COMPLETED.md#11-a-nodes-position-reachable-from-a-clause) | `$pos` — where a node came from |
| [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation) | `otherwise` — what a node answers when its rule does not |
| [1.4](COMPLETED.md#14-where-a-node-ends) | a position is a **span** |
| [1.5](COMPLETED.md#15-a-runtime-that-is-not-a-literal) | `%embed` — a file's bytes under a name |
| [1.2](COMPLETED.md#12-compiling-the-tables-to-code) | compiling the tables to code — settled **against**: measured four times, and the fourth found the control |
| [1.6](COMPLETED.md#16--as-an-expression-operator-for-getline) | `\|` as an expression operator — awk's `cmd \| getline` |
| [1.8](COMPLETED.md#18-names-the-parse-keeps) | `%names`: names the parse keeps, for C's `typedef` |

**Open:** [1.7](#17-a-repetition-that-counts), a repetition whose count is a
value the parse has just produced.


## 2. Borrowed, and worth borrowing

Each of these is somebody else's solved problem. [lineage.md](lineage.md) says
whose. **All five are settled**: three built, and two tested and refused.

| | |
| --- | --- |
| [2.1](COMPLETED.md#21-reference-attributes--from-jastadd) | reference attributes, from JastAdd — settled **against**: awk needed a forward reference and two passes gave it |
| [2.2](COMPLETED.md#22-strategies--from-stratego) | strategies, from Stratego — `%rewrite` |
| [2.3](COMPLETED.md#23-scope-graphs--from-statix) | scope graphs, from Statix — settled **against**: Pascal units were described to test it, and resolution stayed a list |
| [2.4](COMPLETED.md#24-inlining-a-block--from-solas) | inlining a block, from `solas` |
| [2.5](COMPLETED.md#25-circular-attributes--from-jastadd) | circular attributes, from JastAdd: a driver runs a pass `until` an attribute of the root settles |

## 3. What is deliberately not here

### 3.1 An interpreter that can loop

`--run` evaluates attributes, and an attribute is computed **once per node in
one walk**. A loop needs its body evaluated a number of times that depends on
the program, and a branch not taken must leave the variables alone. Neither is a
thing a value computed once can say.

This is not a gap to fill. Interpreting is for checking a language while it is
being designed; compiling is what Phoenix is for, and the clauses in
[`languages/calc/calc.phx`](../languages/calc/calc.phx) say so where a program runs into it.

*It cost something, and the cost has been paid.* The conformance rule is that
one description, run two independent ways, gives one answer — and while one of
the two ways was the interpreter, the rule covered straight-line programs only.
Everything with a loop in it was checked by a single backend against a string
somebody had typed into the suite.

[`calc-awk.phx`](../languages/calc/calc-awk.phx) is the second emit pass, so a
looping program now has **two implementations under it** and the interpreter is
not needed as the referee. What the target had to be is the part worth keeping:
a second backend sharing C's arithmetic would catch a mistake in its own
clauses and not a host assumption leaking into the notation. awk's numbers are
**doubles**, so its `/` is floating division where calc's truncates, and the
backend writes the model out — [semantics.md](semantics.md)'s headline met a
second time in a second host. It also needs nothing this repository does not
already need, which is why it is awk and not the parked Solveig backend.

### 3.2 Actions as host-language fragments

yacc pastes C, Coco/R pastes C#, ANTLR pastes Java. It is the cheapest possible
design and Phoenix will not have it, because a description containing host code
can only ever generate that host — and *what language should the generated
compiler be written in* stops being a question anybody can ask.

### 3.3 Guessing the lexical/syntactic seam

A rule is not lexical because of anything about its shape; `identifier` and
`expression` look alike. A tool that guesses wrong reports a correct file as
broken, which is the worst thing this one could do. `%syntax` is declared.

**awk is what this costs, and it is worth being exact about whose problem it
is.** `/` is division and `/re/` is a regular expression, and which one it is
depends on the parser: a real awk lexer asks whether the previous token could
end an expression. Phoenix's scanner is longest match over the token rules and
has no such feedback, so `languages/awk/awk.phx` **guesses** — a regexp may not
start with a space, a tab or an `=`, and must close on the same line.

That is the description guessing, which is its business, and not the tool
guessing, which is what this entry refuses. The difference matters: the guess
is written down at the top of the file, it has a witness in
`tests/divergent/slash.awk`, and rendering that program puts the spaces in so
the divergence is **visible** rather than silent. A tool that guessed would
have had nowhere to write any of that.

What a scanner with parser feedback would cost is the thing to weigh if this
ever comes up twice: two languages have been described without wanting one, and
the third wants it in one construct.

**It came up twice, with C's `typedef`, and the answer was not the scanner.**
The seam C has is not lexical: `T` is a `name` token either way, and what
differs is which rule of the grammar it belongs to. So the feedback went into
the parse rather than across the seam, as a table the parse keeps and one
rule asks ([1.8](COMPLETED.md#18-names-the-parse-keeps)), and the scanner is
still longest match with no opinion. awk's `/` would want the other kind, and
still does not have it.

### 3.4 A library that grows without deciding

[`phoenix/library.c`](../phoenix/library.c) is a separate file so that every
addition is visible as an addition. A compiler generator whose library keeps
growing has failed at something: the notation was not expressive enough and
nobody noticed.

The rule an entry has to meet: **a pass for a real language needed it, and it
could not be written in the notation.** `quotient` and `remainder` are the
worked example — target languages disagree about negative division, and
truncation cannot be written in terms of flooring without a conditional.

The `.sob` backend added three, and each says what was missing:

| | |
| --- | --- |
| `bytes(n, width)` | a number as little-endian bytes; of a float, its IEEE 754 bits. A binary format cannot be emitted without it |
| `int(text, base)` | Solveig writes `#45`, `$ff` and `%1010` as one node, so the marker says the base |
| `positions(list)` | the table saying where each thing is. A slot *is* a position in the frame's list of names, and `at` wants an index rather than making one |

The line table added **one more, and one extension**, and both say the same
thing about the notation — see [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation):

| | |
| --- | --- |
| `sizes(list)` | the size of each element. The companion to `positions`: that one answers where each thing is, this one how big it is, and neither can be asked any other way |
| `bytes(list, width)` | a **column** of numbers, each as bytes. Not a new entry — the same function taking a list, the way `bind` takes names pairwise and `each` takes two lists |

C's constant expressions added **three more**, on 2026-09-25, for
[6.5](COMPLETED.md#65-constant-expressions):

| | |
| --- | --- |
| `bitand(a, b)`, `bitor(a, b)`, `bitxor(a, b)` | the bits of two integers. A pass that works out `case A \| B:` before the program runs has nothing to write it with in `+ - * div mod` |

**What was not added says as much.** C's other three bit operators, `~`,
`<<` and `>>`, can be written in the notation: `-x - 1`, a multiply by a
power of two, and a `div` by one, which floors as an arithmetic shift does.
So they are not in the library, by this rule, and the C description will
spell them out. The question this section asks of every entry was asked of
these: whether they were one case of a shape nobody saw. The shape here is
operators on integers the notation does not have, and the answer was three
functions and not a fourth kind of operator, because the booleans already
own the words.

**Both are cases `otherwise` would have covered**, and that is the entry worth
reading beside this one. They were added while the question looked like *"a map
over a list"*; it was [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation)'s,
*"an attribute every node has"*, and a list of nodes then has a column of them
for free. The rule this section states was met by both and they are still here,
so the rule is not enough on its own: **a library entry answers one case, and
what it costs is the chance to see the shape of the rest.**

### 3.5 Conditionals in the meta-language

There is no `if`. Clauses match on shape, and a clause that needs a choice is
evidence for another clause:

```
Binary(op: "+") : val = $left.val + $right.val .
Binary(op: "-") : val = $left.val - $right.val .
```

This is the assumption in the design most likely to be wrong, and it is written
here so that the first thing it cannot express is recognised as this decision
arriving rather than as a puzzle.

**It has not arrived.** Tables-as-conditionals carried an entire bytecode
backend — three-way choices between a local, an outer slot and a global, an
append-if-absent on four tables at once — without wanting an `if`. What gave
way first was something else entirely: see 3.6.

**But it has a shape, and awk found it.** `lookup` is a function, so **both
answers are worked out** before it chooses. That is fine when both can be, and
it is not when one of them cannot:

```
lookup([[true, ""]], $init = nil, "{};" of $init.out)    (* fails on the nil *)
```

A conditional would have skipped the branch it did not take. What was done
instead is worth more than the `if` would have been: the **grammar** changed so
that there is no nil. An omitted `for` part builds a `Nothing` node that renders
as nothing, every part is emitted the same way whether it is there or not, and
the question disappears rather than being answered.

That is the third time the answer to "the notation cannot say this" has been
"say something else earlier" — see [1.3](COMPLETED.md#13-a-way-for-a-description-to-share-a-computation)
and [2.4](COMPLETED.md#24-inlining-a-block--from-solas). It is not proof that an `if` is
never wanted. It is one more case where wanting one was a sign that a tree had
the wrong shape.

### 3.6 Threaded and inherited wanted to be one thing

A threaded attribute accumulates left to right along the walk. An inherited
one is scoped to a subtree. **A `.sob` method chunk wanted both**: its own
name and constant tables, accumulated in walk order, started empty on the way
in and put back on the way out.

The fix was not a new mechanism but a meaning for a combination that had none:
a `down` clause naming a threaded attribute sets the thread for the subtree.
The save is then an ordinary `down` attribute and the restore is the node's
own leaving clause, and it nests because a stack nests. `run.c` grew eleven
lines and knows nothing about chunks.

This is the first thing the design could not express, and it is recorded here
in the terms 3.5 asked for: not a puzzle, a decision arriving.

---

## 4. What a description is checked for

Every check Phoenix makes about a description exists because getting it wrong
produces the same failure: something that looks right and is not. The three
newest are all about **when a clause runs**, and all three were mistakes made
more than once while writing `languages/pascal/`:

- an attribute with the same name as a field of the node it is on — a field is
  read first, so nothing outside the pass can see the attribute
- a `down` clause reading an attribute its own rule computes — inherited runs
  on the way in, synthesised on the way out
- a check reading the attributes it guards — a check runs before them

A fourth arrived with `%include`, and it is the same argument in a different
place: a directive that names a node type and a field of it is two names that
can be typos, and a typo in either is a mechanism that silently does nothing.
Both are decidable from the description, so both are decided when it is read.

A fifth came with `$pos`, and it is about a **name** rather than about an
order: `pos` means the same thing in every clause of every pass only if nothing
else can be called that, so a field or an attribute of that name is refused.
The cost of a reserved word is real and is the kind this project prefers to
state rather than to hide — [5](#5-known-warts) already says so about `and`
and `or`.

`%rewrite` brought three more, and all three are about a **stage**: a driver
names one by its name, so two rewrites of one name, or a rewrite sharing a
pass's, is refused; and a rewrite reading `.something` a pass computes is
refused, because a rewrite runs to change the tree rather than to answer about
one and the walk it would be reading has not happened. The ordering hazard is
checked in a rewrite exactly as it is in a pass, since both try their rules in
order and the first match wins.

The first is a warning and the other two are errors, because the first is legal
and merely almost never meant.

**The general shape is worth stating**: a description is read once and then run
over every program ever compiled with it, so a fault found while reading it is
found before anybody else sees it. That is the whole argument for a check
existing at all, and the reason to prefer one over a comment.

**And two things no check can reach.** A description is checked when it is
read; what `-o` writes out is checked by *comparing* it with `phx`, and that is
only as strong as the widest thing compared. Text was compared for a year and
the one backend emitting **bytes** was never written out as a compiler at all,
so nothing noticed that a literal holding a NUL was frozen with `strlen` and
arrived short while the length beside it still said otherwise. The two
disagreed, silently, about a description they were both running. The suite
compares `.sob` files now.

The second is the **notation itself**. Every check on this page is about a
description; [semantics.md](semantics.md) is about the language descriptions
are written in, and nothing asked whether that page and `eval.c` still agreed.
They could have drifted a claim at a time with the whole suite green. Every
claim it makes is a check now, and every refusal it names is a clause, run
through `phx` and through a compiler `phx` wrote — which has to complain in the
same words. **A specification nothing runs is a document about a program.**

**And a third, found by asking what the round trip rests on.** Three of these
descriptions are checked by *rendering the tree back and parsing it again*, and
the rule that makes it worth doing is stated in
[COMPLETED.md](COMPLETED.md#defects-found-and-what-found-them) three times: a
round trip can be **green while the parse is consistently wrong**, because what
is written back out is wrong in the same way.

The renderers are hand-written — 122 lines in `languages/awk/`, 51 in
`solvm/`, 46 in `solveig/`, 16 in `calc/` — and a hand-written renderer is
precisely a second chance to make the first mistake. Nothing checks that a
`show` pass agrees with the grammar it is rendering; a person wrote both.

*What closes it is known and is not on this page.* Spoofax's SDF3 derives the
pretty-printer **from the grammar**, regenerated whenever the grammar changes,
so there is no second artefact to disagree — the layout lives in the production
that already says what the syntax is. It is not a roadmap entry because no
description here is blocked by the absence, and this page's bar is a language
that cannot say something. It is written here instead, under the heading for
things a check cannot reach, because that is what it is.

The three have one shape. **Everything the suite checks, it checks by
comparing two things — and each of these is a place where only one thing
exists.**

## 5. Known warts

**`pos` is a reserved field name.** Every node has a position and `$pos` is
what reads it, in every clause of every pass — which only holds if nothing else
can be called that. A grammar building a node with a field of that name is
refused. One word, across the whole notation, and it is the same bargain as the
one below rather than a different kind of cost.

**A grammar module imposes reserved words.** Importing
[`expression.phx`](../lib/expression.phx) means `and`, `or` and `not` cannot be
identifiers, because every word-shaped literal in the syntactic half is
reserved. There is no way to import a grammar and decline its vocabulary.

**There is no syntactic negative lookahead.** `!` is lexical only, refused in a
syntactic rule because there it would ask about characters where there are only
tokens. The cost is that the notation cannot describe two things the reader
does: a production ending without its `.`, and a directive's arguments ending
at a line. The second was fixed by letting a directive be terminated; the first
stands, and `languages/phx/phoenix.phx` records it.

**Ordered choice is not revisited.** `a | b` tries `a`, and if `a` succeeds and
the rule around it fails later, `b` is never tried. It costs nothing on an LL(1)
grammar, which is what nearly every published grammar is, and it costs a syntax
error on a correct file otherwise.

*Seven grammars later this has still not cost anything*, including awk, whose
grammar is famously not LL(1) — concatenation with no operator, and a `print`
whose arguments exclude a rung the rest of the ladder has. Both were describable
by putting the specific alternative first, which is what ordered choice asks
for and what a published grammar written for yacc does not say.

And two of the seven now **rely** on it rather than merely surviving it.
`languages/solvm/` puts `Label` above the mnemonics because `n:word ":"` fails
on `push` and falls through; `languages/units/` tries `slots 2` before
`slots self, n`. Ordered choice asked for the specific alternative first in
both, and in both that is also the clearer way to read the rule.

**There is no iteration over data inside a pass.** A `%rewrite innermost`
reaches a fixpoint over the **shape of a tree**, and since 2026-09-23 a driver
can run a whole pass `until` an attribute of the root settles, which is a
fixpoint over a *table* at the granularity of a walk:
[2.5](COMPLETED.md#25-circular-attributes--from-jastadd). What is still true is
the narrower thing: every list operation in the library answers in one step.
`each` applies a template once per element, `flatten` opens one level, and none
of them can be asked to run again on what it produced.

The cost was transitive closure, and
[`languages/units/`](../languages/units/) is the first thing to want one. It
refuses a circular interface `uses` two units deep — *does the unit I use use me
back* — and cannot refuse `A -> B -> C -> A`, because catching that means
closing the uses graph over itself.
[`divergent/three-cycle.pas`](../languages/units/divergent/three-cycle.pas) is
that, written down. A pass that adds one step of reachability, run `until` the
table settles, would now say it; nobody has written that pass, because `fpc`
already refuses the program and no one has asked for the diagnostic. It is a different absence from
[3.5](#35-conditionals-in-the-meta-language): a conditional is a thing the
notation says *no* to on purpose, and this is a thing nothing has yet made a
case for.

*A `thread` declared after the rules that assign it was silently not a thread,
and is now refused.* Kept here because the shape is worth having written down.
Found on 2026-09-05, by `languages/z80/`'s `seen` table answering `empty` at
every node. The clauses are classified as they are read —
`pass.c`'s `is_thread` is consulted at that moment — so a rule written above
the declaration gets an ordinary synthesised attribute, and a rule below it
gets the thread. Two different attributes, one name, and **no diagnostic**:

    %pass late                     %pass early
      Num  : seen = $seen + 1 .      thread seen = 0
      thread seen = 0                Num  : seen = $seen + 1 .
      Prog : total = $seen .         Prog : total = $seen .

The same three digits gave **0** on the left and **3** on the right. The
comment in `pass.c` states the requirement — *declared before the clauses that
update it* — so the reader was doing what it said it did; what was missing was
the complaint when a description does not.

**It is an error now**, in `check.c` beside the shadowed thread it is a family
with, and `otherwise` is covered as well as the rules. It went there rather
than into `pass.c`, where the classification happens, because a pass is only
whole once every `%import` has been read — a rule in one module and the
`thread` in another is the same defect and would have slipped a check that ran
per file. `tests/grammars/thread-declared-late.phx` is the witness.

**A field can shadow an attribute handed down.** A field is read before an
attribute, so a `down` clause naming one of its own node's fields hands a value
to that node's children which the node itself cannot read back. It is a warning
rather than an error, because handing it down may be the whole point.

The *threaded* version of the same collision is an error, and the difference is
worth the two entries: a synthesised or inherited attribute that is shadowed is
merely invisible somewhere, while a shadowed thread takes a value **out of the
fold and puts a different one back** — the thread skips that node, every node
after it carries on from a value that never went through, and nothing about the
answer looks wrong. It was silent until a description met it, and the file that
found it is [`tests/grammars/thread-shadowed.phx`](../tests/grammars/thread-shadowed.phx).

**`positions` is zero-based**, alone in a notation that counts from one
everywhere else — text indices, `at`, a reported line and column. It is that way
because what it exists for is **slot numbers**, and a frame's first slot is
zero. The inconsistency is real and is kept on purpose: making it one-based
would mean every use of it subtracting one, which is the off-by-one this
notation is otherwise arranged to avoid.

**A parse reports one syntax error, and only one.** A pass collects its
complaints and reports all of them — three undefined names give three `error:`
lines — but a parse stops at the first failure. Reporting more than one needs
error recovery, which changes what a parse *is*; `lineage.md` has the
literature, and nothing here is blocked by having one.

*Where that one error is reported was a second wart and is now fixed.* It is
worth leaving the shape of it written down. `parse.c` tracks the position the
match got **furthest**, which is the right heuristic; there were two failure
paths and the second discarded it, overwriting `furthest` with the first
leftover token while keeping the `wanted` list recorded elsewhere. Because a
start rule that is a repetition can never fail outright — `program = {
statement }` succeeds on zero statements — *every* syntax error in every
language here took that path, and named a token that was usually legal where it
stood.

**A test was pinning it.** `languages/awk/tests/divergent/spaced-regex.awk`
asserted the message contained `and found "BEGIN"` — the parser blaming the
first token of the file for a fault 34 columns into line 13. It now asserts the
position, which is what the divergence is about.

**A description may guess where the tool will not.** `languages/awk/awk.phx`
decides whether `/` opens a regexp by looking at the character after it,
because awk's own lexer asks the parser and Phoenix's scanner cannot — see
[3.3](#33-guessing-the-lexicalsyntactic-seam). That is the description's
business rather than the tool's, and the difference is that a description can
write the guess down, test the shapes it gets wrong, and render them back
visibly. `languages/awk/tests/divergent/` holds all three.

---

## 6. A C compiler

**Why this page has a language on it.** Every other entry here is a mechanism
the notation lacks, and a language arrives in `languages/` to test one. This
entry is the other way round: the language is the goal and the mechanisms it
turns out to need are the findings. The goal is the workspace's, not only this
repository's — [`../../docs/c-compiler-toolchain.md`](../../docs/c-compiler-toolchain.md)
records the intent that **every tool of a C toolchain eventually exist in the
workspace**, says what the stages are, and says why Phoenix is the one to
start from: its passes with `thread`, `down` and environments already carried
a Pascal typechecker, and the three things a C compiler needs that no tool
here has — a preprocessor, typedef feedback into the parse, a back end that
reaches a machine — are outside the grammar, not a stronger grammar. That
document has the order of the whole arc, and this page copies none of it.
**Its first step, [6.1](COMPLETED.md#61-step-one--a-subset-that-runs-and-cc-as-its-oracle),
is complete**, closed on 2026-09-23 when `long` made its last two
divergences agree. **Its second, [6.2](COMPLETED.md#62-a-function-that-returns-a-pointer),
a function that returns a pointer, was opened and closed on 2026-09-25.**
**Its third, [6.3](COMPLETED.md#63-the-operators), the rest of C's
expression operators, was opened and closed the same day.** **So were
[6.4](COMPLETED.md#64-the-statements), the statements, and
[6.5](COMPLETED.md#65-constant-expressions), expressions worked out before the
program runs**, built in the order 6.4 without `switch`, then 6.5, then
`switch`. What keeps a C program out of the subset now is its types and its
declarations, step four of the toolchain document, and each arrives the way
every entry does, with what breaks without it written down first. **The
first of them, [6.6](COMPLETED.md#66-a-call-to-printf), a call to a function
declared with `...`, was opened and closed on 2026-09-26.** **So was the
second, [6.7](COMPLETED.md#67-void-and-casts), `void` and casts, and the
third, [6.8](COMPLETED.md#68-globals), a variable declared outside every
function.** **So was the fourth, [6.9](COMPLETED.md#69-unsigned), the
`unsigned` types, opened on 2026-09-26 and closed on 2026-09-27**, the
first entry in the arc with a program the subset compiled and got wrong.
**Open: [6.10](#610-const-and-static), `const` and `static`**, the fifth,
chosen on 2026-09-29 by what CPP's own source uses most that the subset
does not have.

**What Phoenix cannot say today, so that the step is honest about what it
avoids.**

| | |
| --- | --- |
| `x * y;` | a declaration if `x` is a typedef, a product otherwise. The scanner cannot ask the parser and the parser cannot ask a pass, so the parse cannot know. [3.3](#33-guessing-the-lexicalsyntactic-seam) refused scanner feedback with the words *if this ever comes up twice*; awk was the first, and C's `typedef` would be the second, with the difference that awk's guess is lexical and C's is a **scope** the parse itself is building. A semantic predicate on the identifier rule is the PEG answer, and it is a change to the tool. *Answered 2026-09-23 by `%names`*, [1.8](COMPLETED.md#18-names-the-parse-keeps) |
| `#include`, macros, `#if` | a language on the token stream, expanded and rescanned. Not a grammar and not a tree walk, so no place for it in a description. `cc -E` supplies it until the workspace has its own |
| a machine | every backend here emits C, an outline, or `.sob` bytes. None emits an instruction sequence for a real processor; `languages/solvm/` and `languages/z80/` show that labels and an order the input never mentions are within reach of an emit pass |

### 6.10 `const` and `static`

C has two words the subset does not, and CPP, the workspace's own
preprocessor and the first program the chain means to compile for
Ouroboros, writes them more than any other it lacks: `const` 278 times and
`static` 129. **`static` says where a thing lives and who can see it**: on
a function or a global, that no other file can name it, C11 6.2.2p3; on a
local, that it is kept for the whole run and initialised once, 6.2.4p3.
**`const` says a thing is not written**, 6.7.3, and C refuses an
assignment to one, 6.5.16p2. Neither is reserved today, so a program that
writes either stops at a syntax error: `static int f(void)` at the
`static`, read as a type's name, and `const char *s` at the `const`.
CPP's other uses of `static`, five local arrays with an initialiser in
braces, need the braces, which are not in this step.

**What writing the witnesses found first: the subset compiles a program
`cc` refuses.** Neither word is reserved, so each is a name:

| program | `cc` | Phoenix today |
| --- | --- | --- |
| `int main(void) { int static = 1; int const = 2; return static + const; }` | refuses it at the first `static`, *expected identifier* | **compiles**; the program exits 3 |

No program the oracle may hold can show it, since the oracle holds only
what `cc` compiles; each part reserves its word, and the program goes to
`refused/`.

**Three programs show what breaks without it**, and join the oracle with the
part that makes each agree, beside a fourth that needs two files:

| program | `cc` | Phoenix today |
| --- | --- | --- |
| `static-files.c`: a `static` prototype and function, `static` globals zero and initialised with a number, a string and nothing, a `static` array and a `static` pointer to a struct, and a `static void` function that changes one | exits 2, prints `42 102 static 7 1` | stops at the `static` of the prototype, on line 2 |
| `static-locals.c`: a counter kept across calls, one initialised to 40, a recursion that keeps its depth in one, a `static` pointer initialised with an array's address and moved on each call, one with a string, a `static` array summed across calls and an `unsigned char` one that wraps, and one in a block of `main` | exits 47, prints `1 2 41 42`, `5 5`, `10 20 30 hi`, `256 3 11` and `10 3` | stops at the `int` after `static` in the first function, having read `static` as a variable |
| `const.c`: `const` before and after `int`, after a star, on a parameter, a member, a global and a typedef, a `const char *` walked along a string, an `int *const` written through, a `const struct` read through a pointer, a cast to `const int` and `sizeof` of two `const` types | exits 3, prints `5 4 17 2`, `5 7 9000000 4` and `42 8` | stops at the `const` of the typedef, on line 2 |
| `tests/link/`: two files, each with a `static int count`, a `static long total` and a `static int helper`, compiled by Phoenix and linked | prints `2 12 1202` | stops at `static` in each |

The fourth needs two files because **linkage cannot be seen in one**: a
`static` function in a single file behaves as any other. The two files
link only if each `helper` stays its own file's, and print `2 12 1202`
only if each `count` does. That second part is the one that could go wrong
quietly: a zero global written as a common symbol would be merged with the
other file's by the linker, and the program would link and print something
else. The emit pass writes every global today as `.globl` with its own
`.space`, and never as a common symbol, so the risk is in what `static`
leaves out, which is the `.globl`.

**Built in three parts, in this order**, each with the suite green:

1. **`static` on a function, a prototype and a global.** The word is
   reserved, as the first word of an item, and a thing declared with it is
   written without `.globl`. C11 6.2.2p4 lets a later declaration without
   `static` take the earlier one's linkage, so `static int f(void);` then
   `int f(void) { ... }` is internal; the other order is refused, as `cc`
   refuses it. `static-files.c` and `tests/link/` are the witnesses; the
   link test runs each file as Phoenix and as `cc` compile it, as
   `tests/abi/` does.
   *Built 2026-09-29.* `static` is an optional first word on each of the
   four function forms and the three global ones, and `internal` its flag;
   the `functions` pass keeps each function's linkage on a thread, in
   document order, and the emit pass leaves out `.globl` for what is
   `hidden`. **The word is first or it is not there**: C allows it among a
   type's words, `int static f(void)`, which `cc` compiles and is a syntax
   error here, beside `static` twice. `static-files.c` agrees with `cc`,
   and the link test in all three pairings. **Of ten breaks, one was a
   control that nothing caught, and one more passed**: a global array that
   forgot its `static`, because neither file had one. Both have one now.
2. **`static` on a local.** A declaration with it is a local in scope and a
   global in storage: it hides and is hidden as a local is, and it lives
   where a global does, under a label of its own that no two declarations
   in a file share, since two functions may each have a `static int n` and
   so may two blocks of one. Its initialiser is a global's, and **the
   `constants` pass gains its third customer**, refusing one that is not
   worked out before the program runs with the reason that pass now gives.
   It is written into the object file once, and never run as a statement.
   `static-locals.c` is the witness.
   *Built 2026-09-29.* Three statement forms and three nodes, `Static`,
   `StaticInit` and `StaticArray`, bound in the block's scope with an entry
   that says *global*. **An entry gained a ninth part, its label**: the name
   for a global, "" for what lives in the frame, and `f.n.K` for a `static`
   local, `K` counted across the file, where `cc` writes `f.n` and `f.n.1`;
   a name is reached by its label now, not by its name. **Writing the
   refusals found a message that was not true**: `static int *p = &a;`, `a`
   a local, was refused as *an address this cannot write*, which is what
   `&table[1]` gets, the limit this compiler keeps, and `cc` says the
   address of a local is no constant at all. File scope has no locals, so
   no global could be given one. The `constants` pass now says whether an
   address starts at a label, `rooted` of a value and `sited` of a place,
   and only one that does gets the message about an offset; a global
   pointer initialised from another's value, which said the same, says
   *cannot be* now too. Of twenty-two breaks one was a control, and three
   more passed at first: `rooted` read only the left of a `+`, and through
   a member that is an array, and the label's counter never moved, since
   no function had two `static`s of one name. Each has a witness now.
3. **`const`.** The word is reserved and may stand where C puts it in the
   subset's declarations: before or after the base, after any star, in a
   typedef, a parameter, a member, a cast and `sizeof`. **A type gains a
   fifth part**, which of its levels are `const`: bit 0 the value itself,
   bit 1 what it points at, and so on, so a `*` halves it and an `&`
   doubles it. A typedef carries its own, and `const` before a typedef's
   name qualifies the typedef's top level, so `const text` where `text` is
   a `const char *` is a `const char *const`. **What it changes is what is
   refused**: an `=`, a compound assignment, a `++` or a `--` whose place
   is `const`, and a struct assigned whole when a member of it is. Nothing
   in the emit pass changes. `const.c` is the witness, and a program for
   each refusal.

**What `cc` refuses, and so will this**: an assignment, a compound
assignment, `++` or `--` to a `const` local, global, member or pointer, or
through a pointer to `const`, a `->` through a pointer to a `const` struct
among them; a struct with a `const` member assigned whole; a `static`
local initialised with what is not worked out before the program runs;
`static` on a parameter, a member or a typedef; and a `static` definition
after a declaration without it. `int static` and `int const` join them,
from the table above. **Refused by name, though `cc` compiles them**:
`static` twice, which `cc` warns about. **Accepted as `cc` accepts it**:
`const` twice, which C11 6.7.3p5 allows.

*Not in this step:* an initialiser in braces, which CPP's `static` arrays
need and which a global does not have either; `extern`; `volatile` and
`restrict`; `static` in an array parameter's brackets; and a `const` that
a conversion with no cast drops, which `cc` warns about and C11 6.5.16.1
makes a constraint: it stays unchecked, by 6.7's rule that a conversion
with no cast is not checked. **The entry closes** when the three programs
and the link test agree with `cc`, with none diverging.
