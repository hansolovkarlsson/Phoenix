# Journal

*Why each decision was made, in the order it was made, so that undoing one is
informed rather than archaeological. The staging exists to be retreated
through; this is the map for a retreat.*

---

## 2026-09-01 — what Phoenix is

The first framing was wrong and worth recording as wrong. Phoenix looked like
"lex/yacc that emits Solveig", and that reading survived about one exchange.

The actual complaint is not about `lex.c + parser.c + tokens.h`. It is that
lex and yacc solve the *front* of the problem and abandon you at the AST: after
the parser you still hand-write forward-declaration collection, type checking,
optimisation and code generation, four large modules that are largely traversal
boilerplate, written again for every language.

So the claim Phoenix is making is:

> **A compiler is a grammar plus a sequence of tree walks, and Phoenix is a
> notation for both plus a driver that runs them in order and reports.**

The grammar half is the part everyone already builds. The pass half is the part
nobody does well, and is the reason for the project.

## 2026-09-01 — the meta-language will be attribute-shaped

Three shapes were on the table for what an action is:

1. **Solveig, spliced verbatim** — yacc's bargain with C. Nothing to design,
   and the actions are string concatenation in a language with no operators.
2. **A notation Phoenix owns**, with two backends: interpret it, or compile it
   to Solveig. One description, two ways to run it.
3. **An evaluator shipped inside the generated compiler**, interpreting an
   action table at run time.

(2), because it is the only one where the phrase "built-in interpreted
evaluator language" does any work, and because the interpreted backend is what
makes a language cheap to iterate on before any code is generated.

The shape is Knuth's **attribute grammars** — `->` names the node a production
builds, `%pass` holds clauses keyed by node type, `=` defines a synthesised
attribute, `down` an inherited one, `!` raises a diagnostic, `%driver` orders
the passes. JastAdd and Silver are the living implementations, so the
attribute-scheduling problem is lifted rather than invented.

**The known weakness, recorded before it bites.** Attribute grammars suit type
checking and code generation and are awkward for exactly the two passes named
first: forward declarations want to mutate a table across the whole tree, and
optimisation wants to *rewrite* the tree rather than decorate it. Those probably
want a second mechanism — rewrite rules with a declared strategy. Two mechanisms
is a cost, and it is better to discover it is needed than to design it up front,
so it is deferred until a real pass demands it.

## 2026-09-01 — `phx` is C11

Weighed against writing `phx` in Solveig, which would have had one genuine
advantage: the interpreted backend and the generated backend would share one
semantics, and in this design they *must* agree.

C won on the other three counts — standalone binary, no bootstrap, no recursion
ceiling on a tree-walker, better debugging. The cost is accepted knowingly and
written down here so that the first divergence bug between the C interpreter and
the generated Solveig is recognised as this decision arriving rather than as a
surprise.

## 2026-09-01 — stage 0

The grammar half. Wirth's notation plus the older angle-bracket dialect, the
lexical/syntactic seam, longest-match scanning, a PEG over tokens, a tree.

**Three things were built that were not planned, each because a test asked.**

*The scanner recovers.* It stopped at the first character no rule matched.
Solveig's `lexical.pas` — two stray characters on two lines — carries a comment
arguing that both should be reported, because *a scan that stops at the first
tells you least about the file you know least about*. It now takes the
character and carries on, and fails at the end.

*A literal nothing spells is a grammar error.* A test grammar named `","` in the
syntactic half with no token rule producing a comma. That rule can never match,
and the way it failed was a syntax error on a correct file, at the comma, saying
it expected a comma. Every literal in the syntactic half is now checked against
the scanner when the grammar is read.

*The unused-rule warning had to learn about token rules.* It fired on
`symbol = ";" | ...`, which nothing names — because a token rule is reached by
its *spelling*, not by its name. Warning about those is noise.

**And one thing was got right by borrowing.** `%fragment` came straight from
`check_syntax.sol`, which learned it the hard way: the first Pascal file it read
came back as a stream of `letter` and `digit`, because longest-match ties break
by declaration order. The trap was known before it was walked into, which is the
whole value of the prior art being in-house.

