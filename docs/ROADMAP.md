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
expression operators, was opened and closed the same day.** **Open:
[6.4](#64-the-statements), the statements C has and the subset does not, and
[6.5](#65-constant-expressions), expressions worked out before the program
runs**, which `switch` is the first thing to need. They are built in the
order 6.4 without `switch`, then 6.5, then `switch`.

**What Phoenix cannot say today, so that the step is honest about what it
avoids.**

| | |
| --- | --- |
| `x * y;` | a declaration if `x` is a typedef, a product otherwise. The scanner cannot ask the parser and the parser cannot ask a pass, so the parse cannot know. [3.3](#33-guessing-the-lexicalsyntactic-seam) refused scanner feedback with the words *if this ever comes up twice*; awk was the first, and C's `typedef` would be the second, with the difference that awk's guess is lexical and C's is a **scope** the parse itself is building. A semantic predicate on the identifier rule is the PEG answer, and it is a change to the tool. *Answered 2026-09-23 by `%names`*, [1.8](COMPLETED.md#18-names-the-parse-keeps) |
| `#include`, macros, `#if` | a language on the token stream, expanded and rescanned. Not a grammar and not a tree walk, so no place for it in a description. `cc -E` supplies it until the workspace has its own |
| a machine | every backend here emits C, an outline, or `.sob` bytes. None emits an instruction sequence for a real processor; `languages/solvm/` and `languages/z80/` show that labels and an order the input never mentions are within reach of an emit pass |

### 6.4 The statements

The subset has `return`, `if`, `else`, `while`, `for`, blocks, declarations
and expression statements. C also has `break`, `continue`, `do`, `switch`,
`case`, `default`, `goto` and labels, and the empty statement `;`. **This is
the last gap in control flow**: after it, what keeps a C program out of the
subset is its types and its declarations, which is step four of the
toolchain document. It comes now because it depends on nothing that is not
built, and it is where the operators of [6.3](COMPLETED.md#63-the-operators)
get used the way C programs use them: `i++` in a loop header and `&&` in a
condition.

**Three programs show what breaks without it**, and `cc` compiles and runs
each. They join `languages/c/tests/oracle/` with the part that makes them
agree:

| program | `cc` | Phoenix today |
| --- | --- | --- |
| `loop-exits.c`: `break` and `continue` in `for` and `while`, a `break` in a nested loop leaving only the inner one, `do` running its body once when the condition is false, and `for (...) ;` | exits 170, prints `aabbcc` | stops at `do {`, having read `break;` as a name |
| `goto.c`: a `goto` backwards to make a loop, one forwards out of two nested loops, and one over a statement that never runs | exits 35, prints `23` | stops at the `:` of the first label |
| `switch.c`: several `case`s on one statement, falling through, `default` in the middle, `break` and `continue` inside a `switch` inside a loop, a `char` case and a negative one | exits 142, prints `zo.o.df.fdf` | stops at the `{` after `switch (c)`, having read it as a call |

**What writing them found: the keywords are not reserved yet.** Phoenix
reserves a word when a syntactic rule has it as a literal, and none has
`break`, `continue`, `do`, `switch`, `case`, `default` or `goto`. So `break;`
is an expression statement naming a variable, and `--driver check` says
`'break' is not declared`; `switch (c)` is a call to a function named
`switch`. Each becomes reserved the moment a rule names it, which is what
C11 6.4.1 says it always was.

**Built in three parts, in this order**, each with the suite green:

1. **`break`, `continue`, `do … while` and the empty statement.** A loop
   hands its labels down, so a `break` jumps to the innermost loop's end and
   a `continue` to where it continues. **In a `for`, that is not the top**:
   `continue` runs the step first, and the step is emitted today straight
   before the jump back with no label of its own, so it gains one. *Built
   2026-09-25*: `loop-exits.c` and four more agree with `cc`. **The labels
   could not be the loop's numbered ones**, because a node takes its number
   on the way out and the `break` is in the body, compiled before that; they
   are named from the loop's line and column instead, which are known on the
   way in, as `awk-c.phx` names a rule.
2. **`goto` and labels.** A label is a name and a `:` in front of a
   statement, and has to be tried before an expression statement, which
   would read the name and fail at the `:`. Labels are **scoped to the
   function**, not to the block, and in **a name space of their own**, C11
   6.2.3, so `x: x++;` is legal C. Two functions may use one label name, so
   the assembler's label is the function's and the name's together, and a
   `goto` may name a label further down, which the `locals` pass has not
   read yet: the labels are gathered on the way out and handed down, the
   way `sigs` is for calls. *Built 2026-09-25*: `goto.c` and `goto-labels.c`
   agree with `cc`, the second with a label name two functions share and a
   `goto` into a block. The assembler's label is `L.function.label`: with an
   underscore between them, `f` and `x_y` would have met `f_x` and `y`. A
   refused `goto` is placed at the `goto`, where `cc` places it at the
   label's name.
3. **`switch`, `case` and `default`**, after [6.5](#65-constant-expressions).
   The controlling expression is evaluated once and promoted, and each
   `case` compared against it in turn, a chain of compares rather than a jump
   table, which is the stack machine's shape. `break` inside a `switch`
   leaves the `switch`, and `continue` inside one still means the loop
   around it. Falling through is what happens anyway when no jump is
   written, and `default` can be anywhere.

**What `cc` refuses, and so will this**: `break` outside a loop or a
`switch`, `continue` outside a loop, even inside a `switch`, a `goto` to a
label no statement has, a label twice in one function, a `case` or a
`default` outside a `switch`, two `default`s in one `switch`, and two `case`s
with one value. Each is a program in `refused/` when its part is built.

*Not in this step:* a declaration after a label, which C11 does not allow
and C23 does; computed `goto`, a GNU extension; and a `case` range, another.
**The entry closes** when the three programs agree with `cc`, with none
diverging.

### 6.5 Constant expressions

C11 6.6 says where an expression must be worked out before the program runs:
a `case` label, the size of an array, an `enum`'s value, a global's
initialiser, and the null pointer constant, which is any such expression
equal to 0. **Not one of those is in the subset yet, and every one of them is
on the way**, which is why this is an entry of its own and not a corner of
`switch`: built once, it serves the five. `switch` is the first customer.

**One program shows what breaks without it.** `constant-labels.c` has a
`switch` whose labels are `'a' + 1`, `1 << 3`, `-2 * 3`, `sizeof(int)`,
`7 > 3 ? 100 : 200` and `~0`; `cc` exits 98, and Phoenix stops at the `{` of
the `switch`, as `switch.c` does. **Writing it found the first refusal**: the
first draft had `sizeof(long)` beside `1 << 3`, both 8, and `cc` refused it
as a duplicate `case`. That program is kept as `duplicate-case.c`, and a
duplicate can only be seen by a compiler that knows both values.

**The mechanism is two attributes in the `types` pass**: whether an
expression is constant, and if it is, its value. Both are folded from the
leaves: a number, a character, whose code the pass already works out, and a
`sizeof`, which is constant whatever its operand is; then every operator
over constants, which C11 6.6p3 limits by leaving out assignment, `++`,
`--`, calls and the comma. A `case` asks for both and refuses a label that is
not constant, as `cc` does. The value has to be **C's arithmetic and not the
notation's**: an `int` result is reduced to thirty-two bits and a `/` truncates,
which is `quotient` and not `div`.

**And the notation cannot say all of it**, which is the finding this entry
exists for. Phoenix's expression language has `+ - * / div mod` and nothing
bitwise, and an integer that overflows is an error rather than a wrap,
[semantics.md](semantics.md). Three of C's operators fold anyway: `~x` is
`-x - 1`, `x << k` is `x` times a power of two from a table, and `x >> k` is
`x div` that power, because `div` floors and a floored division by a power of
two is exactly an arithmetic shift. **`&`, `|` and `^` have no such
spelling.** There are two ways out, and the entry is the choice between them:

- **Refuse them by name** in a constant expression, so `case FLAG_A | FLAG_B:`
  is not in the subset. Nothing changes in the tool, and C that `cc` compiles
  is turned away.
- **Add them to the notation's library**, as three functions next to
  `quotient` and `remainder`. That is a change to the tool, and so to
  [semantics.md](semantics.md), whose every sentence is a check, and to the
  runtime a description written out with `-o` carries. It is the first thing
  the C arc has asked of the notation since `%names`.

**The entry does not settle it.** [1.7](#17-a-repetition-that-counts) sets a
rule for a mechanism, *one is a workaround; two is a mechanism*, and the C
description is one customer. Against that, three functions are arithmetic,
the kind of thing `quotient` and `remainder` already are, and not a new form
of the notation the way a counted repetition would be. The choice is made
when 6.5 is started, and written here first. A long constant that would overflow
the notation's own integers, `9223372036854775807 + 1`, is the other edge:
C calls it undefined, and here it would stop the compiler with an arithmetic
error rather than a message, so the fold refuses it by name first.

**The entry closes** when `constant-labels.c` agrees with `cc` and
`duplicate-case.c` is refused. The null pointer constant, array sizes, `enum`
and global initialisers each come with their own construct, and read the
same two attributes.
