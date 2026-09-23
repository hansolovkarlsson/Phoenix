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
document has the order of the whole arc. This entry has the first step, and
copies nothing else from it.

**What Phoenix cannot say today, so that the step is honest about what it
avoids.**

| | |
| --- | --- |
| `x * y;` | a declaration if `x` is a typedef, a product otherwise. The scanner cannot ask the parser and the parser cannot ask a pass, so the parse cannot know. [3.3](#33-guessing-the-lexicalsyntactic-seam) refused scanner feedback with the words *if this ever comes up twice*; awk was the first, and C's `typedef` would be the second, with the difference that awk's guess is lexical and C's is a **scope** the parse itself is building. A semantic predicate on the identifier rule is the PEG answer, and it is a change to the tool. *Answered 2026-09-23 by `%names`*, [1.8](COMPLETED.md#18-names-the-parse-keeps) |
| `#include`, macros, `#if` | a language on the token stream, expanded and rescanned. Not a grammar and not a tree walk, so no place for it in a description. `cc -E` supplies it until the workspace has its own |
| a machine | every backend here emits C, an outline, or `.sob` bytes. None emits an instruction sequence for a real processor; `languages/solvm/` and `languages/z80/` show that labels and an order the input never mentions are within reach of an emit pass |

### 6.1 Step one — a subset that runs, and `cc` as its oracle

`languages/c/`, in the shape [`languages/README.md`](../languages/README.md)
prescribes: `c.phx` holds the grammar, the tree and the symbols and has no
opinion about a target; `c-arm64.phx` imports it and adds one emit pass. The
target is **arm64 assembly text**, assembled and linked by `cc`, because that
is the machine under this repository and because borrowing the assembler and
linker is what every C compiler except tcc does.

**The emit pass is a stack machine.** Every expression leaves its value in
`x0`, every operand is pushed and popped, every local lives in the frame at an
offset the symbol pass assigned, and there is no register allocator. That is
chibicc's and tcc's shape, it is what `examples/asm.mx` in Metaxis sketched for
a smaller subset, and it is the route the workspace document names first. The
output is slow and correct, and slow is not a divergence.

**The subset grows in chibicc's order**, one construct at a time with the
suite green at each: `int main(){return 42;}`; then `+ - * /` and
parentheses; unary minus and comparison; a local `int`; `;`-separated
statements and `return`; `if`, `while`, `for`; blocks; a function with
parameters and a call under the arm64 calling convention *(prediction three
is scored in [postmortem 16](postmortem.md#16-the-calling-convention-cost-the-most-and-not-for-the-reason-given))*;
`&` and `*`; arrays and
`sizeof` *(done 2026-09-22, indexing and the difference of two pointers
last; ninety-nine programs against `cc`, twenty-five refused and two
divergences pinned)*; **`char` and string
literals** *(done 2026-09-22; 123 programs against `cc`, and the oracle
compares what they print as well as how they exit)*; **`struct`** *(done
2026-09-22, which completes the list; 143 programs against `cc`, 49
refused)*. It stopped before `typedef`
on purpose, because that was where the tool was expected to need a change,
and the change was to arrive with the construct that wanted it and not
before. *It did, on 2026-09-23*: see step two below.

**The width, decided 2026-09-22: `sizeof(int)` is 4, and `int` narrows to
thirty-two bits.** Until that day the value was sixty-four bits wide in a
register C calls a 32-bit `int`, left open on 2026-09-21 with the note that
the oracle would settle it at `char`. It was settled two constructs earlier
and by a program that had been available since the second construct:
`int a = 2000000000; int b = a + a; return b / 1000000;` exits 218 under `cc`,
which wraps at thirty-two bits, and 160 here, which does not. A 64-bit `int`
would have been a **conforming** implementation, the standard asking only for
sixteen bits, so this was a choice and not a defect; what it would have cost
is `cc` as the oracle for everything size-shaped, which is `sizeof`, `struct`
offsets and array layout, or in other words the rest of the arc.
[postmortem 17](postmortem.md#17-left-to-the-oracle-is-not-a-decision-until-somebody-writes-the-program)
scores the expectation and the journal has the reasoning.

*Built the same day.* The emit pass picks `w` or `x` from the star count the
`types` pass already had, which came to nine clauses and a table with one row
in it. On this machine `w0` is the low half of `x0` and every write to a `w`
register zeroes the upper half, so the stack machine, the calling convention
and the frame were all unchanged; a scalar keeps its eight-byte slot and is
stored into it with `str w0`. `tests/oracle/overflow.c` went from 160 to 218,
and two programs were added that a **half-finished** narrowing fails, which
was checked by half-finishing it on purpose.

*`sizeof` came next, the same day, and wanted nothing.* A star count already
says how many bytes a value takes while `int` is the only base type, so the
two `sizeof` shapes read that table for its other column and the `types` pass
did not grow. What `sizeof` did want was a decision: C11 6.5.3.4 makes it
worth a `size_t`, `size_t` is a **typedef**, and this arc stops before
`typedef` on purpose, so it is worth an `int` here and
`tests/divergent/sizeof-of-sizeof.c` pins the one program that shows the
difference, 8 against 4.

*An array's declaration, size and decay went in the same day, and the frame
moved with them.* `int a[10]` is forty bytes and no slot holds forty, so a
local now lives at a **byte offset** rather than in a numbered slot, which is
the first time a declaration's type reached the frame. A name that is an array
decays to a pointer to its first element, C11 6.3.2.1, everywhere except under
`sizeof`, which is why a node answers a `type` that decays and a `size` that
does not.

*Indexing closed the item, the same day.* A subscript is C11 6.5.2.1's
`*((E1)+(E2))` built by the grammar action and no node of its own, and
`sxtw` arrived where predicted, inside one `add` that sign-extends the index,
scales it by the element and adds it to the pointer.

*The difference of two pointers, decided the same day: an `int`.* C11 6.5.6
makes it a `ptrdiff_t`, which is a typedef, so it was the `sizeof` question
again and got the `sizeof` answer. It is also what K&R's first edition said
the difference was, before ANSI C gave it a name.
`tests/divergent/sizeof-a-pointer-difference.c` pins the one program that
shows it, 8 against 4. **Both are to be revisited when `typedef` arrives**,
together: `size_t` and `ptrdiff_t` are the two typedefs this subset already
owes an answer to.

*`struct` closed the list, the same day.* Tagged, at file scope, with `.`
and `->`, arrays of structs, structs in structs, and a pointer from a struct
to its own kind, which is what a list is made of. Members are laid out by a
thread in the `locals` pass, each at the next offset its alignment allows,
and the struct rounded to its widest member, so `cc`'s `sizeof` is this
subset's. A declaration's base became the node the standup expected a type to
become: `int`, `char` and a tag are all looked up in one table of layouts. A
type stayed numbers, three of them now, the tag being the third.

What is **not** here, and each is a refusal or a syntax error rather than a
wrong answer: a struct defined in a function, or with no tag; and a pointer
to a struct nobody defines.

*A struct copied whole, done 2026-09-23*, by `=`, by an initialiser and as
an argument. A copy is a byte loop in the emitted code rather than a store
or a call to `memcpy`, and nothing in `phoenix/` changed for it. An argument
follows AAPCS64: up to sixteen bytes in one register or two, and anything
larger copied by the caller and passed by address. That is held against
`cc`'s own code by `tests/abi/`, where a caller and a callee in two files
are compiled by each compiler in turn, because the oracle can only ever see
Phoenix agree with itself. A copy between two kinds of struct is refused,
and so is a struct anywhere C wants a number: nine such programs, all of
which `cc` refuses, **compiled** until that day into the struct's address,
in a pass whose header says it refuses whatever it would otherwise
mis-compile. 175 programs against `cc`, 73 refused.

*A struct returned, done the same day*, and AAPCS64 again: up to sixteen
bytes packed into `x0` and `x1`, and anything larger written by the callee
where the caller's `x8` points, the caller giving it a place in its frame
either way so that a call is worth the struct's address, as any struct is.
A function that returns a large struct keeps `x8` from its prologue, since
a call in its body may use `x8` for one of its own; that has one witness in
the oracle and one in `tests/abi/`, which now links returns in both
directions as well as arguments. A function's return type became a `base`,
so a `char` or a pointer returned is refused by name, since nothing here
narrows or widens what comes back, and so is `main` returning a struct. A
member of a call is a value, as a member of an assignment is. 185 programs
against `cc`, 82 refused.

**The oracle is `cc` itself**, the way `fpc` is Pascal's and `/usr/bin/awk` is
awk's. `tests/oracle/` holds programs compiled twice — once through `cc` and
once through Phoenix's output through `cc` — and their standard output and
exit status compared. Nothing in this arc has a hand-written expected result.
`tests/refused/` holds what must not compile, with the message, once the
subset has anything to refuse. There is no vendored grammar and no need of one:
the subset is described directly, and the C11 grammar in Annex A is what to
check the description's *shape* against when it is large enough to matter.

**What it borrows, written down so the borrowing is visible**: `cc -E` for
anything with a `#` in it, which the first dozen constructs do not need; `cc`
to assemble and link, and the assembler to turn a string literal's escapes
into bytes, which the notation cannot do; the system libc, reached through a
`puts` or a `putchar` declared in the program rather than included, until the
preprocessor exists. *Not `printf`, since 2026-09-22*: it is variadic, and
Apple's arm64 passes variadic arguments on the stack rather than in
registers, which is a calling convention this subset does not have.

*The predictions, for [postmortem.md](postmortem.md) to score.* One: the
subset reaches `struct` with **no change to the tool** — `%import`, the symbol
pass, `thread` for frame offsets and one emit pass are enough. Two: the first
change the tool needs is the typedef predicate, and it is wanted at `typedef`
and not before. Three: the arm64 calling convention costs more than any
construct before it, because it is the first place the emit pass has to know
something the tree does not say. Each of these can be wrong in a way the
journal would record.

*The condition for the next step* is the first: a subset through `struct`
whose oracle tests pass. **Met on 2026-09-22**, and with prediction one
holding: [postmortem 19](postmortem.md#19-prediction-one-held-and-the-node-went-somewhere-else)
scores it. Steps two to seven live in the workspace document and
are not repeated here; the one that comes back to this page is the predicate,
which will be an entry under section 1 with the failure written down first, as
this page requires.

**Step two, `typedef`, done 2026-09-23**, and with it the predicate:
[1.8](COMPLETED.md#18-names-the-parse-keeps), whose failure was measured on a
copy of `c.phx` before the tool was touched. Prediction two held, and
[postmortem 20](postmortem.md#20-prediction-two-held-and-the-predicate-was-a-table)
scores it. A typedef names a base and some stars, a struct's included, at
file scope, and an ordinary name declared in a block or as a parameter hides
it until that scope ends. 156 programs against `cc`, 58 refused.

*`size_t` and `ptrdiff_t`, revisited as promised, stay `int`s.* `typedef`
gives C a way to name them and gives this subset nothing to name them as:
both are `long`s on this machine, and `long` is step four of the workspace
document. The two divergent programs stay pinned.

What is **not** here, each a refusal or a syntax error: a typedef in a block,
as a struct is at file scope only; a typedef of an array, whose count belongs
to a declaration here and not to a type; and a local named in its own initialiser,
`int x = sizeof(x);`, because the `locals` pass binds a name at the end of its
declaration and C at the end of its declarator. That last one was always so,
and `typedef` gave it a second spelling. A typedef as a function's return
type was a fourth until the same day, when a struct could be returned and a
function's return type became a base.


*Why this entry stays open, decided 2026-09-23.* Every construct step one
listed is built, and so are `typedef`, a struct copied whole and a struct
returned. What is not built is the answer to the two divergences pinned in
`tests/divergent/`: `sizeof` and the difference of two pointers are `long`s
under `cc` and `int`s here, and `long` is step four. Moving 6.1 to
[COMPLETED.md](COMPLETED.md) now would leave those two pins with no entry,
or split one entry across both halves of the ledger. It moves when `long`
arrives and the two programs agree.