## 2026-09-01 — what self-hosting would and would not prove

Raised as a question and worth writing down carefully, because the loose answer
("Phoenix could describe itself") conflates three different things.

**Level 1 — the notation describes its own grammar.** Real, and easy. A `.phx`
file's format is expressible in `.phx`, which is Wirth's own argument for the
notation. It would replace the hand-written reader in `grammar.c` and nothing
else.

**Level 2 — Phoenix generates its own front end.** Real, once stage 5 exists.
`phoenix.phx` generates a program that reads `.phx` files, with resolution and
the checks written as `%pass` blocks; `phx` the C binary would then be needed
only to bootstrap, and a generated `phoenix.sol` would be kept in the repository
the way every self-hosting compiler keeps a bootstrap artifact.

**Level 3 — Phoenix generates all of itself.** Not real, and not a failure. The
PEG matcher and the longest-match scanner are the engine that *runs* a grammar
rather than anything derived from one, so they would ship as a runtime beside
the generated code. Every compiler generator does this; a self-hosting C
compiler still links a runtime.

**Self-hosting is a test, not a feature.** A Solveig Phoenix would be slower and
bound by SolVM's limits — strictly worse as a tool. What it buys is a
completeness argument: a notation that can describe its own compiler
demonstrably has enough in it.

**And the place it should be expected to fail is the interesting part.**
Left-recursion detection is a Warshall closure over a rule *graph*, not a walk
over a tree. If `%pass` can only express tree traversals it cannot express
Phoenix's own checks — and that limit is not peculiar to Phoenix. Dataflow
analysis, call graphs, register interference and alias analysis are all graph
algorithms wearing a tree costume. Attempting level 2 would say early whether
`%pass` needs an escape hatch for passes that are not tree walks.

It would also be the sharpest available probe of the divergence risk taken on
knowingly when `phx` was made C rather than Solveig: the two implementations of
the meta-language must agree, and self-hosting is where disagreement surfaces.

## 2026-09-01 — stage 1

`->` says what an alternative builds. Three decisions, one of which was not
planned and is the best thing in the stage.

**Positional and named references, both.** `$n` is terse and familiar and is
yacc's worst ergonomic flaw — `$3` drifts silently when a factor is inserted
before it. Labels (`e:expression`, then `$e`) survive editing. Rather than
choose, both are read, and **both are checked when the grammar is read** rather
than when a file is parsed, which turns yacc's silent wrong tree into a message
with a caret under the `$5`.

**`$$` folds.** The flat repetition every grammar writes for a binary operator
— `term { ( "+" | "-" ) term }` — has to become a left-leaning tree, and that is
the single most common shape in any grammar. If the notation could not say it
cleanly the notation was wrong. The rule that works: an action mentioning `$$`
*replaces* the value before it rather than following it. Precedence then comes
from the grammar and associativity from the fold, and neither had to be
declared.

**The unplanned one: interior nodes are never built.** The original plan was
that `->` builds a node and the default is the concrete tree. Making a rule's
answer depend on *how many values its body produced* — one passes through, any
other number gets wrapped — turned out to collapse `expression → term → factor
→ number` down to the number for free. That is the CST-to-AST cleanup every
hand-written tree-builder exists to perform, and it fell out of a rule chosen
for a different reason. It is one sentence in `parse.c` and it deleted a
feature.

**What was not needed.** No `%node` declarations, no separate AST schema. The
vocabulary is what the actions build, gathered while checking them, printed by
`--nodes`. Stage 2's passes will be keyed against exactly that, and a type built
with two different field lists is warned about now because a pass would have to
handle both.

**Unchanged, deliberately.** `pascal.bnf` has no actions and behaves exactly as
it did at stage 0 — all 22 of that stage's tests still pass untouched. A grammar
that only wants to be checked never has to learn any of this.

## 2026-09-01 — stage 2, and one thing the sketch got wrong

`%pass` works. The calculator has an `eval` pass that interprets, and `emit-sol`
and `emit-c` passes that compile, and all three answer 97.

**The sketch proposed demand-driven evaluation with memoisation, JastAdd's
approach. That was dropped while building it, and the reason is worth keeping.**

