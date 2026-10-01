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
**So was the fifth, [6.10](COMPLETED.md#610-const-and-static), `const`
and `static`, opened and closed on 2026-09-29**, chosen by what CPP's own
source uses most that the subset did not have. [6.11](#611-a-second-target-elf-under-aapcs64),
a second target, was opened the same day and **parked** the same day, when
the arc was put before the port. **So was the sixth,
[6.12](COMPLETED.md#612-declarations-as-c11-67-has-them), declarations as
C11 6.7 has them, opened on 2026-09-29 and closed on 2026-09-30**, the
first entry of the C11 arc. **So was the seventh,
[6.13](COMPLETED.md#613-initialisers-as-c11-679-has-them), initialisers
as C11 6.7.9 has them, opened on 2026-09-30 and closed on 2026-10-01**,
the second. **So was the eighth,
[6.14](COMPLETED.md#614-pointers-to-functions), pointers to functions,
opened and closed on 2026-10-01**, the third. **Open:
[6.15](#615-the-integer-types), the integer types**, the fourth, opened on
2026-10-01.

**The arc has a destination since 2026-09-29: C written on Ouroboros.** The
workspace chose it, and
[`../../docs/c-compiler-toolchain.md`](../../docs/c-compiler-toolchain.md#the-destination-c-on-ouroboros)
has the order, whose last step is the one 6.10 was already steering by: the
chain compiling CPP's own source, there. *CPP is now Proem, since
2026-10-01*: the workspace's preprocessor was renamed, its folder is
`~/Projects/Proem` and its repository `github.com/hansolovkarlsson/Proem`, and
`~/Projects/CPP` no longer exists. Every mention of CPP on this page means
Proem. What it asks of this page, once the
C compiler is complete, is **a second target for `c-arm64.phx`**. Every choice the back end makes today
is Apple's: `_main`, `@PAGE` fixups, variadic arguments on the stack, a
signed plain `char`. Ouroboros is ELF under AAPCS64 as written, so a program
calling `printf` compiled for it would hand picolibc its arguments where
picolibc does not look. The oracle for that target is clang with
`--target=aarch64-unknown-none`. It is written down as
[6.11](#611-a-second-target-elf-under-aapcs64), with its failing program
first, and parked until then.

**What Phoenix cannot say today, so that the step is honest about what it
avoids.**

| | |
| --- | --- |
| `x * y;` | a declaration if `x` is a typedef, a product otherwise. The scanner cannot ask the parser and the parser cannot ask a pass, so the parse cannot know. [3.3](#33-guessing-the-lexicalsyntactic-seam) refused scanner feedback with the words *if this ever comes up twice*; awk was the first, and C's `typedef` would be the second, with the difference that awk's guess is lexical and C's is a **scope** the parse itself is building. A semantic predicate on the identifier rule is the PEG answer, and it is a change to the tool. *Answered 2026-09-23 by `%names`*, [1.8](COMPLETED.md#18-names-the-parse-keeps) |
| `#include`, macros, `#if` | a language on the token stream, expanded and rescanned. Not a grammar and not a tree walk, so no place for it in a description. `cc -E` supplies it until the workspace has its own. *The workspace has one since 2026-09-27*, [`~/Projects/Proem`](../../Proem/) (CPP until 2026-10-01), not yet put in `cc -E`'s place |
| a machine | every backend here emits C, an outline, or `.sob` bytes. None emits an instruction sequence for a real processor; `languages/solvm/` and `languages/z80/` show that labels and an order the input never mentions are within reach of an emit pass |

**The arc now: C11, before Ouroboros.** Decided by Hans on 2026-09-29,
after 6.11 was opened: the first arc is `c.phx` conforming to C11, and the
port to Ouroboros is a later arc, so 6.11 is parked where it stands.
**The C compiler is completed before the port begins**, and Hans made the
rule exact on 2026-09-30: nothing whose only purpose is Ouroboros starts
until he is satisfied with the compiler itself. That is 6.11, and after it
cross-compiling onto Ouroboros, an assembler and a linker there, and
anything else that exists for the port alone. The gate is his judgement
of the compiler, not the close of any one entry: conforming to C11 is the
arc that is to get it there. What conforming means was settled on
2026-09-29:

- **The mandatory language, and none of the four optional features.** C11
  lets an implementation conform without variable-length arrays,
  `_Complex`, `_Atomic` and `<threads.h>` by defining
  `__STDC_NO_VLA__`, `__STDC_NO_COMPLEX__`, `__STDC_NO_ATOMICS__` and
  `__STDC_NO_THREADS__`, 6.10.8.3. This one defines all four and refuses
  each feature by name.
- **The compiler proper**, translation phases 5 to 8. Phases 1 to 4 stay
  with `cc -E` until CPP takes its place, and the library is the system's,
  which `cc` links. The freestanding headers a program includes,
  `<stdarg.h>`, `<stddef.h>`, `<stdbool.h>`, `<stdint.h>`, `<limits.h>`,
  `<float.h>`, `<stdalign.h>` and `<stdnoreturn.h>`, must work with what
  `cc -E` puts in them.

**What is left between the subset and C11.** Counted on 2026-09-29 from
`c.phx`, its refusals in `languages/c/tests/refused/`, CPP's own source,
and two dozen programs tried against the `check` driver. It is a map of
the ground and not a queue: none of it is an entry until it is opened
with its failing program. It is a careful count and not a clause-by-clause
audit, so a construct missing from it is not proof that the subset has
it; each entry audits its own clause of the standard when it opens.
**Bold** marks what compiling CPP's source needs, which still says where
the arc is going after this one.

| | what the subset lacks |
| --- | --- |
| declarations, 6.7 | *most of it since [6.12](COMPLETED.md#612-declarations-as-c11-67-has-them)*. *Function pointers since [6.14](COMPLETED.md#614-pointers-to-functions)*. Left: a function declared through a typedef of its type, `binop add;`, refused by name; parentheses more than one deep in a declarator; a function declarator in a list, `int x, f(void);`; an identifier-list definition whose declarations are in another order or name two at once; a struct passed whole to a prototype written before it is complete; a global of a struct completed later in the file |
| initialisers, 6.7.9 | *all of it since [6.13](COMPLETED.md#613-initialisers-as-c11-679-has-them)*, but for what waits on other rows: a `union`'s, a wide string, an `enum` constant as a value. Refused by name: an array designator that is an expression and not a number written out; an object nested more than eight levels deep; a struct over 32767 bytes or 86 members, in an initialiser; a struct's compound literal initialising a global, which `cc` takes as an extension |
| types, 6.2.5 | **`_Bool`** (113 uses in CPP), **`enum`** (7 types), **`union`**, **`long long`** (behind `uintmax_t`; the `LL` suffix is refused), `short`, `signed char` as its own type, `float`, `double` and `long double`, bit-fields, a function returning a `char` (refused by name) |
| qualifiers, storage and specifiers | `volatile`, `restrict`, `inline`, `_Noreturn`, `_Alignas` and `_Alignof`, `_Thread_local`, each reserved and refused by name; a qualifier after a `*` other than `const` |
| functions | a variadic function *defined* (`va_list`, `va_arg`), a ninth parameter or a struct needing a ninth register, a struct passed through `...` |
| lexical, 6.4 | **the escapes `\r` `\t` `\v` `\f`** in a character constant (CPP's `lexer.c` and `source.c` stop there), hex escapes, adjacent string literals joined, a `\0` inside a string, the prefixes `L`, `u`, `U` and `u8` on a string or a character constant, universal character names, floating constants |
| expressions | `_Generic`; and one fix, **`?:` takes its `const` levels from its first arm only**, so `*(c ? p : q) = 1` with `q` a pointer to `const` is accepted where `cc` refuses it. A refusal missing, never a false one; the notation has no direct way to combine the two arms' levels a character at a time |
| refused by name, by choice | the four optional features above; an address with an offset in a global's or a `static` local's initialiser, until one folds |

**The declarations row came first**, because most of the rest is written
in it, and it was [6.12](COMPLETED.md#612-declarations-as-c11-67-has-them).
What it left behind is the two rows CPP's source needs most: **initialisers
in braces**, which its five `static` arrays want and which an array whose
size its initialiser gives is part of, and **function pointers**, which its
diagnostic callback wants and which 6.12 parses and refuses. Either is the
next entry, chosen as the others were, by what breaks without it:
initialisers were, as [6.13](COMPLETED.md#613-initialisers-as-c11-679-has-them),
because CPP's source writes thirty and function pointers need them too.
**Function pointers are what is left of the two**, and the one place an
initialiser in CPP's source still stops. They were the next entry,
[6.14](COMPLETED.md#614-pointers-to-functions), opened and closed on
2026-10-01. **What Proem's source wants next is the types row**: `_Bool`
113 times, then `enum`, `union` and `long long`. Counted again on
2026-10-01 in `~/Projects/Proem`, `lib/` and `driver/`: `bool` 143 times,
`enum` 9, `long long` 4, and no `union`, `short` or floating point; the
integer types are the next entry, [6.15](#615-the-integer-types).

**Outside the grammar**, the rest of the chain belongs to the later arc,
which waits for the compiler as above, and the toolchain document has its
order: the **second target**
([6.11](#611-a-second-target-elf-under-aapcs64), parked), CPP put in
`cc -E`'s place, and an assembler and a linker that run on Ouroboros, the
first of which waits on whether Futamura can describe how an arm64
instruction is encoded. Past correctness, the lcc route (an IR,
instruction selection and a register allocator in place of the stack
machine) is the toolchain document's last step and belongs to it.

### 6.11 A second target: ELF under AAPCS64

*Parked on 2026-09-29, the day it was opened: the C compiler is completed
first, and this entry is the first step of the arc after it, which starts
only when Hans is satisfied with the compiler itself. Nothing below has
been built, and the oracle was tried by hand only.*

The destination is C written on Ouroboros, and the first step of
[its order](../../docs/c-compiler-toolchain.md#the-order) is this one:
**the back end writes for Ouroboros as well as for the Mac**, checked
against clang under QEMU. The toolchain document put it before any
construct, because every construct added before it is one more thing done
twice, once for each target. The C11 arc was put first anyway, knowing
that cost: every construct it adds is one more this entry must carry to
the second target. `%driver arm64` stays what it is, and `cc` stays its
oracle.

**What writing the witness found first: Phoenix's output is refused by the
ELF assembler, and once that is fixed by hand, it runs and is wrong.** One
program, calling `printf` with three numbers, the last of them a comparison
on a `char` holding 200:

| program | clang for `aarch64-unknown-none`, under QEMU | Phoenix today |
| --- | --- | --- |
| `char c = 200; int main(void) { printf("%d %d %d\n", 1, 2, c > 0); return 0; }` | prints `1 2 1`, exits 0 | `clang --target=aarch64-unknown-none -c` refuses it at six places: `@PAGE` twice, `@PAGEOFF` twice, and the Mach-O names of two sections |
| the same `.s` with only those spellings rewritten by hand, `_main` to `main`, `L` to `.L` | | assembles, links, runs, and **prints `0 0 0`** |

The second row is the one that matters, because nothing refuses it. It is
two wrongs, and either one alone would print a wrong line. **The variadic
arguments** are on the stack, where Apple's variant puts them, and
picolibc reads them from `x1` to `x3`, where AAPCS64 as written does.
**The `char`** is loaded with `ldrsb`, so 200 is -56 and `c > 0` is 0;
plain `char` is unsigned under AAPCS64, and clang loads it with `ldrb`.

**The target reaches `c.phx`, which says it has nothing about any target.**
Two facts in the language file are Apple's: the `constants` pass folds a
cast to `char` by putting the sign back, so `(char)200` is -56 in a `case`
label, and `signed char` is read as a plain `char` because *a plain `char`
is signed on this machine*. Under ELF those are two types and the fold
keeps 200. Only the signedness of `char` crosses; the rest of the
difference is spelling and the calling convention, which are the emit
pass's.

**How the oracle runs, tried by hand on 2026-09-29.** Nothing in the
Makefile of Ouroboros is needed, and the OS is not booted. A program is
compiled by clang with `--target=aarch64-unknown-none -mstrict-align`, or
by Phoenix and assembled by clang, and linked by the `rust-lld` that
`rustup` installs, against picolibc 1.8.9 as Ouroboros prebuilt it,
compiler-rt's two 128-bit shifts from Ouroboros's `libc/pico/builtins.c`,
and a harness of three short files: a start that sets the stack, turns on
the floating point registers `printf` touches, and calls `main` and then
`_exit`; a port that puts `stdout` on the PL011 UART of QEMU's `virt`
machine and makes `_exit` a semihosting `SYS_EXIT_EXTENDED`, so the status
reaches the shell; and a link script at `0x40080000`.
`qemu-system-aarch64 -M virt -semihosting -kernel` runs it. clang's program
above printed `1 2 1`, and one returning 7 exited 7. **It is an optional
oracle**, skipped and not failed without QEMU, `rust-lld` or picolibc, as
`fpc`, `solas` and `z80asm` are, so the suite still needs nothing outside
this repository. picolibc is read where Ouroboros keeps it and never
written there.

**How much it touches.** Every one of the oracle's 266 programs has a
`main`, so every one changes. 30 of them take an address with `@PAGE`
today, 20 call `printf`, and 78 have a `char`.

**Built in three parts, in this order**, each with the suite green:

1. **The harness and the spellings.** The oracle's runner learns a second
   target, and the emit pass writes, for it, names without the underscore,
   local labels with `.L`, `adrp` with no suffix and `add` with `:lo12:`,
   and ELF's section names. **How a description says which target is the
   first thing this part settles**: `phx` has no option that reaches a
   pass, so the target is chosen by a driver, `%driver elf` beside
   `%driver arm64`, and whether that driver names a small pass that the
   emit pass reads, or a second emit pass, is decided with the witnesses
   in hand. The witnesses are every oracle program without a `printf` or
   a `char`, which should agree once the spellings do.
2. **Variadic arguments in registers**, AAPCS64 as written: a call to a
   function declared with `...` passes its variadic arguments as it passes
   the named ones, in `x0` to `x7` and then on the stack. The twenty
   `printf` programs are the witnesses, the first of which is the one
   above with its `char` taken out.
3. **An unsigned plain `char`**: `ldrb` and not `ldrsb`, `and` and not
   `sxtb` when a value is narrowed, a fold in `c.phx` that keeps 200, and
   `signed char` a type of its own. The 78 `char` programs are the
   witnesses, and the one above, whole.

*Not in this step:* cross-compiling anything onto Ouroboros, an assembler
or a linker there, which are the order's next steps and other projects'
work; `.type` and `.size`, which the link does not need; and a third
target. **The entry closes** when every program in the oracle agrees with
clang under QEMU as it agrees with `cc` on the Mac, with none diverging on
either.

### 6.15 The integer types

The fourth entry of the C11 arc, and the types row of the map, cut to
what is integer: **`_Bool`, `enum`, `long long`, `short` and `signed
char`**, the integer types of C11 6.2.5 the subset does not have. Proem's
source writes `bool` 143 times, which `<stdbool.h>` makes `_Bool`, `enum`
nine times and `long long` four, behind its file identities; `short` and
`signed char` are what is left of C's integers and share the machinery.
Floating point and `union` are entries of their own, and Proem needs
neither. Today `short` and `_Bool` are refused by name as C11's and not
the subset's, `long long` likewise, its `LL` suffix is a syntax error, and
`enum` is read only after `enum` and a tag, to be refused.

**Four programs show what breaks without it**, kept in
`languages/c/tests/pending/` until the part that makes each agree moves it
to the oracle. Each was compiled by `cc -std=c11 -pedantic -Wall` with no
warning:

| program | `cc` | Phoenix today |
| --- | --- | --- |
| `long-long.c`: `long long`, `long long int` and `unsigned long long`, the suffixes `LL`, `ll` and `ULL`, the largest `unsigned long long`, a `long long` parameter and return, Proem's `struct { unsigned long long dev, ino; }`, and `signed char` from 200, beside `unsigned char` | exits 177, prints three lines | stops at the `L` of `9000000000LL`, on line 5 |
| `shorts.c`: `short` and `unsigned short` wrapping at sixteen bits, an array of `short` and a pointer stepping through it, a struct laid out with a `short` and an `unsigned short`, a `short` parameter and return, and a cast to `short` | exits 8, prints three lines | refuses `short` by name, on line 2 |
| `bools.c`: `_Bool` from 256, from -3, from a pointer and from a cast, `b++`, an array of `_Bool` in braces, a struct of them, a function returning one from `x % 2`, and one tested in `&&` | exits 4, prints three lines | refuses `_Bool` by name, on line 2 |
| `enums.c`: constants counted on from 0 and from a value written, one negative, one worked out from another, `LARGE = SMALL + 9`; an `enum` with a tag, a typedef of one with none, one in a block; constants as `case` labels, as indices and in an initialiser; an `enum` as a member and a parameter; and **its type**: an `enum` with no negative constant is `unsigned int` in this `cc` and one with a negative constant is `int`, which C11 6.7.2.2p4 leaves to the implementation, while the constants are always `int` | exits 9, prints three lines | stops at `{` after `enum color`, on line 2 |

**Built in four parts, in this order**, each with the suite green:

1. **`long long` and `signed char`**, each the width of a type already
   here, `long` and `char`, and a type of its own in name: the words
   counted as the types 6.7.2p2 lists, the suffixes `LL` and `ULL` in a
   constant, with 6.4.4.1's table for them. `long-long.c` is the witness.
2. **`short`**, two bytes, signed and not: a load that sign- or
   zero-extends a half-word, a store of one, `.short` in data, the
   `constants` pass wrapping at sixteen bits, and a struct's layout
   aligning one at two. `shorts.c` is the witness.
3. **`_Bool`**, one byte, unsigned, and **0 or 1 whatever it is given**,
   C11 6.3.1.2: every conversion into one, an assignment, an
   initialiser, an argument, a `return`, a cast and an update, is a test
   against zero and not a truncation, which is the part's question: each
   of those places converts today by narrowing, and each must learn the
   one conversion that does not. `bools.c` is the witness.
4. **`enum`**, C11 6.7.2.2: a tag and its constants as a specifier, as a
   struct's are since 6.12, each constant an `int` the `constants` pass
   works out, in the ordinary name space and the scope it is written in,
   so a `case` label and an initialiser take one; and an `enum` object an
   `unsigned int` or an `int` as this `cc` chooses. `enums.c` is the
   witness.

**What `cc` refuses, and so will this**, each checked with `cc -std=c11
-pedantic-errors` on 2026-10-01: an enumerator declared twice, or named
as something else already is; one past an `int`'s range, which is C23's;
an `enum` defined twice in one scope, and one declared without its list,
which C11 does not forward-declare; an assignment to a constant, or `&`
of one; one worked out from what is not a constant; `long long long`,
`unsigned _Bool` and `short long`.

*Not in this step:* an array's size worked out from a constant expression
rather than written as a number, `int t[BLUE]`, which every declarator
here reads as a number and which waits for an entry of its own; bit-fields;
`union`; and floating point. **The entry closes** when the four programs
agree with `cc`, none diverging, and every refusal above has its program
in `refused/`.