A threaded attribute needs a defined traversal order and demand-driven
evaluation has none. Once a walk has to exist for `thread` to be threaded
along, computing everything else during that same walk is simpler than being
lazy: there is no scheduling problem, no dependency analysis, and no cycle to
detect, because a node's attributes are computed strictly after its children's.
What it costs is that an attribute cannot refer *forward* to a node the walk has
not reached — which is what several passes and a `%driver` are for, and how a
hand-written compiler handles forward references anyway.

So the model is **one walk, post-order, two phases at each node**: `down`
clauses entering, children, everything else leaving.

**Three things had to be fixed that only appeared once it ran.**

*A built node's position was in the wrong file.* `Value.pos` came from the
action's position in the `.phx`, so a diagnostic from a pass pointed at the
compiler description rather than at the program being compiled. It is the
source position now, which is the only one worth pointing at.

*Checks are guards, not clauses that print.* `Variable`'s undefined-name check
fired, left `val` as nil, and then the addition above it complained about the
nil, and then every node above that complained in turn — one mistake, four
messages. A check now *blocks* its node's attributes: if one fires, they are set
to a failure rather than computed, and a failure passes through every operator
and every library function silently. One mistake, one message.

*`$body.out` had to mean something.* `$body` is a list, and there was no way to
say "that attribute of each element" without a map, a lambda, and a reason.
Reading an attribute of a list now reads it from every element, which is one
rule and removes the need for all three.

**The `.` is whitespace-sensitive, and this is the one place in the notation
where a space changes a meaning.** `$left.val` reads an attribute; `$left .`
is a reference followed by the terminator that ends a clause. No lookahead can
separate them — `. Binary(op: "+")` beginning the next clause looks exactly like
a field access — so adjacency decides, and the README says so.

**What the two emit passes proved.** They were written together, and neither
knows what language Phoenix itself emits. The conformance rule from
docs/semantics.md is now a test rather than a hope: the same `.phx`,
interpreted and through both backends, gives the same answer, and a change that
breaks one of the three fails the build.

## 2026-09-01 — Solveig parked, and C is the target

Phoenix began as a generator of Solveig compilers. It is not one now.

**The reasons given were maintenance ones and they are sound.** Solveig is still
changing, so every release is a chance to break `emit-sol` and the round trip,
and fixing that buys nothing while the meta-language is itself unstable. And
once Phoenix had its own value semantics, Solveig had stopped supplying
anything: it was a second target, not a foundation.

**The reason worth recording is a different one.** The argument for building two
backends was that two implementations which must agree will catch host
assumptions leaking into the notation. Dropping to one does not remove that
risk — it mirrors it, and *C* assumptions can leak in now instead. What makes
this safe is that the replacement was built first, in the right order:

- `docs/semantics.md` fixes the arithmetic in Phoenix's own terms, and was
  written *before* this decision rather than after it.
- The conformance test keeps two legs, and they were always the more valuable
  pair: `--run eval` is a C interpreter of the notation, `--run emit-c` is
  generated C, and they are two independent implementations that must both
  answer 97.

So the discipline moved from *two backends disagree* to *the spec says, and the
interpreter checks*. Losing the third leg is a real loss and a small one.

**The dependency that actually mattered was not the backend.** `make test` read
`pascal.bnf` and its fixtures out of a sibling checkout, which is the kind of
dependency that breaks a test suite for reasons having nothing to do with the
project being tested — reorganise Solveig, and Phoenix fails. Those are fixtures,
not a library, so they are vendored into `tests/pascal/` and the suite now passes
with Solveig absent from disk, which was checked rather than assumed.

**Going back is writing an emit pass, not changing Phoenix.** The language a
compiler emits was never Phoenix's business; it lives in the `.phx`.
`examples/calc-solveig.phx` still holds those clauses and is still *read* by the
suite, so the notation cannot drift out from under it, and
`PHX_TEST_SOLVEIG=1 make test` runs the round trip. The only place "C only" is a
genuine narrowing is stage 5's own backend — what a generated compiler is
*written* in — and that is Phoenix's code rather than anybody's `.phx`.
