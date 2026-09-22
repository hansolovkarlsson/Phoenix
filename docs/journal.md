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
not a library, so they are vendored into `languages/pascal/tests/grammar/` and the suite now passes
with Solveig absent from disk, which was checked rather than assumed.

**Going back is writing an emit pass, not changing Phoenix.** The language a
compiler emits was never Phoenix's business; it lives in the `.phx`.
`languages/calc/calc-solveig.phx` still holds those clauses and is still *read* by the
suite, so the notation cannot drift out from under it, and
`PHX_TEST_SOLVEIG=1 make test` runs the round trip. The only place "C only" is a
genuine narrowing is stage 5's own backend — what a generated compiler is
*written* in — and that is Phoenix's code rather than anybody's `.phx`.

## 2026-09-01 — exhausting stage 2 on the calculator

The calculator grew comparisons, `if`, `else`, `while`, blocks and assignment,
plus a `typecheck` pass — which is the first time stage 2 has been asked to do
one of the four jobs this project exists for. **Five things broke, and every one
of them was worth the trip.**

**Two clauses for one pattern silently did nothing.** `Block` appeared twice in
`emit-c` — once for `down indent`, once for `out` — and first-match-wins meant
the second was never reached. The symptom appeared elsewhere, as a node missing
an attribute that a perfectly good clause defines. It is the same hazard as
`"<" | "<="` in the lexical half, one level up, and it now gets the same
treatment: a subsumption check over each pass's clauses, refusing a general
pattern written above a specific one. An error rather than a warning, because
there is no reading under which it was meant.

**A repetition matched once was not a list.** `{ statement }` gave a list for
zero or two statements and a bare node for exactly one, so `$body.out` was text
in a one-statement block and `join` failed on it. The `.phx` author cannot know
how many statements a block will hold — but the *grammar* knows the count is not
fixed, so a repetition and an option now yield a list always, of whatever length
they turned out to be. Decidable from the grammar, which is the property that
matters.

**The interpreter has a boundary, and it is not a bug.** An attribute is
computed once per node in one walk. A `while` needs its body evaluated a number
of times that depends on the program, and a branch not taken must leave the
variables alone. Neither is expressible. So `eval` works on straight-line
programs and says so where a program runs into it, rather than failing
obscurely. Interpreting is for checking a language while it is being designed;
compiling is what Phoenix is for.

*That costs something and it should be said plainly.* When Solveig was parked,
the claim was that `--run eval` against `--run emit-c` keeps the conformance
rule honest. It does — for straight-line programs. Anything with a loop is now
checked by one backend only. `%import` is what makes a second one cheap again,
which is a better argument for it than the tidiness one.

**And the divergence docs/semantics.md was written to prevent happened anyway,
in the example.** `0 - 7 / 2` gave -4 interpreted and -3 compiled: `eval` used
Phoenix's `div`, which is floored, and C's `/` truncates. The bug was in
`calc.phx` rather than in Phoenix — **the calc language had never said what `/`
meant**, so each pass borrowed its host's answer, which is precisely the page's
headline.

Fixing it needed something the library did not have. Truncation cannot be
written in terms of flooring in a notation with no conditional, so `quotient`
and `remainder` were added — and they earn their place by the rule at the top of
`library.c`: target languages disagree with each other about negative division,
and a pass that models one of them has to be able to say which. There is a test
with a negative number in it now, so this cannot come back quietly.

## 2026-09-01 — %import, and what to call a `.phx`

**The naming, settled because the docs say it on every page.** A `.phx` file is
a **description** — it describes a language, and Phoenix turns a description
into a compiler. It is not a program, since nothing runs it, and it stopped
being a grammar when it grew passes. Spoken of as a unit — importable, one of
several, in a directory — it is a **module**. A module with a `%start` stands on
its own and one without is only ever imported, which is the whole distinction;
there is deliberately no word for the partial kind, because *fragment* is spoken
for by `%fragment` and a second meaning would be a trap.

**The split `%import` makes possible is not grammar-versus-passes**, which is
where the idea started. It is *the language* against *the target*: the grammar,
the tree, the typechecker and the interpreter all belong to the source language
and have no opinion about C, so only the emit pass is per-target.
`calc-solveig.phx` went from ninety lines of duplicated grammar — quietly wrong
the first time `calc.phx` changed — to an emit pass and a line naming the
language.

**Two things had to change underneath, and one was not foreseen.** A position
was an offset into one file; with imports it has to name which file. The files
are held end to end in one buffer with a map saying which stretch came from
where, so an offset stays a single number and everything downstream keeps
working unchanged while getting the right filename and the file's own line
numbers.

The unforeseen one: `grammar_check` refused a description with no syntactic
rules. That was right when a description was always a whole thing and is wrong
now — `lib/lexical.phx` is exactly that and is *meant* to be imported. The check
moved from *reading* a description to *using* one, which is where it belongs:
having nothing to parse with is only a problem when something asks you to parse.

**What earns a place in `lib/`, and the rule that decides.** A pass is only
reusable together with the grammar that produces the nodes it keys on — a pass
naming `Binary` needs something to build a `Binary`. So the natural module is a
grammar fragment *and* the passes over it, never either half alone. That is why
`lexical.phx` is all grammar and works: it is upstream of any node at all.

## 2026-09-01 — lib/expression.phx, and what building it taught

The expression module was proposed as the test of a rule stated the day it was
written: *a pass is only reusable together with the grammar that produces the
nodes it keys on.* Building it half-confirmed the rule and falsified what was
expected to follow from it.

**The rule held.** `show` — rendering an expression back to something close to
what was read, for putting inside a diagnostic — depends on the shape of these
nodes and on nothing else, and it belongs with the grammar that makes them.

**What did not hold is the expectation that there would be several such
passes.** There is one. A typechecker over these nodes needs the importing
language's type system; an emit pass needs its target. Both are the caller's, so
both stay the caller's. A `lib/` module is therefore mostly grammar, occasionally
with a pass attached — and `lexical.phx` being pure grammar is not the exception
it looked like, it is upstream of any node at all.

**And the module needed something Phoenix did not have.** An expression grammar
cannot know what a language's atoms are, which is the one thing every language
differs about. So `%require primary` declares a hole: the description reads fine
with it open, because that is what a module *is*, and is refused by name the
moment something asks it to parse a file. **A module system needs an interface
in both directions**, and the half saying what a module *needs* is the one easy
to forget.

Two checks had to learn about incompleteness. A rule named by a directive and
never defined is a mistake unless it was required. And a literal nothing spells
cannot be judged while a description has holes — `expression.phx` writes `"or"`
and the language importing it is what makes an `or` token — so that check waits
for the assembled description, which is where it belonged anyway.

**One bug only a three-deep import could show.** A file with no `%start` used to
*assign* the fallback goal rule, so `calc-c.phx` — which says nothing about a
goal — silently unsaid the `%start program` that `calc.phx` had settled. A file
that says nothing must not unsay something. The fallback now applies only when
nothing has chosen yet.

**What is still missing, and it is stage 3's.** `show` exists so that a
typechecker can write *"cannot add {} and {}" of $left.show, $right.show* — and
that needs `show` to have run before `typecheck` does. There is no way to
sequence two passes yet, so the module's one pass is written, tested and not yet
usable for the thing it is for. That is the clearest argument for `%driver` so
far, and a better one than ordering passes for tidiness.

## 2026-09-01 — stage 3

`%driver` names passes in order and which attribute of the root is the answer.
The sketch survived, which is the first time that has happened; what it did not
anticipate were three things that only appeared once passes could actually see
each other's work.

**A threaded attribute is not a node attribute, and the collision check had to
learn it.** The first driver written produced a warning that `typecheck` and
`eval` both define `env` and the later would win. They do not: `thread` is state
belonging to the *walk*, declared per pass with its own starting value, never
written where another pass could read it. Two passes threading an `env` each
have their own. The warning was wrong and the distinction is worth having a name
for.

**`$x.attr` had to read fields as well as attributes.** The check for a
misordered driver flagged `$left.text` as a cross-pass read of something nothing
defines — and it was right that nothing defines it, because `text` is a *field*.
Reading a child's field is an ordinary thing to want and was not possible: `.`
read attributes only. It now reads a field first and an attribute second, which
is the same order `$name` uses on the node being visited, so there is one rule
rather than two. The driver check skips names that are fields in the vocabulary,
since reading one is not a claim about order.

**And a pass could not read what an earlier pass left on the node it is
standing on.** `$name` resolved through bindings, fields, threads and inherited
values, and not through the node's own attributes — so reading a previous pass's
work meant going through a child, which is a strange thing to have to do to read
your own attribute. Added at position three, after fields.

**What the stage was for, working:** `typecheck`'s messages now render the
offending expression with `show`, a pass that arrived with
`lib/expression.phx` and knows nothing about calc —

```
print wants an int, and (n < (2 + n)) is bool
```

— which is exactly the thing that was written, tested and unreachable when the
expression module landed.

**One limit of the order check, stated because it is a real one.** It sees
`$x.name` and not a bare `$name`. A bare one may be a field, a binding, a
threaded attribute or an inherited one, and deciding which would mean knowing
what shapes reach the clause. So it catches a pass reading another node's work,
which is the ordinary case and the one that goes wrong, and stays quiet about a
pass reading its own.

## 2026-09-01 — actions on Wirth's Pascal

The point of doing this to Pascal rather than to another toy is that the
grammar was written by somebody else, for another purpose, years before Phoenix
existed. `languages/pascal/pascal.phx` is `languages/pascal/tests/grammar/pascal.bnf` with `->` clauses
added — the fixture is left unmodified, because three tests depend on it being
a real published grammar that Phoenix reads without being met halfway.

It works: 51 node types, both good programs building an abstract tree with no
punctuation in it, all four bad ones still refused, and an `outline` pass that
reads packed arrays, pointer types, records, sets, enumerations and `var`
parameters back out. **Five things had to change, and three of them are lessons
about the notation rather than bugs in it.**

### `$$` needs its fold and its base in one list

```
simple-expression = [ "+" | "-" ] term { op term -> Binary(op: $1, left: $$, right: $2) }
                  -> Signed(sign: $1, value: $2) .
```

That was the natural way to write Wirth's leading sign and it cannot work.
`$$` is what the *enclosing sequence* built last, and when that sequence carries
an action of its own every factor is gathered separately — so that `$1` can mean
the first *factor* — and the `term` before the repetition is in a different slot
from the repetition. `$$` looked in an empty one.

It was a message from inside the matcher, at parse time, on a file that was
fine. It is a message about the grammar now, with the fix in it: **give the fold
a rule of its own**. Which is also the better decomposition, and is what the
grammar wanted all along.

### An option is not a choice, and the difference is a node per program

`[ integer-number ":" ] statement -> Statement(label: $1, do: $2)` builds a
`Statement` around every statement in the program, nearly all of them holding an
empty label. Written as two alternatives, a `Labelled` node exists only where
there is a label and means something wherever a pass finds one.

The same mistake was in four places — `Signed` around every expression, `Packed`
around every structured type, `Constant` around every constant, `Statement`
around every statement. **A node that is nearly always empty is not worth
having**, and the notation makes the better version no harder to write.

### A separator has to be dropped where it is matched

`{ "," identifier }` answers *everything* it matched. The commas were in the
tree. A repetition that means "a list of these" carries an action —
`{ "," n:identifier -> $n }` — and there is no way around that, because the
repetition is the only place that knows which of its factors was the payload.

### Patterns could not match a boolean

`Param(byref: true)` read `true` as a lower-case name, which is a binder, which
matches anything. The outline printed `falseu, v` for a parameter list. `true`,
`false` and `nil` are values in an expression and are values in a pattern now —
reading them as binders is the sort of mistake that matches everything and looks
like it worked.

### And the absence of `if` was right

`function-declaration` has an optional result type. A pass reading
`$returns.show` would have to ask whether there is one — except there is no `if`
to ask with. The answer the notation forces is to **give absence a name**:

```
returns = ":" t:identifier -> NamedType(name: $t)
        | -> NoType .
```

and `NoType : show = ""`. That is better than the conditional would have been,
and it is the clearest evidence so far for
[3.5](ROADMAP.md#35-conditionals-in-the-meta-language) being the right call.
The other half of the same story is `Param(byref: true)` and
`Param(byref: false)` as two clauses: shape matching *is* the conditional, and
it reads better than one.

### What the shared expression module could not do

`lib/expression.phx` was not used. Pascal's operators are `div mod and or not
in`, its `factor` includes a set constructor and a function call, and its
leading sign attaches to the whole simple-expression. None of that fits the
module, and bending the module to fit would mean reserving `div`, `mod` and `in`
in every language that imports it.

**So the module is less reusable than it looked**, and the reason is worth
keeping: an expression grammar is not one thing. What is shared between calc and
Pascal is the *shape* — precedence climbing, a fold per level, a hole at the
bottom — and a shape is not a module. That is a real limit on what `lib/` can
hold, and it was found by the second language rather than argued about.

## 2026-09-01 — stage 5, and the last decision was the same as the first

`phx desc.phx -o desc.c` writes a description out as a C program that is its
compiler. One file, `cc desc.c -o prog`, no flags and no headers.

**Tables, not code, and it is the same argument as everything else here.** A
generator can emit a recursive-descent function per rule and a switch per pass,
which is faster and is what the yacc family does. Or it can emit the description
as data and ship the machine that already runs it. The first means a second
matcher with the same ordered-choice rules, a second evaluator with the same
floored division, a second pattern matcher — **two implementations of one
notation, which have to agree.** Avoiding that is why actions are not
host-language splices, why `docs/semantics.md` exists, and why `phx --run eval`
and `--run emit-c` are tested against each other.

So a generated compiler is the runtime — `support.c`, `eval.c`, `library.c`,
`lex.c`, `parse.c`, `run.c` — written into the file verbatim, plus the grammar,
passes and drivers frozen as static tables, plus a `main`. It cannot disagree
with `phx` about what a description means, and the test asserts the strong form:
**byte for byte identical output.**

That also drew a line through the codebase that had not been drawn before. The
**runtime** runs a description; the **front** — `grammar.c`, `check.c`,
`expr.c`, `pass.c`, `emit.c` — reads one, and a generated compiler has no use
for it because it will never see a `.phx` file. The Makefile names both.

**Three things went wrong, and all three were the runtime becoming one
translation unit.**

*A static initialiser in C may not name a variable.* Emitting
`static Expr *cv = &x5;` and then using `cv` in an aggregate does not compile.
The ids are kept and `&x5` written into the aggregate directly.

*Four static functions collided.* `fail` in `eval.c` and `library.c`, and
`lower`, `match` and `same` in both `lex.c` and `parse.c`. Renamed — which is
better hygiene than it was before, since the two `match`es do genuinely
different things.

*And the emitted tables shared a namespace with the runtime.* `reserved` is a
table here and a function in `parse.c`. Everything emitted is `phx_`-prefixed
now.

**One bug was worth more than the three.** `emit_gnode` wrote `NULL` for a
node's `action`. The generated compiler parsed every program correctly and
answered nothing at all: the grammar was entirely there and every `->` had
vanished. It is the failure a table emitter is most likely to have — a field
that is only sometimes present, forgotten in the one place it is written — and
the symptom points nowhere near the cause.

## 2026-09-01 — Pascal that checks programs

`languages/pascal/pascal.phx` now has a `symbols` pass and a `typecheck` pass, and
`--driver check` reports undeclared names, bad assignments and non-boolean
conditions on real Pascal. Both fixtures check clean; a program wrong in four
ways has all four found, each at the right column.

**The two-pass shape was forced rather than chosen, and it is the clearest
justification `%driver` has had.** A Pascal block declares things and then uses
them, and a nested block sees the enclosing one's names as well as its own —
which is an *inherited* attribute, handed down. But an inherited clause runs on
the way **in**, before this node's children have been looked at, and gathering
a block's declarations is bottom-up. One walk cannot do both.

Two passes can: `symbols` computes `Block.scope` on the way up, and `typecheck`
reads it on the way in, because a previous pass's work is on the node before
this pass arrives. That is collect-then-use, which is what a hand-written
compiler does, and it is what `%driver` exists to write down.

**I reached for two library functions and needed neither.** `assignable` and
`condition` are what a checker wants, and both are ordinary expressions:

```
! not ($target.type = $value.type
       or $target.type = "unknown" or $value.type = "unknown"
       or ($target.type = "real" and $value.type = "integer"))
```

Putting that in `library.c` would have made Pascal's assignment rule *Phoenix's
opinion about Pascal*, which is exactly what a description is for saying. The
library did grow by two, and both meet the bar in `library.c`'s header:
`flatten`, because `[...$vars.entries]` opens one level and a declaration list
is a list of lists and there is no fold in the notation; and a third argument to
`lookup`, which is the same operation with an answer for absence.

**Type aliases needed one idea.** `var i : Small` where `type Small = 1..Limit`
binds `i` to `"Small"`, and the checker compares `"Small"` with `"integer"`.
Resolving that is a second lookup — and the trick that makes a second lookup
always safe is binding every base type **to itself**, so `integer` answers
`integer` and `Small` answers `integer`, and nothing has to ask which it was
looking at.

### Two places it says nothing, and one of them is the roadmap's first real argument

`with origin do writeln(x, y)` opens a record's fields into scope. Knowing which
fields those are means knowing the *structure* of `Point` and not just that
`origin` is one, and this table maps a name to a type's name. So names are not
checked inside a `with`.

`function Area;` after `function Area(r : real) : real; forward;` repeats the
heading, and its parameters belong to the declaration it repeats. **Finding that
declaration is a reference to another node**, and an attribute computed in one
walk cannot reach sideways. So names are not checked in there either.

That second one is worth more than the checking it costs: it is the first
concrete argument for [reference attributes](COMPLETED.md#21-reference-attributes--from-jastadd),
which until now was a thing the literature offered rather than a thing this
project needed. The rule has been *do not build it speculatively*, and it is no
longer speculative.

### And composing descriptions found a wart

`pascal-outline.phx` imports `pascal.phx`, and an import is read first — so
"the first driver declared" handed the default to the imported description, and
running the outline description ran the checker instead. **A file that says
nothing must not unsay something** was the rule the last import bug taught; this
is its other half: *a file that says something must outrank the file it
imported*. The default driver is now the first one declared in the file that was
named.

## 2026-09-01 — the reference attributes that were already there

The two places the Pascal checker said nothing — `with origin do ... x ...` and
`function Area;` repeating a `forward` heading — were filed as needing
[reference attributes](COMPLETED.md#21-reference-attributes--from-jastadd), a
JastAdd feature that would have brought demand-driven evaluation back with it
and undone a decision stage 2 made deliberately.

**Both are now solved, and nothing was added.**

The realisation is that a Phoenix value can *be* a node. `bind(env, name, node)`
stores one and `$x.field` reads one wherever it came from, so an environment
that binds a name to the thing it was *declared as*, rather than to the name of
its type, is an ordinary list of pairs and was always expressible. Following a
`with` is then four hops:

```
origin   -> NamedType(name: "Point")     the variable's declared type
"Point"  -> RecordType(fields: [...])    what that type is
fields   -> what each FieldDecl declares
```

**They work because every hop points backwards** — at a node the one post-order
walk has already visited and finished with, whose attributes are therefore
computed and sitting on it. That is the whole of what made them look hard and
the whole of why they were not.

The `forward` case is the same shape: a routine binds its name to its parameter
*list*, the repeated heading looks that name up, and `lookup` answers the first
match — which is the earlier declaration, because the routines are in document
order.

### What this does to the roadmap

§2.1 shrinks to one sentence: what is missing is a reference that points
**forward**, to a node the walk has not reached. Pascal barely has one —
`forward` exists precisely so that it does not — and a language that did would
be one with mutually recursive types and no forward declaration, or one where a
method may be used above where it is defined.

Two things are worth taking from that. **The discipline paid.** The rule has
been *do not build a roadmap item speculatively*, and the item that finally
looked justified turned out to be four-fifths unnecessary; building it when it
was first written down would have added demand-driven evaluation to solve a
problem that a list of pairs solves.

And **§2.3 should be read more sceptically now.** Scope graphs were filed
against `with` blocks specifically, and `with` turned out to need nothing. A
mechanism named in advance against a difficulty nobody has met yet is a
prediction, and this project has now had one prediction fail in the useful
direction.

### One thing Phoenix caught that I had wrong

`symbols` computed `Block.shapes` on the way up and `typecheck` handed down
something different under the same name. The driver's collision check said so —
*both 'symbols' and 'typecheck' define 'shapes', the later one wins* — which is
a check written for a hazard that had not yet happened, catching the first time
it did.

## 2026-09-01 — Pascal to C

`languages/pascal/pascal-c.phx` is `%import "pascal.phx"` and an emit pass.
`languages/pascal/programs/primes.pas` compiles to C that `cc -Wall -Werror` accepts, and the
program is right — ten primes below thirty, the last of them 29, and
`Gcd(1071, 462)` is 21. The whole chain has nothing in it but `cc`.

The subset is written at the top of the file rather than discovered: in are
scalars, subranges, one-dimensional arrays, records, value and `var`
parameters, the control structures and `write`; out are sets, files, pointers,
`goto`, `case`, `with` and nested routines. **Phoenix names the missing clause
the first time a program reaches for one**, which is the right way round.

### What C made awkward, and what the notation had to say about it

**A C type is written around its name** — `long v[30]`, not `long[30] v` — so a
type answers two pieces, `pre` and `post`, and every declaration is
`{pre} {name}{post}`. Writing C's declarator rule out once is cheaper than
special-casing arrays in the four places a type is declared.

**An array parameter is by reference in C whether it says so or not**, because
an array decays to a pointer. So Pascal's `var f : Flags` is a plain `Flags f`
with no dereference, while `var r : Result` is `Result *r` and every use is
`(*r)`. Telling them apart needs the parameter's type resolved, which only the
typechecker can do — so the typechecker computes it and `emit-c` reads it off
the node. That is what a sequence of passes is for.

**A call has to know which of its arguments to take the address of.** The
routine was declared earlier and its name is bound to its parameter list, so
this is another backward hop — the same mechanism as the `with` statement, used
for something that looks nothing like it.

### The conditional the notation does not have, four times

There is no `if`, and four times something needed one. Every time the answer
was a **table**:

```
lookup([["array", ""]], $shapeof, "*")              a pointer, unless it is an array
lookup([["integer", "%ld"], ["real", "%g"], ...], $value.type, "%ld")
lookup($spelled, $name, $name)                      a name C spells differently
lookup([["array", "{}"]], $shapeof, "(*{})")        which template to apply
```

`lookup` with a default *is* the conditional, and reading these back they are
better than the `if`s would have been: each one is a small explicit table of
what differs, with everything else falling through to a default that is right.
[3.5](ROADMAP.md#35-conditionals-in-the-meta-language) has now survived a real
compiler.

### Three findings, and `cc -Wall` found the worst one

**A field is read before an attribute, and a field can shadow.** `Block` has a
field called `routines` and I computed an attribute of the same name; the field
won, silently, and the message was about a list where text was wanted. The rule
is right — one rule for `$name` and `$x.name` both — and the hazard is real.

**A node built inside a clause has fields but no attributes.** A pass puts
attributes on the nodes it walks, and `NamedType(name: "?")` as a lookup default
was never walked, so asking it for `.tname` fails. Obvious in hindsight, and not
before.

**And an inherited attribute is not on the node either.** The driver's collision
check said `typecheck` and `emit-c` both define `known` and the later would win.
They do not: a `down` attribute lives in a scope pushed on the way into a node
and popped on the way out. That is the *second* time this check has been wrong
in the same way — `thread` was the first — and both are the same fact said
twice: **only a synthesised attribute is on a node.** It is one condition in
`check.c` now and the comment says why.

**The worst bug was a `writeln` inside an `if`.** `writeln(x)` is two C
statements, a `printf` and the newline, so `if (c) writeln(x);` put the newline
outside the `if` and printed it every time. `cc -Wall` said *misleading
indentation* and it was right — which is a good argument for a test that
compiles what the compiler emits rather than only reading it.

## 2026-09-01 — gcd.pas compiles

The Pascal subset now covers `languages/pascal/tests/grammar/gcd.pas`, which is the file that has
been in this repository since the first commit and was written for another tool
years before Phoenix existed. It compiles to C that `cc -Wall -Werror` accepts,
and every line of its output is right — the record through a `with`, the
enumeration through a `case`, the set membership, the field widths.

**`with` cost four lines**, and that is the finding. C has nothing like it, so
the fields have to be spelled `origin.x` inside the body — which is a table of
names spelled differently, handed down. That table already existed, for `var`
parameters. A construct C does not have turned out to need no mechanism, because
the mechanism it needs was built for something that looks nothing like it.

**An enumeration became a C `enum`** rather than a `long` and a run of
`#define`s, which means nothing has to count: C numbers enum members from nought
exactly as Pascal does. That is the second time the answer has been *emit the C
construct that already agrees* rather than *emit the arithmetic*, the first
being array parameters, which C passes by reference whether you ask or not.

**A set is a bit per member in a `long`**, and the empty set is why `SetOf`
emits `(0 | ...)`: the leading nought makes `[]` come out as `(0)` instead of
`()`, without a second clause for a case the arithmetic already covers.

### Two things the library did not have, and one it did not need

`slice` and `split`. A Pascal string arrives with its quotes on and its doubled
quotes undoubled, and turning `'it''s'` into `"it's"` cannot be written without
them. They are ordinary operations on bytes and their absence was a real gap
rather than a Pascal-shaped one.

What it did *not* need was a way to number a list. That was wanted for
enumeration members, and choosing C's `enum` removed the want — which is worth
noticing, because the first instinct was to add `indexed()` to the library and
the better answer was to emit different C.

### The lesson that keeps arriving

`Argument(width: nil)` could not be told from `Argument(width: something)`,
because a pattern matches a node type and cannot ask whether a field is nil. So
`Argument`, `Padded` and `Rounded` are three node types.

That is the fourth time: `Labelled`, `Packed`, `Signed`, `Accessed`, and now
these. **An option is not a choice**, and every time the grammar has been asked
to make a distinction it already knows, the passes have got simpler and a node
that was usually empty has stopped existing.

## 2026-09-01 — the notation, described in itself

`languages/phx/phoenix.phx` is the `.phx` notation written in `.phx`. It parses
itself, and it parses every other description in this repository.

This is [level one](#2026-09-01--what-self-hosting-would-and-would-not-prove) of
the three the earlier entry set out, and the only one that is free: it describes
the *shape* of a `.phx` file and replaces nothing. The reader in `grammar.c`
stays, and the PEG machine and the scanner are not derived from any grammar and
never could be.

**Four things came out of it. Three were improvements to Phoenix and one is a
gap that stays.**

### An attribute should be its own token

`grammar.c` tells `$left.val` from `$left .` by whether a space precedes the
dot — a special case in the scanner, and the one place in the notation where
whitespace changes a meaning. It has been in the README's list of warts since
stage 2.

Described in the notation it is a lexical rule and there is no special case: an
attribute is a dot with a **lower-case letter immediately after it**, so `.val`
is a token and `. ` cannot be one. Longest match does the rest.

**And it is better than the rule it describes**, because it covers something
the reader's rule was never about. `at($vars, 1).name` is an attribute of a
*call*, and there is no `$` for a space to be adjacent to; the reader handles
it by accident of where `read_postfix` sits, and the description handles it by
saying what an attribute is.

### A directive could not end at a line, and no longer has to

`%fragment letter digit` ends where the line does, and a grammar matched over
tokens cannot see a line — the scanner threw it away. Phoenix now accepts a `.`
after a directive, which is how every other construct in the notation already
ended, and every description here was updated to write one.

### Reserved words are automatic, and this is the file guaranteed to mind

Every word-shaped literal in a syntactic rule becomes a reserved word, worked
out from the grammar rather than declared. It is a good rule. It is also why
`of`, `and`, `or`, `not`, `div`, `mod`, `thread` and `down` — all operators in
this notation — became unusable as field names, and `pascal.phx` writes
`of: $t` and means a field.

Phoenix does not reserve them: its reader knows an operator from a field name
by where it is looking. The notation cannot say that, so the description has a
rule `word` listing the words a plain name will also accept. It is the wart the
README already called *a grammar module imposes reserved words*, met in the one
description certain to meet it.

### The optional production terminator stays undescribable

`grammar.c` lets a production end without its `.`, by looking two tokens ahead
for a name followed by a definition symbol. That is **syntactic negative
lookahead**, and `!` is lexical only — refused in a syntactic rule on purpose,
because there it would be asking about characters where there are only tokens.

Nothing is lost by requiring the terminator: every `.phx` file here writes one.
But it is a feature of the notation that the notation cannot state, and it is
the answer to the question this exercise was for.

### And two mistakes worth keeping

**`! ""` never matches.** The first attempt at a string escape was `"\\" ! ""` —
a backslash and then anything — and there is no *anything* in this notation:
`! x` is one character provided `x` does not match, an empty literal always
matches, so `! ""` always fails. The escapes are enumerated instead, which is
more accurate anyway.

**A grammar can describe a call and forget that a call can be reached into.**
`Name(field: value)` was described as a function call with positional
arguments, so `Description(items: $1)` failed on the colon; and `postfix` was
missing entirely, so `at($vars, 1).name` failed on the dot. Both were places
where the reader does something so ordinary that writing the grammar down was
the first time anybody had to notice it was a rule.

## 2026-09-01 — and the reader took the description's advice

`.val` is a token now. The scanner makes one when a dot is immediately followed
by a lower-case letter, and the expression reader has nothing left to decide.

This is the change `languages/phx/phoenix.phx` argued for by being written: the
notation could only describe its own attribute access by making it lexical, and
having done so it was plainly the better rule. **The `tight` flag is gone from
every token**, along with the stamping that maintained it, and the wart that has
been in the README since stage 2 with it.

Three things it fixes rather than moves:

**`at($vars, 1).name` was working by accident.** The old rule asked whether a
space preceded the dot, which is a question about a *reference* — and an
attribute of a call has no reference before it. It worked because
`read_postfix` happened to sit after `read_primary`. Now it works because an
attribute is an attribute.

**The scanner no longer tracks what preceded a token.** Maintaining `tight`
meant stamping every push site with where the previous token ended, in eleven
places, and getting one wrong would have been a silent misparse.

**The rule is now written where a rule belongs.** It was a condition in
`expr.c`, one call deep, in a loop about something else. It is a scanner rule
about what a token is, which is what it always was.

## 2026-09-01 — measured, and it found a segfault

`bench/` and [performance.md](performance.md). The question was never *how
fast*; it was **whether the work grows in proportion to the input**, because a
PEG with no memoisation need not and Phoenix has none. A constant factor is a
decision and a bad complexity is a defect.

**It is linear**, in all four shapes tried — statements in sequence, one long
expression, nested parentheses, nested blocks — at about 24 match-steps per
token, flat across sixteen times the input. There is no bad case in Pascal's
grammar, which is a thing nobody had checked. Steps are deterministic, so that
is the curve exactly rather than a measurement of it.

**And measuring found a crash nobody suspected.** Matching is recursive
descent, so the C stack is proportional to how deeply the *input* nests, and
about 3,400 nested parentheses exhausted it: a SIGSEGV, which tells a person
nothing, cannot be caught, and arrives on input a compiler does not get to
trust. There is a depth limit now and a message with a position. Real programs
reach 62 to 99; the limit is 10,000.

That is the whole argument for measuring. The linearity result confirmed what
was hoped, which is worth having written down and is not why it was worth
doing. The crash would otherwise have been found by somebody else's malformed
file.

**One number is worth keeping for what it says about stage 5.** The generated
compiler is 18% faster than `phx` on the same input, and all of the saving is
fixed cost — it neither reads a description nor checks one. On a small program
that is most of the run and on a large one it is noise. **The generated
compiler's value is that it stands alone, not that it is quick**, and it is
better to know that than to have assumed either way.

And `fpc` fails on the 20,000-line file — *"Procedure too complex, it requires
too many registers"* — where Phoenix does not, because register allocation was
never Phoenix's problem. That is not a point in Phoenix's favour so much as a
description of what emitting C means.

## 2026-09-01 — the oracle, and the six bugs it found on the first run

`languages/pascal/tests/oracle/` compiles the same Pascal with `fpc -Miso` and with Phoenix, runs
both, and compares byte for byte. **fpc is the oracle**: where they differ,
Phoenix is wrong until somebody shows otherwise, because fpc has been read by
more people than this repository has. It is the method Solveig's `PASCAL.md`
uses, for the same reason.

Eight programs. The first run had **one** of them agreeing.

| | |
| --- | --- |
| **`mod` was C's `%`** | ISO Pascal's `i mod j` is the non-negative remainder and wants `j > 0`: `-7 mod 2` is **1**, not −1, and `7 mod -2` is a runtime error. There is a `phx_mod` helper now |
| **an integer had no default width** | Pascal right-justifies in eleven, so `writeln(15)` writes nine spaces first. Every unwidthed integer in every program was wrong |
| **a boolean printed as `1`** | it is ` true` and `false`, in a field of five |
| **a real printed as `1.5`** | it is ` 1.5000000000000000e+000` — scientific, sixteen fraction digits, and a **three**-digit exponent where C's `%e` gives two. There is a `phx_real` helper now |
| **a recursive function would not compile** | the result variable took the function's own name, so `Fact := n * Fact(n-1)` became `Fact = n * Fact(n-1)` with `Fact` a `long`. The result is `phx_result` now, and *reading* the function's name is spelled that way while *calling* it is not, because a call is a different node |
| **`Signed` was two things** | a signed *constant* and a signed *expression* shared a node, and `symbols` asked a `Variable` what type of constant it was |

**Every one is a place C's obvious answer is not Pascal's**, and not one would
have been found by reading the output and thinking it looked right. Three of
them — the widths — had been in front of me the whole time, in `primes.pas`'s
own expected output, which I wrote down from what Phoenix produced.

### What it cost to fix, and what that says

Nothing was added to Phoenix. All six are changes to `languages/pascal/pascal-c.phx`,
and the two that needed C that Pascal has and C does not — `phx_mod` and
`phx_real` — are **emitted by the description into every program it compiles**.
A description that needs a runtime writes one.

Two notation things came out of it. `of` does not chain, so a template built by
`lookup` is filled once and not twice. And adjacent string literals do not run
together, so a multi-line C helper is `join([...], "\n")` — which turns out to
be better anyway, because the braces in C code are then *values* rather than
template syntax and none of them has to be doubled.

### And one thing the oracle cannot check

`fpc -Miso` has 32-bit integers and Phoenix has 64-bit, so `maxint` differs and
so does where arithmetic overflows. The oracle would catch it only on a program
that overflows, and such a program has no agreed answer to compare. It is a
divergence in the sense Solveig's `PASCAL.md` uses the word: written down, not
fixed.

## 2026-09-01 — six more oracle programs, four more bugs, two of them in Phoenix

The standard functions, chars, enumerations, sets, `case` with several labels,
and a `with` inside a `with`. Fourteen programs now agree with `fpc -Miso` byte
for byte.

**Two of the four were in Phoenix, and both were silent.**

`each` ran to the length of its **first** list, so everything the second had
beyond it was dropped without a word. `abs(i)` came out as `abs()`: the first
list is what a call puts before each argument, and a call to something the
description does not declare puts nothing before anything — so the first list
was empty, and so was the answer. It runs to the longer of the two now.

`lookup` compared **only text**, so an integer key never matched and never said
so. `lookup([[1, "char"]], size(t), "string")` quietly answered `"string"` for
every length, which is exactly the shape of bug a table-instead-of-a-conditional
design invites. It compares the way `=` compares now, which is what it should
always have done: one notion of equality, not two.

Both are the same kind of fault — **a silent wrong answer from a library
function**, where an error would have been found in a minute. Neither would have
surfaced without an oracle, because both produce output that looks plausible.

**The other two were Pascal facts.** None of `abs`, `sqr`, `odd`, `ord`, `chr`,
`succ`, `pred`, `round`, `trunc` is a C function, and two of them depend on
their argument's type — which the typechecker knows and leaves on the node. And
a one-character Pascal literal is a `char`, not a string: `c := 'a'` was a type
error and `ord('A')` took the address of a C string literal.

**And a nested `with` needed one word changed.** The prefix a `with` puts in
front of its fields has to be the *spelled* form of its own variable, not its
name — inside `with o do with p do ...`, `p` is already `o.p`, so `a` becomes
`o.p.a`. Looking the prefix up in the very table the clause is extending is the
whole of it.

## 2026-09-01 — four more oracle programs, and the one an oracle cannot catch

Array bounds, set operators, `for` over chars and enumerations, and
two-dimensional arrays. Eighteen programs agree with `fpc -Miso` byte for byte.

**One of them agreed while the compiler was corrupting memory, and that is the
thing worth writing down.** `array [5 .. 9]` had *one* subtracted from every
index instead of five, so it wrote elements 4 to 8 of a five-element array, and
`array [-3 .. 3]` wrote element −4. The oracle passed it. It passed because the
write and the read used the same wrong offset: the answers matched and the
memory did not.

**An oracle proves agreement, not correctness**, and a program that only reads
back what it wrote is exactly the shape that hides this. `languages/pascal/languages/pascal/tests/oracle/run.sh`
says so at the top now. What found it was reading the emitted C, which is the
other half of the method and the half that does not scale.

Fixing it properly took the longest chain in the description so far — a
variable to its type, a named type to what it stands for, and that to where its
index range starts — and two things had to change underneath.

**A lookup's default has to be constructible**, and a node built in a clause has
fields but no attributes. So `shape` binds a name to a `Shape(iname:, startsat:,
node:)` wrapper, and every hop reads fields rather than attributes.

**And a field shadows an attribute of the same name.** `Subrange` has a field
called `low`, so a computed `low` was invisible from outside — the second time
this has happened, after `Block.routines`. Renamed to `startsat`. The rule is
right and worth restating: `$x.name` is a field first and an attribute second,
and a computed attribute must not take a field's name.

Two smaller things. **A pass builds nodes too**, and the vocabulary was gathered
only from productions — so the driver's check reported a *field* of one as an
attribute nothing defines. And **a `down` clause does not overwrite a node
attribute**, which is the third time the collision check has been wrong the same
way; it now counts only synthesised clauses, which is the one condition that was
always meant.

**`Member` is the fifth time an option should have been a choice.** A set
constructor could not ask whether an element was one bit or a run of them, so it
shifted a range that was already a mask.

## 2026-09-01 — the other half of correct

An oracle says the subset is right. It says nothing about what is outside it,
and that is the half where a mistake looks like success.

`set of 0 .. 200` **compiled quietly and answered `no`** where Pascal answers
`yes`. A set is a bit per member in a `long`; the two-hundredth bit is not
there. Nothing said so until a program was written that asked, and the oracle
would never have asked, because a program using a big set is not a program
anybody writes by accident.

`languages/pascal/tests/refused/` is that half now: programs that must fail, each with a message
naming the feature, at a position in the Pascal. Four of them — a nested
routine, a set too large, pointers, files — and the test insists on both halves
of the message, so a refusal that says *'Pointer' has no attribute 'pre' in
pass 'emit-c'* counts as a failure. That is a true sentence about the
description and no use at all to somebody holding a Pascal program.

**Three things came out of writing them.**

`goto` turned out to be *in* rather than out. C has labels and `goto`, so it is
two clauses — and it is the one place emitting C is strictly better than
emitting Solveig would have been, which `Solveig/docs/PASCAL.md` predicted from
the other side: a translator into *source* has no control-flow syntax to
translate a `goto` into.

**A node cannot ask a question about itself that its own `down` clause
answers.** `Procedure : down inroutine = true` with a check reading
`$inroutine` sees its own value: the scope is pushed on the way in and is still
there when the checks run on the way out. The *block inside* it is what can
ask, and the program's block gets the program's answer. Obvious afterwards, and
the false positive was on every top-level routine in the suite.

**And a check is introduced by `!` alone, not by `: !`.** I wrote the latter
twice. The message — *expected the name of an attribute* — is accurate and
points at the `!`, which is not where a person would look.

## 2026-09-01 — six more oracle programs, and a second thing that agreed while wrong

Strings, mixed arithmetic, partial lines, a dangling `else`, records inside
arrays inside records, and enumerations ordered against each other.
Twenty-four programs agree with `fpc -Miso`.

**Two of the six were wrong in ways the oracle had already been passing.**

`'abc' < 'abd'` compiled to `("abc" < "abd")`, which compares two *addresses*
and is undefined — and it **agreed with fpc**, because the compiler had pooled
the identical literals and laid the others out in order. That is the second time
an accident has looked like a pass, after the array bounds; both were found by
reading the emitted C rather than by the oracle. `strcmp` now, and each
comparison has a clause of its own because the two templates want their operands
in different places.

`b.name` is a `char` and was printed as `66`. **The accessors were a flat list**,
and the comment written at the time said turning that list into a nest was "a
decision a pass can make with more context than this rule has". It was not: a
pass has to know what `b.corners[2]` *is* before it can say what `.x` is, and a
flat list has nowhere to hang that. They nest now — `Indexed(of:)`,
`FieldOf(of:)`, `Deref(of:)` — and each step asks the step below it.

**The chain works in type names, not type nodes, and that was the second
attempt.** Nodes needed a default wherever a lookup might miss, and a node built
in a clause has fields but no attributes — so `$tnode.iname` failed on every
name the scope did not hold, which is every enumeration constant and every
built-in. Text has no such trouble: `named` is the type as written and `type` is
that resolved, both plain strings, and a default is just another string.

That also deleted the `down lowbound` hack. An array's lower bound belongs to
the `Indexed` node that uses it, and with a nest there is finally an `Indexed`
node to put it on.

**And a check cannot read an attribute its own rule defines.** A check is a
guard and runs *before* them. `FieldOf`'s check asks the child instead, which is
where the answer was anyway.

## 2026-09-01 — a directory per language

Pascal had spread: three descriptions in `examples/`, its programs beside
calc's, its grammar fixtures in `tests/pascal/`, its oracle in `tests/oracle/`
and its refusals in `tests/refused/`. None of that was wrong while there was one
serious language, and all of it would have been in the way of a second.

```
languages/
  pascal/   the descriptions, its programs, and its own tests
  calc/     the same, smaller
  phx/      the notation described in itself
tests/      tests of Phoenix rather than of any language
```

**The distinction that matters is the last line.** `tests/` was holding two
kinds of thing: whether Phoenix reads a description correctly, and whether the
Pascal description describes Pascal correctly. The first belongs to the tool and
the second to the language, and only one of them multiplies when a language is
added.

The move was mechanical and the tests caught every path it broke, which is the
argument for having had them. Nothing in `phoenix/` changed, and no description
needed editing beyond the paths in its own header comment — `%import` resolves
beside the file that names it, so the descriptions moved together and kept
working without being told.

## 2026-09-01 — an array passed by value was not copied

Six more oracle programs — by-value parameters, a `for` limit, `case` on a
char, records inside arrays inside records, expressions as loop bounds, whole
record assignment. Thirty programs agree with `fpc -Miso`.

**Two more silent wrong answers.**

*Pascal copies an array passed by value and C does not*, because a C array
decays to a pointer — so `TouchArray(r)` wrote the caller's `r`. An array is
wrapped in a struct now: `struct { long v[5]; }`, indexed through `.v`. A struct
copies, so the C does what the Pascal says.

**And that deleted a special case rather than adding one.** `var` array
parameters had needed different treatment from every other `var` parameter —
no pointer and no dereference — for exactly the reason that arrays decayed.
With a struct nothing decays, every `var` parameter is a pointer, every use is
`(*name)`, and the table that chose between the two spellings is gone along with
the `shapeof` attribute that fed it.

*A `for` limit is evaluated once in Pascal*, before the loop, so a body that
changes what the limit was computed from does not change the loop. C
re-evaluates it. The limit gets a variable in a block of its own, which also
means a nested `for` shadows it rather than clashing with it.

**Neither would have been found by reading the emitted C**, which is how the
last two were found. `a[1] := 99` inside a procedure is right-looking C, and
`for (i = 1; i <= n; i++)` is what anyone would write. It took a program that
asked, which is what an oracle is.

## 2026-09-01 — mutual recursion, and two orderings said again

Five more oracle programs — evaluation order of `and` and `or`, recursion to
depth 500, mutual recursion through `forward`, stray semicolons and empty
statements, and the boundaries of enumerations and `char`. **Thirty-five
programs agree with `fpc -Miso`.**

Four of the five passed first time, which is the first time that has happened
and is worth noting for what it says: the bugs are getting harder to find, and
the ones left are in the corners rather than in the middle.

**`forward` was the one.** A forward declaration is a C prototype and the
heading repeated after it is the definition, whose parameters and result type
belong to the declaration it repeats. The routine's name is already bound to a
shape; the shape carries the result type as a *name* now, so finding it is one
lookup — **a backward reference**, like every other hard thing in this
description.

That the shape had to carry a *name* rather than the type node is the same fact
as always: a lookup needs a default, a default has to be constructed, and a
constructed node has fields but no attributes. Text needs no default worth
worrying about.

**And two orderings had to be said again.** An inherited clause runs on the way
*in* and a synthesised one on the way out, so `down spelled` cannot read a
`forward` attribute computed in the same rule — the lookup is written out
twice. And Phoenix's own warning caught a `Shape` built with four fields in one
place and three in another, which is a check written for a hazard that had not
happened, catching the second time it did.

**The evaluation-order test is the interesting pass.** ISO Pascal does not
promise short-circuit evaluation and C promises the opposite, so
`Note('a', false) and Note('b', true)` could have printed `ab` under fpc and
`a` under Phoenix. It prints `a` under both: fpc short-circuits too. A
divergence that was expected and is not there is worth a test, because the next
compiler might not.

## 2026-09-01 — three checks, from three mistakes made twice

Writing `languages/pascal/` I hit the same three foot-guns repeatedly. All three
are decidable from the description alone, which makes them Phoenix's business:
a description is read once and then run over every program ever compiled with
it, so a fault found while reading it is found before anybody else sees it.

**All three are about when a clause runs.** A node is visited in two phases:
`down` clauses on the way in, then the children, then the checks and the
synthesised attributes on the way out.

| | |
| --- | --- |
| an attribute with a field's name | a field is read before an attribute, so `Block.routines` and `Subrange.low` were invisible from outside their pass. A **warning**, since it is legal and merely almost never meant |
| a `down` clause reading its own rule's attribute | inherited runs on the way in, synthesised on the way out. An **error** |
| a check reading the attributes it guards | a check runs before them. An **error** |

Each was tried against the mistake that motivated it, by putting the mistake
back: `Subrange : low = ...` warns, and the `down spelled = ... $forward ...`
that cost me twenty minutes is now a message naming the rule and the reason.

**And the check found one I had not noticed.** `Param : type = "void"` — `Param`
already has a field called `type`, so the attribute was never visible from
outside the pass, and nothing read it. It had been there since the typechecker
was written, doing nothing, because a clause was added for uniformity that the
uniformity did not need. Deleted.

That is the argument for this kind of check in one line: it is not that I would
have made the mistakes more slowly, it is that one of them was in the tree,
harmless, and would have stayed.

## 2026-09-01 — Solveig, and a conformance suite before a compiler

The next language is Solveig, and the first thing built for it is not a
description — it is **a conformance suite**, so that the target exists before
anything aims at it.

**The grammar half is already free.** Solveig ships
`programs/check_syntax/solum.bnf`, its published grammar in Wirth's notation,
held character for character against `docs/GRAMMAR.md`. Phoenix reads it
**unmodified** and parses **all 63 `.sol` files** in that repository — every
example, every program, every library file. The same result `pascal.bnf` gave,
from a grammar written for another tool.

**Why a conformance suite is a different thing from Solveig's own tests.**
`tests/*.c` there check the internals of `solas` and `solvm`, which is the right
job for an implementation to do to itself. A conformance suite checks the
*language*: programs and the output each must produce, which can be handed to
anything claiming to compile Solveig. There was not one, and there is now — nine
programs asserting what `CHEATSHEET.md` and `REFERENCE.md` say the language is.

**The expectations are read against the documentation rather than taken on
trust**, which is the difference between a suite and a set of fixtures. Where
the two disagree that is a finding. Nothing disagreed: floored division,
byte-counted strings, trapping overflow, `infinity` for float division by zero,
`join` strict about strings, `and` checking for a block when it is *sent* — all
as written.

One thing that looked like a disagreement was not. `display` writes the value
**and a newline**, which `CHEATSHEET.md` says explicitly of `print` and not of
`display` — and `REFERENCE.md` shows `#3:repeat({ "tick":display })` producing
`tick tick tick` on one line. Measured, it produces three. The inline comments
in those docs render output space-separated, which is a convention rather than a
claim; the three-line reading is right.

**And two of the programs were wrong before the compiler was.** `join` over
integers is an error, not a conversion, and I had written it expecting a
conversion. That is what a suite written against documentation is for: it caught
me rather than `solas`.

## 2026-09-01 — the Solveig front end, and what a second language proved

`languages/solveig/solveig.phx` is the published grammar with `->` clauses
added. **Fifteen node types where Pascal needed fifty-one**, because Solveig
has one thing that happens and Pascal has many.

Every `.sol` file there is — 75 of them, including a 2,800-line compiler
written in Solveig — parses, renders back out, and parses to an **identical
tree**. The twelve conformance programs get the stronger form: what comes out
is compiled by `solas`, run, and prints what the original printed.

### What the second language proved about the notation

**It needed nothing new.** No library function, no check, no mechanism. That is
the answer to the question the whole exercise was for: a notation that suited
fifty-one node types suits eighteen, and a language with statements, types and
infix did not shape it against a language with none of those.

**And the lessons transferred exactly.** The two mistakes I made writing it were
both ones Pascal had already taught:

- the separators were in the tree, because `{ "." statement }` answers
  everything it matched — the same fault as `{ "," identifier }`, four
  descriptions later
- `Reach(of:, by:)` with `Args`/`Setter`/`Plain` was the flat-list problem
  wearing a new hat. A send has no receiver until the chain gives it one, so
  the three shapes are written *inside* the fold and there is no half-node in
  the tree. Four node types disappeared

The second is worth stating as a rule, since it is now three for three:
**a fold has to be where the accumulator is.** Pascal's accessors, Pascal's
signed expression, and now Solveig's send chain.

### The one real finding

`solum.bnf` lets the operator ladder take a leading minus, so `-1.5:truncated`
reads as `negated(1.5:truncated)` — the sign applied to the whole chain.
`solas` reads it as `(-1.5):truncated`, because outside an `@expr` region its
scanner makes no minus: *'-' must be followed by digits*. The two differ, `#-1`
against `#1`.

**The grammar file names this itself** — *"that is the looseness this ladder
costs"* — and a grammar checked against files rather than against a compiler
can afford it. This description follows `solas`, which is the one place it
departs from the published grammar and the only place it should.

**It was found by the round trip**, on the two conformance programs that write
a negative float, and by nothing else: the tree round-tripped fine, and only
running the rendering through `solas` showed the difference. That is the same
division of labour the Pascal oracle taught — reading the output catches what
is wrong on its face, and running it catches what is wrong only against the
language.

### And the operators are not in the tree

`@expr(a + b * c)` produces `Send(a, add, [Send(b, mul, [c])])`. The language
says the operators are a second spelling and never a second semantics, so the
tree says so too — and `&` and `|` wrap their right side in a block, because
`and` and `or` short-circuit. That is the one place the lowering is more than
renaming, and it is the sort of thing a description is *for* saying.

---

## Stage 7 — a binary target, and what it took

The `.sob` backend ([`languages/solveig/solveig-sob.phx`](../languages/solveig/solveig-sob.phx))
compiles Solveig to SolVM bytecode, which `solvm` runs. Every emit pass before
it produced *text*, where the output followed the shape of the tree and a
parent wrapped its children. A bytecode file does not work that way, and the
roadmap had claimed since stage 2 that a flat target is where threaded state
earns its keep without ever testing the claim.

**The claim held, and it was not enough.** Three things had to be added, and
each one is a place where the notation was short rather than a place where the
target was strange.

### `bytes`, and `int` with a base

A description that emits a binary format cannot do without a number as bytes,
and it cannot be written in the notation. `bytes(n, width)` is little-endian
and one to eight wide; `bytes(f, 8)` of a **float** is its IEEE 754 bits,
which is the only reading of "this number as eight bytes" a binary format ever
wants.

`int(text, base)` is the same generalisation of something that was already
there. Solveig writes `#45`, `$ff` and `%1010` and they are **one node**, so
the marker says the base and the base has to be sayable.

### `positions`, and slots

A block's locals are slots numbered from zero, and *a name's slot is where it
is in the list of the frame's slot names*. Nothing could reach that: `at` wants
an index and nothing produced one. `positions(list)` answers the table saying
where each thing is — a table rather than a list of indices, so that it
composes with `lookup`, which is how every other question in the notation is
asked.

With it, scoping is three lines and no machinery: a name is a slot if the
frame has one by that name, an `OP_OUTER` if a frame further out does, and a
global otherwise.

### `down` on a threaded attribute — the real one

**A thread runs in one chain along the whole walk, which is right for anything
the program has one of and wrong for anything a scope has its own of.** A
`.sob` method carries its own name and constant tables, so entering one has to
start them empty and leaving one has to put the enclosing tables back. That is
a save and a restore. That is a stack. A single chain has no stack in it.

The change is that a `down` clause naming a threaded attribute now *sets the
thread for the subtree* instead of binding a name over it. Everything else
follows from what was already there: the save is an ordinary `down` attribute,
the restore is the node's own leaving clause — which works because a node's
scope is torn down *after* its leaving clauses run, not before.

```
Block : down heldnames = $names        (* save    *)
      : down names     = [...]         (* reset   *)
      ...
      : names          = $heldnames .  (* restore *)
```

It nests because a stack nests: a block inside a block saves the middle
chunk's tables and puts them back, and its method lands in the middle chunk's
method table where its `OP_BLOCK` looks for it. Nothing in `run.c` knows what
a chunk is.

**This is the first thing the design could not express**, and section 3.5 of
the roadmap asked to have it recognised as this decision arriving rather than
as a puzzle. It is not the conditional that gave way — tables-as-conditionals
held up fine over an entire backend. It is that inherited and threaded were
two mechanisms where the target wanted one thing that was both: accumulating
left to right *and* scoped.

### Spreading a non-list is now an error

`...` of something that is not a list used to spread to the thing itself. That
is quiet and wrong, and it hid a real bug in two files for as long as it was
allowed:

```
group = "(" t:temporaries e:expression { "." f:expression -> $f } [ "." ] ")"
          -> Group(temps: $t, body: [$e, ...$3]) .
```

`$3` is the third *item* — `e:expression` — not the repetition, which is `$4`.
So `[$e, ...$3]` built `[e, e]`: the first statement twice, every later
statement dropped. `("ran":display. { nil })` parsed as
`("ran":display. "ran":display)`.

**The round trip could not see it**, and this is the sharpest example yet of
why an oracle is not optional. The parse was wrong, the tree was wrong, and
what `show` wrote back out was wrong *in the same way* — so it parsed to an
identical tree and the round trip passed. Running it did not: `ifTrue` was
handed a string.

Refusing the spread found the same mistake twice more, in
`languages/phx/phoenix.phx` itself — `Apply(values: [$a, ...$3])` and
`Shape(fields: [$f, ...$3])`, both wanting `$4`. Phoenix's own
self-description had been miscounting items since it was written, and every
test passed because the miscount was consistent.

### What the oracle found

`solas` and `solvm` are the oracle, the way `fpc` is for Pascal, and the test
is stronger: not "does the output read correctly" but "does the compiled
program print the same thing". Two bugs, both in the *front end* and neither
findable by rendering:

- **`-2^2` was 4 and should be -4.** `^` binds tighter than a leading minus,
  so it is `-(2^2)`. Keeping the sign in the literal — which is what makes
  `-1.5:truncated` read as `solas` reads it — gives `(-2)^2`. The one shape
  where the two rules disagree is now written out first in `power`.
- **`self` is slot 0 of *every* frame**, not of the outermost block of a nest.
  A block installed on a class is a method and its slot 0 is the receiver, and
  a block written inside another is still the one that gets sent.

### Where it stands

50 of the 51 Solveig files in the repository that do not use `@include`
compile to bytecode that prints exactly what `solas`'s does, run by the same
`solvm`. Four differ only in the *locations in a traceback*, because this
backend emits one line run per chunk and no file table — missing debug
information, not a miscompile. One reads the clock.

`@include` is the one construct refused, and refusing it is right: splicing
another file in before compiling is something a **reader** does, and a pass is
a walk over one tree that has already been read. It is the first real gap that
is not about expressions at all, and any language with a module system will
want the same thing.

## 2026-09-02 — `@include`, and the failure that was not one

The first gap that was about the shape of the tool rather than about
expressions, and [ROADMAP 1.0](ROADMAP.md) had named it as the one to decide
next. `@include "library.sol"` splices another Solveig file in before
compiling; 24 of the files in that repository use it, and the bytecode backend
refused all 24 by name.

**Refusing it was right, and that is the whole argument for the mechanism.** A
pass is a walk over one tree that has already been read. An include is a second
file, which has to be read before there is a tree to walk. No clause can reach
it, however it is written — so this is a directive the reader acts on, and the
only one that is about the *target* language's files rather than about the
description's.

```ebnf
include = "@include" p:string -> Include(path: slice($p, 2, size($p) - 1)) .
%include Include path .
```

Two names: which node an include is built as, and which of its fields holds the
file. What happens then is fixed and is deliberately not a description's to
vary — the file is read with the same grammar, and the items its root holds
take the include node's place in the list that held it.

### The quotes come off in the action

The first real decision, and it went the other way from the obvious one. A
token arrives spelled the way the file spelled it, quotes and escapes and all,
so `Include(path: $p)` holds `"library.sol"` with the quotes on. The reader
could strip them. It must not: how a language writes a string is the one thing
only that language's description knows, and a reader that guesses is a reader
that is wrong about the first language that disagrees.

So `%include` takes the field's text **exactly as it stands**, and the
description says what a path is with the notation it already has. `show` then
puts the quotes back, which is what keeps the round trip honest.

### A cycle turned out not to be a failure

The roadmap entry warned about three new ways to fail — a cycle, a missing
file, a path relative to which of two files — and predicted each would need a
message with a position. Two of them did, and they are one message: *cannot
read the included file, and here is where I looked.* The rule is C's, and for
C's reason: beside the file the include is written in, so a program survives
being moved, then the search path, `-I` in the order given.

The third needed nothing. **A file is read once however many ways it is
reached**, which is what `%import` already does one level up and for the same
reason — and once that is true, a file that comes round to itself finds itself
already read and contributes nothing. There is no cycle to detect. The check
that would have detected one would have been a second mechanism doing what the
first already did.

What the entry did *not* anticipate is that the splice needs two refusals of
its own, and both are the same sentence: there is no answer to what this would
mean.

- **an include where a field is wanted.** A file is a number of things and a
  field holds one. Solveig refuses the same shape from the other side — `x :=
  @include "f"` is a compile error there — and this is that error arriving
  through a different door.
- **an included file whose root holds two parts.** Splicing is "the items its
  root holds", and a root holding a header and a body has no answer to which of
  them a statement position wanted.

### Identity is spelling, and that is a decision

A file reached beside its includer and again from the search path is the one
file, so the two spellings have to be recognised as one. `realpath` is the
answer and `realpath` is POSIX; a generated compiler is meant to build with
`cc file.c` and nothing else, and this code is part of one. So the paths are
folded textually — `a/./b`, `a//b` and `a/x/../b` are `a/b` — and a symbolic
link is read twice.

Worth writing down because it is a trade rather than an oversight: being wrong
here costs a file compiled twice, which *runs* twice and is visible, rather
than something quiet.

### The joined text, and the pointer that stays valid

Positions had to keep working across files, and the machinery for that already
existed one level up: every file's text end to end in one buffer, with a map
saying which stretch came from where, so an offset stays a single number and a
diagnostic still names the file and its own line.

The buffer is copied when it grows, which looked like a problem — a token
scanned from an earlier copy points into memory that has been superseded. It is
not one, and the reason is the arena: nothing is freed, text is only ever
appended, so an old copy holds the same bytes at the same offsets that the new
one does. A pointer into it is stale and correct. That removed the tree walk
that would otherwise have had to shift every position, and with it the
aliasing bug that walk would have had if a node ever appeared twice.

### `--no-includes`, and what a round trip is a question about

Expanding is what a *compilation* does, so `phx` does it before anything walks
the tree, `--tree` shows the expanded tree, and a generated compiler does the
same and takes `-I` for the same reason.

The round-trip test wanted the other thing. It parses every `.sol` file in the
Solveig repository, writes it back out, and parses that; with expansion it
would have been checking the library over and over and never once checking that
an `@include` is written back as one. So `--no-includes` exists, and the flag
is not a convenience: *what does this file's own text mean* and *what does this
compilation mean* are two questions, and only the second follows a file it
names.

### What it moved, and what it uncovered

The Solveig oracle went from **50 programs to 72**. The 22 it added found
nothing wrong with the backend, which is the useful negative result: some
22,000 lines of Solveig that had never been compiled by this description
before, and not one new disagreement.

Two of them did cross a line the other seventy do not, and the cause is one
thing seen twice. `solas` **inlines** the block of an `ifTrue:`, a
`whileTrue:`, an `and:` and an `or:` into the enclosing chunk, behind a jump;
`solveig-sob.phx` compiles every block as a block. The bytes differ and the
output does not — except where a block that is really a block is visible:

- `programs/pascal.sol` nests blocks **19 deep** and the `.sob` format allows
  16. `solas` inlines its way under the limit; this backend cannot, and the
  loader refuses what it writes.
- `programs/basic.sol` is a BASIC interpreter whose own suite calls something
  recursive until the machine stops it and prints what happened. One extra
  frame per level means it stops one test earlier.

Neither is a miscompile and neither was caused by this work; `@include` is
what made the two files reachable. They are counted apart in the test, with the
cause named, and [ROADMAP 2.4](ROADMAP.md) is the entry for the missing
optimisation.

**The oracle was worth more here for what it made reachable than for what it
disagreed with**, which is the opposite of every previous time it earned its
place — and it only worked because the count is reported by category rather
than as a single number. "72 agree, 2 nest a block `solas` inlines" says
something; "74 tried" would have said nothing, and hiding the two would have
been a lie with a green tick on it.

## 2026-09-02 — `$pos`, and the sentence on the roadmap that was wrong

[ROADMAP 1.1](ROADMAP.md) asked one question and answered another. The question
was *what a position is to a description* — a line, a line and a column, or an
opaque value only the diagnostics understand. The answer it did not offer is
the one that turned out to be right:

```
Position(line, column, file)
```

**A node.** Which sounds like a detail and is the whole design. A number would
have been smaller and would have meant nothing: every use a description has for
a position is a line or the name of a file, and a byte offset into a buffer
nobody wrote is neither. A node makes reading part of one an *ordinary field
read* — `$pos.line`, `$pos.file` — so the notation needs no new syntax and no
library function to get at it, and a fourth thing later is a field rather than
a second reserved name.

And because `.` over a list already means "that of each", `$body.pos.line` is a
column of line numbers without anybody deciding it should be. That is the shape
a table in a binary format wants, and it arrived free.

### One word reserved, said out loud

`$pos` resolves **before** bindings, fields and attributes. It has to: a name
that means the position on one node type and a field on another is the shape of
quiet wrongness this project keeps checks for, and a description reading
`$body.pos` over a mixed list would get both.

So `pos` is a word a grammar may not call a field, and a description that does
is refused when it is read. That is a real cost and it is written in the warts
rather than left to be discovered — the same bargain `expression.phx` makes
when it reserves `and` and `or`.

### "Everything needed is already there" was wrong

The entry said the work was small because a node already carries its position.
Reading one *is* small: about thirty lines. Using one is not.

A `.sob` line table is a run per statement — its bytes at its line — and
writing one needs, for every element of a list, a value computed from it.
**The notation cannot say that.** `each` applies a *template* to a list, and a
template can only write an element out; it cannot ask for `size(x)` of one, or
for `x` as four little-endian bytes.

There were two ways forward and only one of them is small:

- a clause on **every node type that can be a statement**, each carrying the
  same line of notation. Twelve of them in Solveig, identical.
- the two operations, as a library entry and an extension.

The second, and the reason is the argument roadmap 3.4 makes about the library
being a visible thing: `sizes(list)` is the companion to `positions(list)` —
that one answers where each thing is, this one how big it is, and neither can
be asked any other way — and `bytes` taking a *column* of numbers is the same
function taking a list, the way `bind` already takes names pairwise and `each`
already takes two lists.

With those, the whole line table is one clause:

```
bodyruns = join(each(bytes(sizes($body.code), 4),
                     bytes($body.pos.line, 4),
                     "{}{}\x01\x00\x00\x00{}"), "")
```

— each statement's bytes at its line, then the one byte after it, the `POP`, at
the same line. A block drops eight bytes off the end of that table for the same
reason it drops one byte off the end of its code: its last statement has no
`POP`. The run count is measured off the table rather than counted from the
body, because the loader adds the runs up and refuses a file whose lines do not
account for every byte.

### The case that stayed open, and what it is evidence for

The file table did not fall out. A chunk holding code from two files — which is
what `@include` made possible last night — needs a run per statement naming a
**row of a table of the distinct files**, and that is a `lookup` per element:
the third case of the same missing thing, and the one two library entries did
not cover.

So the file table is written when a chunk is about **one** file, which every
block is and every program that does not include is, and otherwise it is not
written at all. That is the format's own answer for the case — bytes belonging
to no file print a bare line — and it is the right one, because a line number
naming a file nobody said reads as a line of the file you were looking at and
is worse than saying nothing.

**Three cases of one missing mechanism in a single stage** is what
[ROADMAP 1.3](ROADMAP.md) was waiting for, and it is not the shape it expected.
1.3 was written about *repetition*: the same computation spelled out once per
node type. This is narrower and worse — a computation the notation cannot
express at all, patched twice by adding to the library and left open the third
time. A map with an expression would have covered all three, and it is the
mechanism that page keeps warning about.

### What it bought, measured

The Solveig oracle **stopped normalising locations away**. It used to replace
every `[...]` in a program's output before comparing, because every message
from bytecode written here said `[line 1]`; now the file and the line are
compared like any other byte.

- **66 programs print exactly what `solas`'s bytecode prints**, tracebacks
  included. Four of them have real tracebacks and match to the character.
- **7 differ in a traceback line and in nothing else.** Every one is the
  inlining of [ROADMAP 2.4](ROADMAP.md): a block that is really a block is a
  frame `solas` has not got, and the frame around it points at the statement
  the block is written in rather than at the send inside it. Six of those also
  lose the file name, which is the open case above — but `programs/log.sol` has
  no include, gets its file table, and still differs by a line, which is what
  proves the two causes are separate.
- 2 are the nesting limit and the call depth, the same inlining seen twice
  more; 1 does not print the same thing twice under `solas` either.

**A test that stopped normalising also found a flaky one.** `programs/diff.sol`
prints a file's timestamp to the second, and the check for that ran the oracle
twice back to back — which nearly always agrees — before running this backend a
moment later, on the other side of a second boundary. The two oracle runs now
*bracket* the one under test, so a clock that ticks anywhere in the window is
reported as a program that does not repeat itself, which is what it is.

## 2026-09-02 — the block that should not be there

[ROADMAP 2.4](ROADMAP.md) said inlining was "the first thing the `.sob` backend
cannot express rather than has not got round to", and left open whether that
was a gap in the notation or in that description. It was neither, quite. It was
a gap in what a **pass** is.

`solas` compiles the block of an `ifTrue:`, an `ifFalse:`, an `ifElse:`, an
`and:`, an `or:`, a `whileTrue:` and a `doUntil:` into the enclosing chunk,
behind a jump, whenever the block is written right there with no parameters and
no temporaries. This backend compiled every block as a block, and three things
followed: an extra frame in every traceback, `programs/pascal.sol` nesting 19
deep where the format allows 16, and `programs/basic.sol` running out of call
depth one test early.

### The thirty lookups that were not written

The obvious way in was a clause: match the send, and emit jumps instead. Two
things were in the way.

**A pattern could not ask the question.** `Send(args: [Block(params: [])])` is
exactly the shape, and a pattern could not be a list — it covered nodes, text,
integers, booleans, nil and anything, which is every kind a value can be except
the one that holds several things. That is not a special case for an
optimisation, it is a hole, and it is filled: `[ a, b ]` and `[]` match a list
of exactly that many, each element matching.

**And the block would still have been there.** A `Block` node opens a chunk,
starts fresh name and constant tables, and pushes a frame's worth of slots. An
inlined one must do none of that: its body belongs to the enclosing frame.
Conditioning it on who the parent is meant threading a flag down and turning
about thirty clauses into `lookup([[true, ...]], $inlined, ...)` — in the rule
the journal already calls the thread that had to nest.

### What a pass cannot do

So the answer was [2.2](ROADMAP.md), deferred on day one and waiting for a
customer better than constant folding:

```
Send(to: c, message: "ifTrue", args: [Block(params: [], temps: [], body: b)])
  => IfTrue(cond: $c, body: $b) .
```

**A clause answers *about* a node. Some things are answered by there being a
different node.** The block is not something to compile differently; it is
something that should not be there. Take it out and what is left is a list of
statements sitting where the send was — and it compiles in the enclosing frame
because that *is* the frame it is in. `OP_OUTER` depths come out right with
nothing adjusting them, for the reason `solas` gives for the same thing.

That is the same argument `%include` made a day earlier from the other end. A
pass is a walk over one tree; there are things to be done to a tree that are
not walks over it, and each one has turned out to want its own mechanism rather
than a longer clause.

`%rewrite` cost about a hundred lines in `run.c` and no second implementation
of anything: the same `match_pattern`, the same `eval_expr`, with a traversal
that puts the answer back. A rewrite and a pass cannot disagree about what a
pattern means, because there is one of each.

**The strategy is a word rather than a default**, which the roadmap's sketch
already had right and which the fold test is there to show: `2 + 3 * 4 + 1`
folds to `15` bottom-up and stops at `((2 + 12) + 1)` top-down, because
top-down asks about the outside of an expression before its inside.

### The arithmetic that was not a fixup

The one thing a jump needs is an offset, and this is where the entry's worry
about "a jump over code in the middle of the chunk being built" turned out to
be about the wrong tool. `solas` writes `0xffff`, keeps the slot, and patches it
when it knows. A clause does not have a slot to patch — and does not need one:
**the code being jumped over is a value the clause is holding**, so its size is
a question rather than a fixup.

```
: code = join([$cond.code,
               bytes(14, 1), bytes(size($bodycode) + 3, 2), bytes($idx, 2),
               $bodycode,
               bytes(13, 1), bytes(1, 2),
               bytes(1, 1)], "") .
```

Every offset in all seven forms is that: the number of bytes between the end of
the jump and where it lands, which is a `size` of something already built. A
backwards `OP_LOOP` is the same arithmetic with the terms rearranged.

### What it fixed, and what it did not

| | |
| --- | --- |
| `programs/pascal.sol` | nested 19 deep and the loader refused what this wrote. It compiles and agrees now |
| `programs/basic.sol` | stopped one recursion test early. It agrees now |
| every traceback's *frames* | an inlined block is a frame that is not there, and there are no longer any extra ones |

**Sixty-eight programs print exactly what `solas`'s bytecode prints**, up from
sixty-six, and the two categories the test kept for this gap are gone.

Seven still differ, in a traceback line and nothing else, and the useful part
is that **the cause is no longer this entry**. Six lose the file name, because
their top-level chunk holds code from more than one file and the file table for
that is a `lookup` per element of a list. The seventh names the enclosing
statement's line where `solas` names the inlined statement's, because a chunk's
line table is a run per statement and splitting one is a run per element of a
list.

Both are [1.3](ROADMAP.md), which three stages in a row have now ended at, and
which is the only thing left between this backend and an oracle it agrees with
on every byte. That is a much better sentence than the one this stage started
with, and it was worth two mechanisms to be able to write it.

### And one more flaky test

Comparing tracebacks exactly means comparing everything exactly, and
`programs/system.sol` prints how long a loop took. The oracle's two runs
happened to agree while this backend's, a moment later, did not. Both are now
asked again — but only when they differ, which is two extra runs on the few
that get there rather than on all seventy-five.

## 2026-09-02 — the clause that was already the answer

[ROADMAP 1.3](ROADMAP.md) had been the most dangerous entry on the page for
three stages, and it said so itself: the obvious fixes were all a second
mechanism — a function, a macro, a rule other rules call — and *"each one would
be the first thing in the notation that is not a clause about a node, and the
reason this tool is small is that there is only ever one of those."*

It also said what to do about it: **wait for a second example in a different
language.** Three stages had ended at this entry and all three examples were in
Solveig, so the first thing worth doing was to look, rather than to design.

It was already written. `languages/pascal/pascal.phx` has `type = "void"`
**twenty-one times**, with a comment saying exactly why:

> *Everything else a walk reaches, so that a node above it can read a type
> without asking which kind of statement it was.*

### And the shape it settled

That comment is the whole answer, and it says the entry had been framing the
problem the wrong way round. The Solveig cases looked like *a map over a list*:
a `lookup` per element for the file table, a run per element for the line
table. Pascal's is not a list at all. What both are is **an attribute every
node has** — and a list of nodes then has a column of them for free, because
`.` over a list already means "that of each".

So the mechanism is not a map. It is the **general clause about a node**, which
is why the warning this entry carried for three stages turned out not to apply:

```
otherwise type = "void"
```

What a node answers with when its own rule works nothing out. It runs after
that rule, so it can read what the rule worked out, and only for the attributes
the rule left alone. A node with a *field* of the name reads the field, since
`.name` reads a field before an attribute — which is the node saying so itself,
and is exactly what this is "otherwise" to.

Twenty-one clauses in Pascal became one, and the 35 programs `fpc` checks are
what says it still means the same thing.

### Both open cases, closed

**The file table.** `otherwise fileidx` interns every node's file into the
chunk's table the way a name is interned, and a chunk's file runs are then
`$body.fileidx`. The table is saved and restored per chunk exactly as the name
and constant tables are — and a `Block` restores *and interns its own file into
the enclosing table* in one clause, because a block is a statement of the chunk
around it and its `OP_BLOCK` has to name a file like any other.

**The line table.** `otherwise runs` gives every node its own code at its own
line, and the seven nodes an inlined block became compose one from their parts:
the condition's runs, the jump at this node's line, the body's runs, the tail.

Sixty-eight programs agreeing with `solas` byte for byte became **seventy-one**,
and every message the backend produces now names the right file.

### What two library entries cost

`sizes(list)` and `bytes` over a list were added a stage earlier, and
`otherwise` would have covered both. That is worth writing down rather than
tidying away: [3.4](ROADMAP.md) says a library entry has to be something a real
pass needed and could not be written in the notation, and both met that rule at
the time. What the rule does not catch is **answering a question one case at a
time before seeing the shape of it** — and the cost of that is two entries in a
library the same page says to watch the size of.

### The four that are left, and what they are

Not 1.3, and not inlining either. All four fail inside a send whose arguments
run over several lines, and they name the line the statement *starts* on where
`solas` names the line it *ends* on:

```
path := system:arguments:size:greaterThan(#0):ifElse(
    { system:arguments:at(#1) },
    { | fallback |
      ...
      fallback }).
```

`solas` writes the `OP_SEND` after compiling the arguments, so the line it
records is the one the `)` is on. A node here carries **one** position and that
is its first token.

So the last gap is a second number, and the question to answer before adding
one is whether a position is a point or a **span** — `$pos.line` and
`$pos.column` are the start of one either way, and nothing until now has wanted
the end. It is [1.4](ROADMAP.md), it is four traceback lines in seventy-five
programs, and it is the first entry on that page that came from a measurement
rather than from a design.

## 2026-09-02 — the one thing the two of them could disagree about

The README's second claim, after the notation itself, is that `phx` and the
compiler it writes out **cannot** disagree: a generated compiler is the same
`lex.c`, `parse.c`, `eval.c` and `run.c` over frozen tables, so there is only
one implementation and nothing for two of them to argue about.

It was not true, and finding out took asking a question nobody had asked:
*what happens if the description that emits bytes is written out as a
compiler?*

```
$ phx --raw --driver sob solveig-sob.phx arrays.sol   →  2552 bytes of .sob
$ ./sobc      --driver sob arrays.sol                 →  3242 bytes of errors
solveig-sob.phx:644:24: error: this template has 1 {} and 2 values were given
```

### A literal may hold a NUL, and the length beside it is what says so

`emit.c` froze every string with `emit_string`, which measures with `strlen`.
A template like `"{}\x01\x00\x00\x00{}"` — a line-table row, four bytes of
little-endian one between two holes — arrived in the generated compiler as
`"{}\001"`, with the `len` field beside it still saying eleven. So the
generated compiler read six bytes past the end of a string `phx` never had, and
found one `{}` where the description has two.

Three kinds of thing can be one: a **grammar literal** (`phx.h` has said "a
literal may hold a NUL" beside `GNode.len` since stage 0), a **pattern**, and a
**template**. All three were frozen the same wrong way. The fix is that each is
written by its length instead, which is three lines and a helper.

**It had been broken since stage 7.** `solveig-sob.phx` has seeded its name
table with `"\x05\x00array\x02\x00of\x0a\x00dictionary"` since the day the
backend was written. Nothing noticed, because nothing had ever built that
description as a standalone compiler.

### And the flag it needed as well

The generated `main` had no `--raw`. `phx` grew one when the `.sob` backend
arrived — *a trailing newline is a kindness to a terminal and a corruption of a
binary file* — and the generated one kept appending. So even with the strings
right, a compiler written out from a description that emits bytes wrote a file
`phx` would not. Same flag now, same comment, same reason.

### What the test was, and what it is

```
ok    sum.calc: identical to phx, byte for byte
ok    a Pascal compiler, and it agrees with phx
ok    12 .sob files, byte for byte, from phx and from a compiler it wrote
```

The first two lines had been there for stages. Both compare **text a person
could read**, and neither was ever going to notice a NUL, because a description
without one cannot have the bug.

That is the lesson worth keeping, and it is not about strings:

> "There is only one implementation" is a claim about the code. That it
> **holds** is a claim about the tests, and it is only as strong as the widest
> thing they compare.

The suite now writes `languages/solveig/solveig-sob.phx` out as a compiler and
requires its `.sob` to be identical to `phx`'s over the twelve conformance
programs — a binary format, where a single wrong byte has nowhere to hide.
There is a smaller one beside it, `tests/grammars/nul-literal.phx`, which puts
a NUL in a grammar literal, in a pattern and in a template at once, so the next
person to touch `emit.c` finds out from a test rather than from a `.sob`.

Both fail against the previous commit. That was checked rather than assumed.

## 2026-09-02 — a node is a stretch, not a point

[ROADMAP 1.4](ROADMAP.md) was the only entry on that page that came from a
measurement rather than from a design, and it posed one question: **is a
position a point or a span?**

It is a span, and four programs are what said so. All four failed inside a send
whose arguments run over several lines, and named the line the statement
*starts* on where `solas` names the line it *ends* on:

```
path := system:arguments:size:greaterThan(#0):ifElse(
    { system:arguments:at(#1) },
    { | fallback |
      fallback := "build/example-access.log".
      system:writeFile(fallback, sample).
      fallback }).
```

`solas` records the line of the token it has just read. By the time it writes
the `OP_SEND` for `ifElse`, that is the `)` on the last line — because **a
send's own bytes go in after its arguments**. A node here carried one position,
its first token, and had nothing to say about that.

```
Position(line, column, file, endline, endcolumn)
```

Every value now carries where it ends as well as where it starts: a token ends
at its last byte, and a node ends at the last byte of the last token its
sequence consumed. That is one field on `Value`, one on `Eval`, and about
fifteen lines between `parse.c` and `run.c`.

### The clause that was wrong by one word

```
Send : runs = join([$to.runs, join($args.runs, ""),
                    bytes(4, 4), bytes($pos.endline, 4)], "") .
```

`$pos.line` to `$pos.endline`, and 71 programs became 72. `Bind` and `SetSlot`
store after their value, so the same change took it to **76** — every `.sol`
file in the Solveig repository. `Array`, `Dictionary`, `Pair` and `Group`
compose theirs too, which changed nothing measurable and is right for the same
reason: a composite node's line runs are its children's, in the order it writes
their bytes, which is the order it already wrote them in. **The bytes and the
lines are the same walk.**

### What the test says now

```
76 programs print exactly what solas compiled prints, 0 do not
   (1 do not repeat themselves)
```

**Nothing is normalised and nothing is counted apart.** The `sed` that replaced
every `[...]` before comparing is gone; so is the rule that let a difference
count as "only a traceback"; so are the categories for the format's nesting
limit and for the call depth. A traceback names a file and a line and both are
compared like any other byte.

The one thing still set aside is a program that does not print the same thing
twice under `solas` either — `programs/system.sol` prints how long a loop took.
That is not a disagreement about compiling and it never was.

### The field nothing asked for

`endcolumn` came along with `endline` and nothing uses it. It is there because
a position is a line *and* a column at both ends or at neither, and a shape
that is right is cheaper to keep than a shape that is minimal. That is the
second field on `Position` in that position — `column` was the first — and both
were free because `$pos` answers a node.

Which is the small vindication of the decision two stages ago not to make a
position a number. Every time this has needed to say more, it has been a field.

### Where that leaves the page

[Section 1](ROADMAP.md) has one entry left, and it is the one that page has
twice said is not worth doing: compiling the tables to code, measured, weak,
and the only thing on it that would create a second implementation of the
notation. Of the four borrowed entries, two are done and two are the two it
said to be sceptical about.

The Solveig oracle has nothing left to say. That is worth noticing: it has been
the sharpest instrument in this repository for five stages, and it has run out
of disagreements. **The next real evidence has to come from a language nobody
here has described yet.**

## 2026-09-02 — the specification, made to run

Two commits ago a bug turned up by asking a question nobody had asked: *what
happens if the description that emits bytes is written out as a compiler?* The
answer was that `phx` and the compiler it wrote disagreed, silently, and the
lesson written down at the time was that **a claim about the code is only as
strong as the tests that compare it**.

So: what else is claimed and not compared?

[`docs/semantics.md`](semantics.md) is the specification. It says what the
meta-language's arithmetic, comparison, text and formatting *are*, in Phoenix's
own terms, "so that a second backend has something exact to agree with", and
`eval.c`'s header says the two are changed together or not at all.

**Nothing checked that.** Every test in this repository asks about a language
being *described* — Pascal against `fpc`, Solveig against `solas`, calc through
two backends. None of them asks about the notation doing the describing. The
page and `eval.c` could have drifted a claim at a time and the suite would have
stayed green the whole way.

### The page as a description

```
Case ! not ( 7 div  2 =  3) : "7 div 2"
     ! not (-7 div  2 = -4) : "-7 div 2"
     ...
     ! not ((-7 div -2) * -2 + (-7 mod -2) = -7) : "the identity, -7 and -2"
```

Forty-four checks, in the order the page makes its claims, and a check that
fires names the sentence it came from. There is nothing new in the notation
here — a check is what a description already uses to refuse a program, pointed
at the tool instead.

Two of them are asserted by **not failing**, which is the only way to observe a
short circuit from inside:

```
! (false and (1 div 0 = 0))   : "and short-circuits"
```

The right-hand side divides by zero. If `and` ever stopped short-circuiting,
this would not report *"and short-circuits"* — it would report *"division by
zero"*, which is a better message than the one written for it.

### And the half a specification usually leaves out

A page that says only what works is half a page, and the half it leaves out is
the one two backends drift apart in: an implicit conversion one of them makes
and the other does not is exactly the silent disagreement the page exists to
prevent. So `semantics-refused.phx` is thirteen clauses that must not work —
`1 + 1.0`, `"a" + "b"`, `int(1.5)`, overflow, `div` by zero, negating the most
negative integer, `nil + 1`, `1 < "1"`, `not 1`, formatting a nil or a list,
`...` of a non-list.

A clause whose value cannot be worked out reports and leaves a failure behind,
and the clauses after it still run — so one description asks for all thirteen
at once, and the test checks that every message the page promises is among
them.

### The conformance rule, applied to the page it is about

Both halves run through `phx` **and** through a compiler `phx` wrote. The
assertions have to hold in both. The refusals have to produce **the same
complaints, byte for byte** — which they do, and which is the strongest form
the rule takes anywhere in this repository, because the thing being compared is
the tool's own account of what it means.

```
ok    44 claims from docs/semantics.md hold
ok    and every refusal it names
ok    and hold in a compiler phx wrote
ok    with the same complaints, byte for byte
```

### Checked, rather than assumed

Deleting one line from `div_floored` — the correction that makes division
floored rather than truncating — makes four claims fire and two tests fail,
each naming the sentence on the page that stopped being true:

```
error: -7 div 2
error: 7 div -2
error: the identity, -7 and 2
error: the identity, 7 and -2
```

That was run rather than reasoned about, which is the same discipline the NUL
tests got and for the same reason: a regression test nobody has seen fail is a
regression test nobody has tested.

**A specification nothing runs is a document about a program**, and it drifts
from it one sentence at a time. This one runs.

## 2026-09-02 — awk, and the two bugs a round trip could not see

The Solveig oracle had run out of disagreements, and the note at the end of
that stage said the next evidence had to come from a language nobody here had
described. This machine has `/usr/bin/awk`, so: awk.

### The first grammar that is not vendored

Pascal came with Wirth's report and Solveig with that project's `solum.bnf`,
both held character for character in `tests/` so that "reads the published
grammar unmodified" is a checkable claim. **There is no awk grammar on this
machine.** What `languages/awk/awk.phx` holds is the POSIX definition
transcribed into Wirth's notation, and the honest thing is to say so at the top
of the file rather than to imply otherwise.

What carries the weight instead is the oracle, and it carries more of it than
in either previous language: `/usr/bin/awk` decides what awk means, and
`tests/corpus/` is six programs that e2fsprogs, ncurses and vim ship — 800
lines of awk written by people who had never heard of this.

**All six parsed on the first run**, which was not expected and is the single
most useful thing the stage says about the notation.

### What awk is here to test

Pascal has statements, expressions and a type system, and 51 node types.
Solveig has one thing that happens and 12. awk has neither shape and 46: a
program is a list of pattern-action rules with no main; nothing is declared;
and **concatenation has no operator**, which is why its grammar is not LL(1)
and why `concat` here is a repetition of the rung below it.

```
concat = additive { a:additive -> Concat(left: $$, right: $a) } .
```

That is juxtaposition written down, and it is one line.

### The one place the description guesses

`/` is division and `/re/` is a regular expression, and **which one it is
depends on the parser**: a real awk lexer asks whether the previous token could
end an expression. Phoenix's scanner is longest match over the token rules and
has no such feedback, deliberately — [ROADMAP 3.3](ROADMAP.md) says a tool that
guesses the lexical/syntactic seam reports a correct file as broken.

So the description guesses instead, which is its business and not the tool's: a
regexp may not start with a space, a tab or an `=`, and must close on the same
line. That reads every regexp in the corpus and every division in it, because
nobody writes `a/b/c` without spaces.

**And `a/b/c` is checked in**, in `tests/divergent/`, together with the second
divergence — `f (1)` with a space, which awk reads as a concatenation and this
reads as a call, because saying otherwise means putting the `(` inside the
token and then `if(`, `while(` and `print(` become function names. Both tests
assert the *wrong* answer on purpose, so that a change to either shows up with
the old answer in it. A guess with a witness is a different thing from a guess.

### The two bugs, and why the round trip could not see them

Fourteen programs parsed, rendered and re-parsed to identical trees. Then the
oracle ran them:

```
awk: syntax error at source line 1
	do { printf "%d", i; i++ >>>  }; <<<
```

**A `;` after a block is not the same as a `;` after a statement.** awk wants a
*terminated* statement before an `else` or a `while`; a block terminates
itself, so `}` followed by `;` ends the whole `if` and orphans the `else`.
Written the other way — `if (c) x = 1 else y = 2` — awk wants the `;`.

So the rendering depends on the **shape of the branch**, which is what a
pattern is for:

```
If(otherwise: nil)  : show = "if ({}) {}" of ...
If(then: Block)     : show = "if ({}) {} else {}" of ...
If                  : show = "if ({}) {}; else {}" of ...
```

and the same three lines again for `do`. Both bugs re-parsed to the same tree,
which is exactly the failure a round trip cannot see, and it is the third time
this journal has written that sentence.

### The rung awk takes out

`print a > b` writes to a file. So a print's arguments cannot contain a
relation — and not just `>`: awk rejects `print 1 == 2` and `print 1 < 2` as
well, while allowing `&&`, `?:` and assignment. That is awk's own grammar
splitting `unary_expr` from `non_unary_expr`, and here it is the expression
ladder with **one rung removed**, duplicated because nothing in the notation
parameterises a rule.

Six rules copied, which is the largest piece of duplication in any description
here. It is the same shape [1.3](ROADMAP.md) was about and it is *not* the same
problem: `otherwise` answers "every node does this", and this needs "these
seven rules, but one of them differently". Worth remembering if a fourth
language wants it too; not worth a mechanism on one example.

### What it left on the roadmap

[2.1](ROADMAP.md) has been waiting for a language where a name is used above
where it is defined. awk is that language — `tests/conformance/functions.awk`
calls `greet` from `BEGIN` before its body appears, and awk resolves it — so
the entry is no longer waiting for a language. It is waiting for a **pass**
over the one it has, because what is described so far is a front end and
nothing has yet had to resolve that call.

Which is the same order Solveig was built in, and for the same reason: a
backend for a language whose parse is wrong is a backend written twice.

## 2026-09-02 — the entry that was waiting for a language, and lost

[ROADMAP 2.1](ROADMAP.md) — reference attributes, from JastAdd — had been
narrowed twice already. What was left of it was one sentence:

> **A reference that points *forward*** — to a node the walk has not reached —
> which is the only case a backward lookup cannot serve.

and one condition: *until a language that needs one is being described, this
stays unbuilt.* Pascal has `forward` precisely so that it does not need one.
Solveig sends messages and resolves nothing until it runs. awk was picked, in
part, **because it would need one**: a function may be called above where it is
defined, and awk resolves the call by name over the whole program.

```awk
BEGIN { print greet("world") }
function greet(who,   prefix) { prefix = "hello, "; return prefix who }
```

awk prints `hello, world`. So checking that a call names something has to see a
node the walk has not reached.

### It is two passes

```
%pass functions
  thread known = []
  Function : known = [...$known, [$name, size($params)]] .
  Program  : table = $known .

%pass calls
  Program : down declared = $table .
  Apply ! not defined($declared, $name)
          : "'{}' is not a function in this program" of $name .
```

One walk collects the functions and leaves the table on the root. **A leaving
clause on the root runs after the whole subtree**, so every function is in that
table wherever in the file it was written — the forward reference is answered
by the shape of the walk rather than by a mechanism. The next pass hands the
table back down, and attributes stay on nodes between passes, which is the
whole reason a `%driver` names a sequence.

Twenty lines, and it finds while *reading* a program what awk finds when the
call *runs* — on somebody else's input, on somebody else's machine. It flags
`outside/hello.awk` for calling `bindtextdomain`, a gawk builtin POSIX awk has
not got, which is a true thing about that file.

The arity check came free beside it, and with it the notation doing plurals the
way it does every other conditional — a table:

```
lookup([[1, ""]], lookup($declared, $name, 0), "s")
```

### So the entry loses

The cost of two passes is that the walk happens twice. The cost of reference
attributes is demand-driven evaluation and the cycle detection that walking
once avoids, and what it would have bought here is **one walk instead of two**.

The case two passes cannot do is a dependency that does not *stratify* — two
nodes each needing an attribute the other computes. Neither Pascal nor Solveig
nor awk has one.

Three languages described without wanting this, and the one picked because it
looked like it would want it did not. That is as close to an answer as this
project's roadmap gets, and it is worth more than the mechanism would have
been: **the entry can now be closed on evidence rather than left open on
politeness.**

### What is worth noticing about the shape of the answer

Every time this roadmap has been wrong, it has been wrong in the same
direction: it predicted a **new mechanism** where the answer was the
mechanisms already there, used in an order nobody had tried.

- 1.3 wanted a map over a list; the answer was an attribute every node has.
- 2.4 wanted a way to compile a block differently; the answer was to take the
  block out of the tree.
- 2.1 wanted a reference that points forward; the answer is that a root's
  leaving clause has already seen everything.

Three for three. The next entry that asks for a mechanism deserves the same
question first: *what does the walk already know, and when does it know it?*

## 2026-09-02 — awk compiled, and the first value that is not a machine word

`languages/pascal/pascal-c.phx` has no runtime worth the name. Its entire
preamble is four `#include`s, because Pascal's types *are* C's types: an
`integer` becomes a `long` and C does the work. `languages/solveig/solveig-sob.phx`
emits opcodes for a machine that already knows what a value is.

**awk has one type and it is not C's.** Every value is a string and a number at
once; `$1 == "10"` and `$1 == 10` differ by whether the field *looks* numeric;
a variable never set is both `""` and `0`. None of that is optional — it is
what awk programs are written against — so a compiled awk program carries a
runtime, and `awk-c.phx` is mostly that runtime.

```c
typedef struct { char *s; double n; int isnum, strnum; } Cell;
```

Two hundred lines of C, written and checked against awk *before* being embedded,
which is the only reason the rest went quickly. The subtle pair — a field of
` 10 ` comparing equal to the number 10, and an unset variable comparing equal
to both `0` and `""` — was right in the second attempt and has been right since.

```
ok    6 awk programs compiled to C print what awk prints, 0 do not
```

That is the conformance rule with a **third** language under it.

### What the backend taught the front end

Two bugs in `awk.phx` that reading 800 lines of other people's awk had not
found:

**`for (;;)` would not parse.** `optnl` — "any number of newlines or
semicolons" — is right between statements and wrong inside a `for` header,
where the semicolons belong to the header: the rule ate the second one and then
the grammar wanted a third. POSIX writes `newline_opt` in exactly those places,
and there is now an `nl` for exactly that. Fourteen awk programs had
round-tripped without touching it, because none of them writes an empty `for`.

**`For` shadowed its own fields.** The emit pass named attributes `init`,
`cond` and `step`, which are that node's *fields* — a field is read before an
attribute, so nothing outside the pass could ever have seen them. Phoenix's own
check said so the first time the description was read, which is the check
earning its place a second time.

**A backend is the test a front end cannot be given any other way.** That is
the argument for building one rather than admiring the tree.

### The conditional that evaluates both answers

`lookup` is a function, so both answers are worked out before it chooses. That
is fine until one of them cannot be:

```
lookup([[true, ""]], $init = nil, "{};" of $init.out)
```

An omitted `for` part was a nil, and `.out` of a nil is an error however the
condition comes out. [3.5](ROADMAP.md) says there is no `if` and that the first
thing it cannot express should be recognised as a decision arriving. This is
not that. The fix was in the **grammar**: an omitted part now builds a
`Nothing` node that renders as nothing, so every part is emitted the same way
whether it is there or not and the question stops being asked.

Third time the answer to *"the notation cannot say this"* has been *"say
something else, earlier"*. 1.3 wanted a map and got an attribute; 2.4 wanted a
special case and got a rewrite; this wanted a conditional and got a node.

### And a second customer for `otherwise`

An expression is a statement too, and the tree cannot say which: `x = 1` is an
`Assign` whether it stands alone or sits inside something. So every node
answers a `stmt` as well as an `out`, and the default is *the expression with a
semicolon after it*:

```
otherwise stmt = "  {};\n" of $out
```

Nine statement kinds override it; the twenty-odd expression kinds say nothing.
That is `otherwise` in a second language, doing the thing it was added for, and
it is the strongest evidence yet that [1.3](ROADMAP.md) landed on the right
mechanism.

It also found a rough edge in it: a node whose **check fired** was still having
its defaults worked out, so a refused node reported its refusal and then a
consequence of it. `run_defaults` takes the block now, for the same reason
`run_clauses` always has — one mistake, one message.

### The two hundred lines, and where they live

The runtime is a list of one-line literals joined with newlines. It is exactly
what `pascal-c.phx` does with its four `#include`s and it is fifty times the
size, which is the first time the shape has been big enough to argue about.
Nothing in the notation reads a file at emit time, so there is nowhere else to
put it.

[1.5](ROADMAP.md) is the entry for that, and it is written down rather than
built because there is **one** customer. What it would cost is on the page: a
description that names a file it does not contain stops being one thing, and
`-o` writing a compiler that needs a file beside it would be the end of *one
file, no headers, no library*.

## 2026-09-02 — arrays, functions and regular expressions, and three questions `otherwise` answered

Stage two of the awk backend: the parts that need a hash table and a regular
expression engine. `<regex.h>` is POSIX and is what one-true-awk's EREs are
close enough to; the hash table is a hundred lines. The runtime went from two
hundred lines to three, and — as in stage one — **it was written and checked
against awk before being embedded**, which is why the rest went quickly.

```
ok    10 awk programs compiled to C print what awk prints, 0 do not
```

Arrays with `in`, `delete` and `for`-in; functions with locals, recursion,
calls above their definition and **arrays by reference**; patterns, `~`, `!~`,
`match`, `sub`, `gsub` and `split`.

### Three questions the tree could not answer, and one mechanism that could

Every one of them is the same shape: *what is this node, when it is used
**here**?* — which a clause cannot ask, because a clause is keyed on what a
node **is**.

| | |
| --- | --- |
| `stmt` | `x = 1` is an `Assign` whether it stands alone or sits inside something. A statement wants a `;` after it and an expression does not |
| `argout` | a variable handed to a function has its array made first, because an array is by reference and a scalar is by value and awk decides which by what the callee does. Anything that is not a variable is passed as it stands |
| `reout` | a regexp on its own matches the record; handed to `sub` or `split` it *is* the pattern. `Match` can ask with a clause pattern, because the regexp is a **field** of it — an argument is in a **list**, and a clause cannot reach into one |

`otherwise` answers all three, one line each, and the nodes that differ say so.
Without it each would have been the same clause written once per node type —
twenty-odd times, three times over.

That is the mechanism [1.3](ROADMAP.md) landed on, in its third language,
answering a question nobody had when it was built. It was added for *"an
attribute nearly every node answers the same way"*; what it turns out to be
good at is *"an attribute about the **position** a node is in"*, which is a
larger thing.

### Four bugs, and where each was actually wrong

**`(i, j) in a`** asked about a C comma expression. A parenthesised subscript
list is one SUBSEP key, and saying so is a clause pattern — `In(index: Group)`.

**An array's name was text.** `Index(array: "a", ...)` meant the pass that
collects a program's variables never saw it, because that pass looks at `Var`
nodes. An array name *is* a variable, so it builds one now. **The fix was in
the grammar**, which is the fourth time this week the answer to a pass that
could not ask something was a tree with a different shape.

**`substr("abc", 0, 2)`** was `"a"` and one-true-awk says `"ab"`: the start is
clamped to 1 and *then* the count is taken. POSIX can be read either way and
the oracle cannot, which is the whole reason for having one.

**`/ +/` will not parse**, and that is not a bug — it is the guess from stage
one, met in the wild. A regexp may not begin with a space here, because `a / b`
is division and nothing but a parser can tell them apart. It has a way out that
costs nothing (`" +"` is a string used as a regexp, which awk allows) so it is
a limit rather than a wall, and it is checked in beside the other two
divergences. **Found by writing a conformance program rather than by thinking
about it**, which is the useful kind of finding.

### What the shape of this stage says

Stage one was the hard one and it was hard in the runtime. Stage two is twice
the language and about the same amount of work, nearly all of it in C rather
than in the notation — because once a value is a `Cell` and a variable can hold
a map, an array is a hash table lookup and a function is a C function.

The description grew by about a hundred and twenty lines for arrays, functions,
regular expressions and eighteen builtins. That ratio is the argument for the
whole project, and it is the first time it has been visible on a language
nobody here designed.

## 2026-09-02 — the corpus, compiled

Stage three of the awk backend: output redirection and pipes, `close`,
`system`, `fflush`, range patterns, a multi-character `FS`, and the input awk
actually takes — the files named on the command line, `FILENAME`, `FNR`, and
`name=value` operands including `-v`.

The point of it was one line:

```
ok    13 awk programs and 6 other people wrote compile to C that prints what awk prints
```

**The six are the corpus.** `et_c.awk` is 269 lines of awk that e2fsprogs uses
to generate C error tables. Compiled by `awk-c.phx` it becomes 1,149 lines of C
and prints the same 56 lines that `/usr/bin/awk` does, given the same input and
the same `-v outfile=`. Nobody who wrote it had heard of this project, and that
is the whole claim being tested.

### Two bugs found by compiling other people's code

Neither could have been found any other way — both are in constructs the
conformance programs written here did not happen to use.

**`sub(/,/, ", ")` with no third argument.** It works on the record, which
means writing the record back and splitting it again — and the emitter had a
placeholder for a `$0` that was never defined, so the C did not compile. Two
shapes told apart by how many arguments there are, which is what a **list
pattern** is for.

**`printf("%s %s\n", a, b)`.** A parenthesised list after `print` or `printf`
is *its arguments*, not one argument that happens to be parenthesised — and
that is how most awk is written. The tree cannot say which, because both are a
`Group` in the one place a group may be. It compiled to a **C comma
expression**, which is to say it printed the last argument and threw the rest
away, silently.

A clause would have needed four of them — print and printf, each with and
without a redirect — and each would have had to reach inside a list to find the
group. Written as a rewrite it is two rules:

```
%rewrite unparen bottomup
  Print(args: [Group(items: g)], to: t)  => Print(args: $g, to: $t) .
  Printf(args: [Group(items: g)], to: t) => Printf(args: $g, to: $t) .
```

**That is the third mechanism in a row doing something it was not built for.**
`%rewrite` was built to take an inlined block out of a tree; here it takes a
parenthesis out. Both are "the answer is a different node".

### And a mis-parse that was worse than a refusal

`getline` was not described at all, on the grounds that nothing compiles it and
the corpus does not use it. So it was not a keyword — and `getline line` read
as **two variables concatenated**. Ordinary awk, read as something else,
quietly.

That is the failure this project refuses to have, and refusing to describe a
construct is not the same as refusing it. Four of `getline`'s six forms are
described now, the node is refused by name with a position, and the other two —
`cmd | getline`, which needs `|` to be an expression operator — do not parse,
which is loud. **Mentioning the word is what makes it reserved**, and that is
the whole reason the four forms are in the grammar.

### The range pattern, and the position it is named after

A range is a rule with a memory, and the memory has to be a static with a name
nothing else uses. `$pos` answers where the rule was written, so the static is
named after it:

```
: id    = "{}_{}" of $pos.line, $pos.column
: ahead = "static int in_range_{};\n" of $id
```

Which is `$pos` doing something it was not built for either — it was added so
that a `.sob` could say which line an instruction came from.

### Where it stands

awk is described, checked, and compiled. Three descriptions, 458 lines for the
language and 1,187 for the backend, of which about 700 are the C runtime held
as literals — awk's value model, its hash tables, its regular expressions and
its input loop, none of which C brings.

The ratio is the argument for the whole project: **the awk in the corpus is
800 lines, the description that compiles it is 1,600, and the description
works on awk nobody has written yet.**

## 2026-09-02 — measuring awk, and the seven hundred lines that could not be compiled

The roadmap was down to entries it says not to do, so the next thing was to
measure rather than to build — which is what
[1.2](ROADMAP.md) rests on and what it had only ever been told about Pascal.

### awk is the grammar that ought to have broken it

Pascal's is a shallow ladder and an LL(1) shape. awk's is neither: fourteen
rungs from `expr` down to `primary`, **concatenation with no operator**, and a
`print` whose arguments need six of those rungs duplicated because `print a > b`
writes to a file.

| | |
| --- | --- |
| Pascal | 24 match-steps per token |
| awk, simple statements | **370**, flat from 705 tokens to 11,205 |
| awk, the corpus | 365 – 2,594 |

**A hundred times the constant and the same curve.** Sixteen times the input,
the same work per token; the expression shape gets *cheaper* per token as it
grows. And the constant does not matter: `et_c.awk` is 269 lines, 1,452 tokens
and 2.9 million match-steps, and it reaches running C in **50 ms**.

The figure that surprised me was the node count: **70,204 values built for
1,452 tokens**, nearly all of them made and dropped inside alternatives that
failed. That is what ordered choice costs and what memoisation would save, and
neither is worth a table per position at 50 ms.

So 1.2 is refused a third time, and this time by the hardest grammar tried
rather than by the easiest.

### And what the measuring actually found

682 of `awk-c.phx`'s 1,187 lines were **quoted C** — 58% of the biggest
description in the repository, held as one-line string literals.

[1.5](ROADMAP.md) was the entry for that, and it said to wait for a second
customer. **That was the wrong test.** There is still only one customer. What
made the case is a cost the entry had not noticed:

> Seven hundred lines of C inside a `.phx` **cannot be compiled**.

The runtime was written as a standalone file and checked against awk before
being embedded — twice, once for each stage — and both times the file was
thrown away and only the transcription survived. The artefact that had been
tested was not the artefact in the repository. Nothing would have caught a
change to the literals; `make test` compiled the runtime only as part of a
program generated from it, which is a much weaker thing to compile.

```
%embed runtime "awk-runtime.c" .
```

The file is read when the description is read and frozen into whatever `-o`
writes, so *one file, no headers, no library* still holds. It is looked for
beside the description and then in `lib/`, which is where `%import` looks;
`--imports` names it; and there is a test that the bytes survive being written
into a generated compiler, which is the lesson of the NUL bug applied in
advance.

**`awk-c.phx` went from 1,187 lines to 510**, and the 682 lines that came out
are byte-identical to the C that was tested — checked, rather than assumed,
because that was the whole problem.

### The rule this changes

3.4 says a library entry has to be something a real pass needed and could not
be written in the notation. 1.5 said to wait for a second customer. Both are
rules about *how many* — and the thing that decided this was **what the cost
was**, which neither rule asks about.

The cost here was not repetition and not size. It was that a tested artefact
and a shipped artefact had drifted apart with nothing able to notice. That is
worth adding to the questions a mechanism has to answer: not only *who else
wants this*, but *what can no longer be checked without it*.

## 2026-09-02 — where it stands

*A stopping point rather than an entry: what is true now, so that the next
session can start from the documents rather than from this one.*

### What exists

Three languages described and compiled, each against an oracle that is not this
project's:

| | |
| --- | --- |
| Pascal | 35 programs agree with `fpc -Miso`; 5 outside the subset are refused with a position |
| Solveig | **every** `.sol` file in that repository prints what `solas`'s bytecode prints — byte for byte, tracebacks included, nothing normalised and nothing counted apart |
| awk | 13 programs written here and **6 that e2fsprogs, ncurses and vim ship** compile to C that prints what `/usr/bin/awk` prints |

176 tests, 0 failing; 174 of them need nothing outside this repository.

[COMPLETED.md](COMPLETED.md) is the record — the tool, the languages, the
notation, every roadmap entry that has left with a verdict, and the defects
found with what found each one. [ROADMAP.md](ROADMAP.md) is now only what is
*not* built: three entries, one of which is a measurement that keeps coming out
the same way.

### What this run of stages added to the notation

`%include`, `%embed`, `%rewrite`, `otherwise`, `$pos`, and patterns over lists.
Six mechanisms, and the thing worth noticing is how few of them were the
mechanism that was asked for:

> Every time this project has predicted a **new mechanism**, the answer has been
> the mechanisms already there, used in an order nobody had tried.

- a map over a list → an attribute every node has
- a way to compile a block differently → take the block out of the tree
- a reference that points forward → a leaving clause on the root
- a conditional that skips a branch → a node that renders as nothing

Four for four. `otherwise` is the sharpest case: added for *"an attribute nearly
every node answers the same way"*, and what it turned out to be good at is
*"an attribute about the **position** a node is in"* — which answered three
questions in the awk backend that nothing else could ask.

### What the tests learned

Two claims on this project's own pages turned out to be false, and both were
found by asking what a test does **not** compare:

- *"There is only one implementation, so `phx` and the compiler it writes
  cannot disagree."* They did, for two stages, for any description with a NUL
  in a literal. The comparison had only ever covered text.
- *"docs/semantics.md is the specification and eval.c is what makes it true."*
  Nothing checked that. Every claim on that page is a check now, and every
  refusal a clause, run through both implementations.

The rule both leave behind: **a claim about the code is only as strong as the
widest thing the tests compare.**

### Where to look first

`README.md` for what the tool is, `COMPLETED.md` for what exists, `ROADMAP.md`
for what does not. The three things named as unfinished are `getline`'s two
piped forms in awk, scope graphs, and compiling the tables to code — and the
page says why none of them is urgent.

---

## 2026-09-03 — documentation, and what running it found

The tool was finished enough that the day's work was mostly about the pages
around it. Five documents for Phoenix — a manual, a reference, a cheatsheet and
two tutorials — then a website that builds them, then the same four documents
for a new language, then a week's worth of finding out that a page nobody runs
is a page that is wrong.

### The website, assembled rather than committed

`www/` holds a front page and a stylesheet; `.github/workflows/pages.yml` runs
`www/assemble.sh` on every push that touches `docs/` or `www/`. Nothing is
committed built, so the site cannot fall behind the documentation and there is
no generated HTML in the history.

The one thing that had to be worked around: **Jekyll's Liquid ate `{{`**, which
is how this notation writes a literal brace, so six of fourteen documents
refused to build. `assemble.sh` wraps each body in `{% raw %}`. Front matter is
added there too, rather than committed, because `docs/*.md` are read on GitHub
as often as on the site and YAML renders there as a stray table.

### An assembler for SolVM

`languages/solvm/` — 21 mnemonics, labels, nested blocks. It is the thing this
tool is most obviously for: every hard part of `solveig-sob.phx` is absent,
because in assembly the programmer says which slot and which frame. What is
left is the part that is not, and it is the two-pass shape `%driver` exists for.

Two mechanisms, because there are two questions. A side-table index is assigned
where a name is first seen — a fold over the walk, so a thread. A label is used
before it is defined, so it cannot be one, and is gathered instead. Both nest,
because a block is its own chunk, and `down` on a *threaded* attribute finally
has its second customer.

`count.sasm` is the loop-and-conditional listing printed in SolVM's own
`docs/BYTECODE.md`, typed back in by hand, and it assembles to that listing
exactly — every offset, every opcode, every side-table index.

### The oracle found the one thing reading did not

The CAPTURES flag was derived over nested chunks as well as this one, on the
reasoning that a frame read from below has to survive too. `solas` does not,
and says why in a comment above `touches_home`: *a nested chunk is not
consulted; its depths are counted from its own frame.* Both spellings run the
same program and print the same answer. **Only comparing the instruction
streams found it.**

### And then: run the documentation

Three tutorials were made executable this week, and the first two had been
"verified" by their author while writing them. That verification is worth
nothing, and it is worth understanding why: an author checks the commands
against files that already exist, in a directory that already has state.
Neither is what a reader has.

The solvm tutorial had four defects. Three were a `solvm` run on bytecode
nothing had reassembled after the source changed — the reader sees an answer
that has nothing to do with the file in front of them. The fourth was the
closing comparison, the step the whole page builds to, diffing a program with a
block against one without.

`docs/tutorial-assembler.md` had two: a command using a driver the page never
told the reader to write, and a line number captured from a file that already
had a later pass appended. `docs/tutorial-picture.md` had one, and it was a
caret line two spaces short.

All three now run in the suite, and each asserts that what came back **appears
verbatim in the page**. Confirmed to bite by drifting a field name in one and a
line number in another.

### Two roadmap entries left with verdicts

**1.6** — `|` as an expression operator, for awk's `cmd | getline`. Where the
rung goes is not guessable from the ladder around it, so it was settled against
`/usr/bin/awk`: looser than concatenation, tighter than a relation, a left
fold, no newline after it. Two of those four are things a description could be
*consistently* wrong about, which is why the round trip could not have settled
them. The entry predicted `printargs` would need telling where to stop; it
needed nothing, because awk keeps `|` as the redirect inside a print and says
so loudly.

**2.3** — scope graphs. The entry had scepticism and no evidence, so Turbo
Pascal's units were described to get some: `languages/units/`. Every rule
settled against `fpc -Mtp` first, including one a reading of the others gets
wrong. Resolution stayed a list, and a cycle between two implementations costs
nothing — because visibility does not compose, resolving a `uses` is one lookup
in a table the first pass built, not a walk. **There is no traversal for a
cycle to be a cycle in.**

So the entry's leading criterion, *modules that import each other*, is not
sufficient. What would bite is a language where visibility *composes*, and the
entry leaves saying so.

### A gap in the checker, found by using a feature

Adding a `slotnames` field called `names` to a node whose clauses save and
restore the interned `names` **thread** broke the assembler silently: a field is
read before an attribute, so the save read the field, the thread never passed
through, and the chunk came out with a name count of zero and the names still
in it. Three bytes wrong, no diagnostic.

A synthesised attribute of a field's name had always been warned about. A
threaded one had not, and it is the sharper case: the synthesised one is merely
invisible from outside, while the threaded one takes a value out of the fold and
puts a different one back. It is an error now. An inherited one is a warning.
And settling the third case turned up a documentation bug — `docs/manual.md`
stated the resolution order backwards, claiming a field is read before a
binding.

### What the day's last hour said about all of it

`docs/reference.md` § 11 was held by nothing: eighteen of the library's
twenty-two functions had no executable check. 66 claims later, **all 66 held.**

That is the useful result. Three tutorials and one reference section were made
executable this week; the tutorials had eight defects between them and the
reference had none. The difference is what the two kinds of page are *about*.
A tutorial's claims are about a sequence of commands in a directory, and go
stale when anything around them moves. A reference's claims are about the tool,
and the tool has tests.

**Run the documentation whose claims are not already held by something else.**
That is sharper than "run your documentation", and it is what this week
actually taught.

176 tests at the start of the day, 189 at the end.

### A last pass over the known warts

Closing the day, the standup said `ROADMAP.md` § 5 was *likely stale* — labels,
slots and threads had all moved this week, so surely two of the five entries
described behaviour that no longer happens.

**Checking found one, and it was a count.** *Three languages later this has
still not cost anything* is now seven grammars, and the claim is stronger than
when it was written: `languages/solvm/` puts `Label` above the mnemonics
because `n:word ":"` fails on `push` and falls through, and
`languages/units/` tries `slots 2` before `slots self, n`. Two descriptions
now **rely** on ordered choice rather than merely surviving it.

One sentence had become true again by accident, which is worth recording as
such: *`languages/awk/tests/divergent/` holds all three* was wrong yesterday,
when that directory held four, and closing 1.6 moved `getline-pipe.awk` out of
it. The remaining three entries had not moved at all.

The real gap was omission. Three warts were missing, all found this week:

- **There is no iteration over data.** A `%rewrite innermost` reaches a
  fixpoint over the shape of a tree, and nothing does that over a table — so
  transitive closure cannot be written, which is why `languages/units/` refuses
  a two-unit interface cycle and cannot refuse a three-unit one. Distinct from
  3.5: a conditional is a thing the notation says no to on purpose, and this is
  a thing nothing had yet made a case for.
- **A field can shadow an attribute handed down**, so a `down` clause may hand
  its children a value the node itself cannot read back.
- **`positions` is zero-based**, alone in a notation that counts from one
  everywhere else, and kept that way because what it exists for is slot numbers.

`docs/reference.md` mirrors the list and carried the same stale count; it is
corrected and gains the three in brief.

---

## 2026-09-03 — a slot with a name, after the day was closed

The second entry for this day, and the closeout above it was already written
when this began — which is the only reason it is worth saying so. The last
thing the assembler was left owing. `.slots self, total, i` had put
the names in the chunk since the day slot names went in — `solvm --trace` reads
them to write `value(n: #41)` — but an instruction still said `local 1`, and
the page said so in as many words: *names are for reading, not for addressing.*

### What it cost, and what it did not

The resolving is two passes, and it is the same two the assembler already is.
The script's frame is declared by a `.slots` that is a **sibling** of the
instructions using it and very often below them, so the names are gathered on
the way up in one pass and handed back down in the next — which is exactly what
`layout` and `sob` do for labels. A block needs neither pass, its frame being
in its own header; the mechanism is written once for the case that needs it.

Three things made it smaller than expected:

- **`positions` already existed and already answers slot numbers.** It returns
  `[value, index]` pairs and its index is zero-based — kept that way, says the
  warts list, *because what it exists for is slot numbers*. That is the whole
  of the name-to-number step.
- **The operand became a node**, `SlotNum` / `SlotName`, which is what `sel`
  already does for a selector written bare or quoted. Every instruction reads
  `$slot.num` without knowing which spelling it was given, so `layout` and
  `sob` changed by one token each rather than gaining a rule apiece.
- **A stack of frames did not need a stack.** `lookup` takes a table, and a
  list of tables would have wanted a second mechanism to index. Keying one flat
  table by `"<depth> <name>"` avoids it — a space occurs in neither half — and
  the chain from root to any node has strictly increasing depths, so the
  entries cannot collide.

### The evidence is that nothing changed

`REGOLD=1` rewrote the goldens and **git reported one new file and no
modifications**: five programs, byte for byte, through a rewrite that moved
every slot operand from a field to a child node. `programs/adder-named.sasm` is
`adder.sasm` with `outer 1, 1` and `local 1` written `outer 1, n` and
`local m`, and the suite puts both at one path — a chunk records the file it
came from — and compares the bytes.

The tutorial's step 6 now has a 6c that renames the block's frame and
re-assembles, and step 7 compares **that** build against `solas`: the named
spelling produces the instruction stream the compiler produces.

### The check that pays for it

`local 0` in a frame of two is a valid instruction that pushes the receiver
instead of the argument, and nothing catches it. `local nn` is not an
instruction at all. That is the only thing a name buys that the number does not
— the byte is identical — and it is worth the two passes.

Two refusals came with it and one came out of writing the message. A frame with
two slots of one name is refused, for the reason two labels of one name are.
And `outer 3, x` at the top level first reported *no slot is called `x` here*,
which is true and is not the mistake: **the lexical chain is as long as the
nesting**, so a chunk `n` deep has `n` frames outside it whenever it runs, and
a depth past that is knowable from the text. `outer 5, 1` had been silently
accepted until then, numeric spelling included.

> **A diagnosis that is true and not the mistake is a bug in the diagnosis.**
> The `$fdepth >= 0` guard on the slot-name check exists only to let the
> depth complaint win, which is the one that names what is wrong.

189 tests, unchanged — the assembler's own count went 49 → 58.

### Two stale numbers, found on the way past

`README.md` quoted the assembler's suite as `25 checks` and said it was among
`the 177`; the suite reports 58 and there are 186 that need nothing outside the
repository. Both were quoted output, which is the kind that goes stale in
silence — the same lesson the tutorials taught this week, one level up.
`COMPLETED.md`'s table of languages had no `solvm/` row at all.

### And then the check found a claim the manual had wrong

Asked whether anything was still open, the honest way to answer was to exercise
the three operand forms the day had not: `setlocl` by name, `setoutr` by name,
and `outer 0`. The first two resolved to the same bytes as their numbers, which
is what the rest of the feature already said they would.

**`outer 0, n` assembled cleanly and SolVM refused to load it.**

`solum/src/serialize.c:817` is `if (d < 1 || d > ancestor_count)`, and the
chain is indexed `ancestors[d - 1]` — so a depth counts from **one**, and depth
0 names no frame at all. The manual said the opposite in as many words: *Depth
0 is this frame, so `outer 0, s` is a roundabout `local s`.* It never was. The
cheatsheet's operand table said it too.

The check written an hour earlier had the upper bound and not the lower, which
is the same mistake in a smaller place: `d > ancestor_count` was transcribed
from the *behaviour* — a chunk cannot reach past its own nesting — rather than
from the line of C that states both halves. Reading the source would have given
both at once.

> **A bound taken from reasoning has one end. A bound taken from the code that
> enforces it has two.**

What makes this the third time this week: nothing about the feature required
`outer 0` to be considered. It came up because a slot written as a name has to
ask *which frame*, and asking that question out loud is what made the depth
worth looking at.

### One left, and it is the sibling of the one just fixed

`serialize.c` checks two things about an `outer`, and the assembler now checks
one of them. The other is `slot >= ancestors[d - 1]` — an `outer 1, 99` into a
frame of two — and it is still accepted here and refused at load:

```
$ phx --driver check ... w.sasm      # accepted
$ solvm w.sob
solvm: cannot load: an outer access names a slot that frame has not got
```

It is knowable statically for the same reason the depth is: every frame on the
chain declared its size, and `slotrefs` already carries a table keyed by depth.
It is left open rather than folded in because it would widen *slot n is past
this frame, which has m* from `local` to `outer`, and that message has a test
naming it.

### The sibling check, and the bound it made unreachable

Closing the gap left open above turned out to be a boundary correction rather
than an addition. `serialize.c` checks two things about an `outer`, and the
assembler checked one; the reason the other was missing is that it lived in the
wrong file.

`! $slot.num > $nslots - 1` sat in the `sob` pass. Its bound comes from a
`slots` **in the source**, not from the container — and `solvm-sob.phx`'s own
header says the file is *only the two passes that make bytes*, with the checks
about the program in `solvm.phx`. Moving it to `slotrefs` put it where the
frames already are, so it covers `outer` and `setoutr` for free:

```
$ phx --driver check ... w.sasm
error: slot 99 is past this frame, which has 2
          outer   1, 99
```

One check, one message, all four instructions — instead of the two-places-one-
job the other shape would have left.

**And it made a bound unreachable, which is worth saying out loud.** `layout`
also refused a slot wider than a byte. A frame is at most 255 slots, so *past
the frame it was declared in* is strictly tighter: there is no program the byte
bound catches that the frame bound does not, and the frame bound says something
useful when it fires. It only ever fired before because it ran first.

So it is gone, and `tests/slot-too-big.sasm` with it — its subject is not a
reachable state any more. The depth keeps its byte bound, because nothing
bounds a depth more tightly than the nesting does.

> **A check that only fires because it runs first is not a check, it is an
> ordering.** Moving the tighter one earlier is what exposed which was which.

The goldens did not move. 189 tests; the assembler's own count 59 -> 58, one
refusal retired and its subject folded into a message that already existed.

**And a count to correct, in the entry above rather than here.** `1db93b8`'s
message says the depth-zero test took the assembler from 58 to 60. It took it
from 58 to **59** — one test, one check. The number was written from memory
instead of from `grep -c '^  ok'`, which is the third counting error this week
and the second in a commit message, where it cannot be edited afterwards. The
run is cheap and the claim is not; there is no reason to have guessed.

### Asked a third time whether anything was open, and this time nothing was

Twice today "anything still open?" found a defect, so the third asking got a
method instead of a memory. Two sweeps.

**Every attribute in both descriptions is defined and read.** The refactor
moved `snames`, `sl`, `declared` and `ownnslots` between passes, and a move is
where a stranded definition hides. Counting definitions against reads found
none stranded, and `sl` reads only through `$items.sl`, which is what it is
for.

**Every rule in `verify_chunk` is accounted for.** `solum/src/serialize.c` is
the list the assembler is really measured against, and it had never been walked
end to end — the README's *what it checks, and what it cannot* was written from
what had been implemented rather than from what the loader refuses. Reading it
against the code: eleven rules, of which four are guaranteed by construction,
six are checked, and one is `verify_stack_heights`.

That last one was already named as out of reach, and the reason stands: two
paths reaching one instruction at different depths is a dataflow analysis, not
a walk over a tree. What changed is that it is now the *only* one, which is a
much stronger sentence than the list it replaces — and the README says so as a
table, so the next person can check it in a minute rather than an hour.

### The nesting bound, generated rather than reasoned about

`SOL_MAX_NESTING` is 16 and this refuses `$bdepth > 16`, which looks like the
same bound and is the kind of looking that was wrong twice today. So the
programs got generated: sixteen nested blocks with `outer 16, 0` at the bottom.

It assembles, loads and runs — `OUTER 0 ^16` in the dump, sixteen chunks.
Seventeen deep is refused here, and `outer 17` from the sixteen-deep one is
refused here. The edge is exact at both ends, and the `child_count` clamp in
`serialize.c` that looked like an off-by-one is unreachable: it bites at an
ancestor count of 16, whose children are 17 deep and already refused.

> **Two of today's three bugs came from reading a bound instead of running
> one.** Generating the program at the boundary costs a minute and settles it.

189 tests, `main` clean at `28f0045`.

## 2026-09-03 — a changelog, and the two tables that were about different things

The fourth stretch of a day that had already been closed out three times.

### The skill, twice rewritten and then removed

`day-closeout` had been left unrun since the day it was noticed that it would
damage this repository. Asked to fix it, the diagnosis went past the three
known collisions:

- Its captures ended at `(?:\.|$)`, so **any identifier with a dot was
  truncated** — `serialize.c` to `serialize`, `ROADMAP 1.2` to `ROADMAP 1`.
- `commit\s+([0-9a-f]{7,40})` **missed "Committed abc1234"**, the most natural
  phrasing, because `\s+` wanted whitespace and found `t`.
- A filter `if "day" not in item` **dropped every sentence containing
  "today"**, in an end-of-day tool.
- On seven lines describing a real day it extracted **zero** completed items
  and **zero** code references.

Two rewrites followed. The first replaced scraping with structured input and
added a provenance marker; it still owned filenames, so `roadmap.md` still
opened `ROADMAP.md`, and its guards ran per file — a refusal on the third
document left the first two written. The second discovered the documents
instead of naming them, which found `ROADMAP.md` and `COMPLETED.md` correctly,
and planned every change before applying any.

**Then it was removed anyway, and the reason is the one thing worth keeping.**
The plumbing was never the problem. A script can guarantee it writes the right
file, atomically, reversibly — and it still cannot know whether the summary it
was handed is the whole day. Asked three times whether it would *for sure*
document everything, the answer was no three times, for the same reason each
time. A tool that cannot fail loudly at the thing you actually want is worse
than no tool, because it reports success.

> **Automating the placement of a judgement does not automate the judgement.**

### The gap it did surface

Running its discovery against this repository listed five roles and found four.
There was no changelog — and looking for one is what showed the hole. Four
records existed and none answered *when*: `COMPLETED.md` is the standing
inventory, `ROADMAP.md` its complement, `journal.md` this narrative,
`postmortem.md` the scoring. Somebody arriving from the website could learn
what exists and why, and not when it arrived or what would break if they had
written a description last week.

[CHANGELOG.md](CHANGELOG.md) is that page, organised by the thing this project
actually versions by — the `stage-0` … `stage-7` tags — and ending with a
compatibility section that names what a description would have to change.

### Two tables, about two different things, and neither said which

Writing it from the tags found `COMPLETED.md`'s stage table disagreeing: `-o`
at 4 and Pascal at 5, where the tags have Pascal at 4 and `-o` at 5. The
journal settled it — there is **no stage 4 entry at all**, and the stage 5
entry is `-o`. `%import` was credited to 6; the commit adding it is inside 3.

Fixing that turned up why it had drifted. **The README has a stage table too,
and it is a different kind of table**: the original plan, ticked off, where
`COMPLETED.md`'s is the delivery keyed to the tags. They agree everywhere but
stage 4 — the plan put an emit pass writing C there, and it arrived early,
`examples/calc-c.phx` being present already at tag `stage-3`, so the `stage-4`
tag went onto the Pascal work instead.

> **Neither table was wrong about its own subject. Neither said what its
> subject was**, which is what let one of them drift for two days with a second
> table sitting in the README contradicting it.

Both say now, and the delivery table names the tags, so the claim is checkable
in one command.

### The page was wrong an hour after it was published

Asked again whether anything was open, the answer was to run `git log -S` for
each feature the changelog dates rather than re-read it. `otherwise` was listed
as one of six notation entries added on the 2nd. It was not added that day —
`067fff8 Stage 2: passes`, on the 1st.

What happened on the 2nd was better than what the page claimed. ROADMAP 1.3,
the entry that had carried a warning for three stages, **closed with no new
notation**: the mechanism was already built and `languages/pascal/pascal.phx`
was already using it twenty-one times with a comment saying why.

Five entries, then, not six — and the correction is worth more than the count,
because *an entry that closes because the answer was already written* is a
different and stronger result than one that closes because something was built.

Also softened: `$pos` becoming a span is listed as a breaking change, and it
and `$pos` itself landed the same day hours apart, so only a description
written between two commits is affected. Saying "breaking" without that is
louder than the truth.

189 tests throughout. `main` at `ccd8cb1`.

### The fourth measurement, and the harness that could not fail

ROADMAP 1.2 has come out the same way four times. What changed this time is
what was measured: `languages/solvm/` is the **control** the first three
lacked. It has no expression grammar at all — an instruction is a mnemonic and
its operands, and the first token settles which rule matches — so it is what
this matcher costs when a grammar asks nothing of it.

**11 to 25 match-steps per token**, against Pascal's 12 to 31 and awk's 221 to
2,638. Three grammars, **240× apart in constant and identical in curve**, over
nine shapes. Two of the nine get cheaper per token as they grow.

> **The constant tracks how deep ordered choice must go before it commits. The
> curve tracks nothing.**

That is a stronger case than three measurements could make, because the
assembler is precisely where generating code would help least, and it is within
a factor of two of Pascal.

### The defect was in the instrument

`bench/run.sh` never checked whether `phx` had succeeded. On error `--stats`
prints nothing and the diagnosis arrives on the same stream, so
`awk '{print $9}'` picked a word out of the error text and the row looked like
a measurement.

**Two numbers in `performance.md` came from that** — `nest` and `blocks` at
n=1600, for shapes that cannot complete. A nested parenthesis costs **11 levels
of grammar recursion**, so the 10,000-level limit binds at about nine hundred
parentheses; the page had never distinguished a level from a paren, and reading
it could not have caught that.

> **A measurement harness that cannot report failure will report something
> else.** The numbers it invented were plausible, which is why they survived
> three readings of the page they were on.

And the awk figures had no generator anywhere in the repository — nothing could
reproduce them. `bench/generate-awk.awk` is that now, and its constant differs
from the old claim because the grammar gained a rung today, `|` for `getline`.
Reproducible numbers show that drift. Unreproducible ones hide it.

Timings re-taken while there: 20,000 lines of Pascal reach C in 189 ms, not the
238 the page claimed.

### 1.2 closed, and the roadmap emptied

The fourth measurement did not change the number and did change the decision,
which is the distinction the entry had been missing.

Three flat curves could not say *why* they were flat, because all three
grammars were expression languages. The assembler is the control: no expression
grammar at all, and **11–25 match-steps per token against Pascal's 12–31**. So
the constant tracks how deep ordered choice must go before it commits, the
curve tracks nothing, and generating code buys a constant factor on a matcher
already within 2× of the grammar that asks least.

Against that it costs a second implementation of ordered choice, of floored
division, of pattern matching. **Two implementations of one notation** is what
this project has refused everywhere else, and there is now a measurement saying
what refusing it costs: nothing anybody has asked for.

Closed **against**, with the reopening order preserved — tables first, code
checked against the interpreter that produced them.

### The section that emptied, and one entry that was in the wrong half

Sections 1 and 2 of the roadmap are now both empty. Nothing on that page is
open; what is left is what the project has decided *not* to have, what a
description is checked for, and the warts it knows about.

Filing 1.2 under *Settled, and not built* turned up **2.3 sitting in the wrong
half**. Its own first line reads *Settled against, and the way it was settled is
the point* — and it was filed under *Settled, and built*, where it had been
since the day it closed. The audit that caught it compared each entry's verdict
sentence against its section, which is a thing worth doing once per section
rather than once per entry.

> **A document with two halves will eventually have something in the wrong
> one**, and the check is cheap: read what each entry says it is, not where it
> sits.

Three entries are settled against now — 1.2, 2.1, 2.3 — and the README had said
*the one*.

## 2026-09-04 — the standup, moved out of the records it was never part of

`docs/daily-standup.md` was a working note filed among the records. It was
written at the end of each day to be read at the start of the next, which is a
different job from the five documents around it: they are written for a
stranger a year from now, and it was written for one person tomorrow morning.
It moved to `scratch/`, which is gitignored, and left version control.

**The evidence that it was never a record was that nothing linked to it.** The
five documents in `docs/` are defined as much by their cross-references as by
their contents — [ROADMAP.md](ROADMAP.md) and [COMPLETED.md](COMPLETED.md) are
two halves of one ledger and say so in every entry, [postmortem.md](postmortem.md)
scores what the other two predicted, and [CHANGELOG.md](CHANGELOG.md) answers
the *when* the rest decline to. A grep for the standup's path across the whole
repository before the move returned nothing outside the file itself. Three
documents mention *the standup* as an actor — what it estimated, what it
recommended against — and not one of them had ever needed to link to it. A
document that nothing points at, in a set whose discipline is pointing at each
other, was already outside the set; the move only wrote that down.

### What the move cost, and the wrong way to pay it back

It cost the handoff. The file the next session reads first is now a file in a
directory that session is told not to open, and one that a fresh clone does not
have at all. The first instinct was a stub in `docs/` — a small tracked file
whose whole content is the scratch path — and that instinct was wrong for a
reason worth keeping.

**A stub would have been a sixth document in a set of five.** The property that
makes those five work is that each answers a question no other one answers, and
the italic note at the top of each is that claim in writing. The stub's question
would have been *where is the other file*, which is not a question about this
project. It would have earned a heading, a cross-link from the others, and a
line in whatever counts them, all to say something that is not about compiling
anything.

What was written instead is [`CLAUDE.md`](../CLAUDE.md) at the root, which is
already the file whose job is orientation and which no record cross-links by
design. It names the standup's path as the thing to read first and then does the
part a stub could not: it says plainly that the path is **absent on a fresh
clone and on any day that was not closed out**, and gives `git log` and the five
documents as the way in for that case. A pointer that admits it often points at
nothing is honest in a way a stub in `docs/` would have had to pretend not to be.

> A document that has to explain where another document is has the wrong
> question. Move the pointer to the file whose question is already *where do I
> start*.

### What the audit found, which was nothing

The day's second half was an audit, and the useful result is that it changed
nothing. Sections 1 and 2 of the roadmap are still empty, `make test` is still
189 passing and 0 failing — the same count before the writing and after — and a
sweep for `TODO`, `FIXME` and `TBD` across every tracked file returns empty.
Nothing was owed to [ROADMAP.md](ROADMAP.md), so nothing was added to it; the
temptation to record *push the branch* on a page whose header says it lists what
is **not built** is the same category error as the stub, one document doing
another's job.

## 2026-09-05 — a second backend, and the string somebody had typed

The roadmap said nothing was open, and that was true of sections 1 and 2. This
day's work came out of **section 3**, which is the list of things deliberately
not built — and the thing that changed there was not a decision but a *cost*.

[§ 3.1](ROADMAP.md#31-an-interpreter-that-can-loop) refuses an interpreter that
can loop, and the refusal still stands: an attribute is computed once per node
in one walk, a loop needs its body evaluated a number of times that depends on
the program, and neither is a thing a value computed once can say. What the
entry also did was admit what the refusal costs — *"the conformance rule
therefore covers straight-line programs only"* — and then name the fix and
leave it unbuilt. That sentence had been sitting there since 2026-09-01.

**An entry in section 3 has two halves and only one of them is a decision.**
The decision was right and is unchanged. The cost was payable and had not been
paid, and nothing about an empty section 1 said so.

### What the hole actually was

The conformance rule is that one description, run two independent ways, gives
one answer. `sum.calc` has always had both legs: the suite takes what
`--run eval` says and holds the compiled binary against it, so nobody ever
typed 97 anywhere — two implementations agreed on it and the test records the
agreement.

`programs/fizz.calc` is the only calc program with a loop and a branch in it,
and it had one leg. `--run eval` refuses it by design. So the test read:

```sh
if [ "$got" = "1 2 300 4 5 300 7 8 300 10 11 300 13 14 300 " ]; then
```

That string is right. It is also **a person's answer, checked by that person**,
sitting in a suite whose whole method everywhere else is to make two
independent things agree. The gap was not that the expectation was wrong; it
was that nothing could have said so.

### Why awk, and why not the two easier answers

`calc-solveig.phx` was already a second backend and could not be this one. It
needs `solas` and `solvm`, which are not in this repository, so the suite can
only run it behind `PHX_TEST_SOLVEIG=1` — a leg that is absent on most machines
is not a leg. Its control-flow clauses are also missing on purpose, which is
the same fact from the other end.

A second **C** backend — the same tree emitted through `goto` and labels — was
the cheap answer and is the one worth arguing against explicitly. It would have
caught a mistake in its own clauses. It could not have caught a host assumption
leaking into the notation, because both legs would still divide the way C
divides, and *that* is what the two-backend discipline was for
([2026-09-01](#2026-09-01--solveig-parked-and-c-is-the-target)).

awk is wrong in a different direction, which is the whole qualification for the
job. **Its numbers are doubles.** `/` is floating division where calc's
truncates, so the backend has to write the model out as `int(a / b)` — the same
sentence [semantics.md](semantics.md) was written to force, met a second time
in a second host. And it costs no dependency at all: the Makefile builds
`phoenix/runtime.h` by piping through `awk`, so a machine that cannot run these
tests cannot build `phx` either.

### The mutation that proves it, and it is the interesting one

A test that has never failed is a claim about a test, so the backend was broken
on purpose twice. Removing the `int()` from division — the one clause that
models the host rather than spelling it — made awk print `300` fifteen times,
because floating division makes `n / 3 * 3 = n` true for every `n` and the
branch always takes the same arm.

**That output is plausible.** It is fifteen lines of a number the program
really does print, from a backend that is consistently wrong about the one
thing this project has a whole document to pin down. No interpreter leg could
ever have caught it, because the interpreter refuses that program. It is
exactly the failure the conformance rule exists to catch, and until today
calc's looping programs were outside the rule.

> A test whose expectation was typed by the person who wrote the code being
> tested is a spell-check, not a check. The suite knew that everywhere except
> the three programs the interpreter could not reach.

### What the estimate got wrong, which is in the postmortem

*"About fifteen lines"* against twenty-nine actual. The miss is scored in
[postmortem § 12](postmortem.md#12-about-fifteen-lines-and-what-a-second-backend-actually-cost)
and is worth one line here because of *where* the missing half went: nine of
the twenty-four clause lines answer for nodes calc's own grammar never
writes — `Binary`, `Compare`, `Logical`, `Negate` and `Not` all arrive with
`lib/expression.phx`. The other fifteen are calc's own, which is the estimate
almost exactly.

`calc.phx` has a comment directly above those clauses saying what importing a
grammar module costs. The estimate was made anyway.

> A cost written down in a comment is not a cost that has been counted.

### What the two files now say to each other

Both emit passes are twenty-four clause lines and **seventeen of them are
identical character for character**. The seven that differ carry five
differences, and each is the target forcing one: awk's special variables are
ordinary assignable names, so a variable gets a `_` prefix, where C would have
rejected `long printf = 3;` loudly and awk would have accepted `NF = 3` and
gone quietly wrong; `/` is floating; there are no declarations, so `let` and
`:=` are one shape; `print x > y` redirects to a file, so the argument list is
parenthesised; and the unit of execution is a rule, so a program is a `BEGIN`
block.

That is what `%import` was argued for, and it is the first time the argument
has been checkable rather than asserted: a diff between `calc-c.phx` and
`calc-awk.phx` is a list of the ways awk is not C, and contains nothing else,
because there is nothing else in either file to differ about.

### The sweep afterwards, and nine numbers that had gone quietly wrong

A status sweep the same afternoon held every checkable claim in the records
against the tree. **Nine numbers disagreed**, and the shape of the
disagreement is the part worth keeping: not one of them was ever wrong when it
was written.

`solveig` 1,108, `awk` 968 and `50 node types`, `solvm` 820 — all four entered
[COMPLETED.md](COMPLETED.md) on 2026-09-02 and 2026-09-03, and all four
descriptions changed *after*. `ee5c993`, the commit that made `|` an expression
operator, is almost certainly what turned awk's fiftieth node type into its
fifty-first. Nobody was careless; the numbers were true, and then the thing
they counted moved.

> A record's prose is written to be read again. Its numbers are written once
> and then quietly describe a repository that has gone on without them.

Two of the nine were **two hours old**. `480 lines` for calc went into the
ledger this morning and a comment block in `calc-awk.phx` grew by two lines
afterwards; `189 checks` in the README was corrected in the CHANGELOG and not
in the README. Same failure at a hundredth of the timescale, which is the
useful part: it is not a discipline problem that better care would fix, it is
that nothing *runs* these numbers. [semantics.md](semantics.md) has a whole
entry about that — a specification nothing runs is a document about a program —
and the counts in the ledger are in exactly the position `semantics.md` was in
before `tests/grammars/semantics.phx`.

The README's was the one that mattered, being the page a stranger reads first,
and it was the wrong *shape* rather than merely stale: *"186 of the 189, and
the two that drive `solas` and `solvm`"* counted skipped lines in one clause
and tests in the other. Measured rather than reasoned about, with the tools
removed: 195 passed with them, 191 without, four external tests reported
through two skipped lines. The claim the paragraph exists to make survived —
the suite does pass with nothing outside this repository.

### And the check that could not fail, found in the thing built to prevent it

The sweep also read [`tests/run.sh`](../tests/run.sh) and found that
`backends_agree`, written this morning, **checked neither program's exit
status** — and captured stderr for awk while not capturing it for C. Two
programs that both die print the same nothing, and the comparison would have
called that agreement. [COMPLETED.md](COMPLETED.md#defects-found-and-what-found-them)
already carries a row for this exact mistake reaching `bench/run.sh`, so it is
the second time, in the same repository, in a harness written to be trusted.

Probing the fix turned up something better than the fix. A calc program
dividing by zero:

| | |
| --- | --- |
| `awk` | fatal, exit 2, *"division by zero"* |
| C | **exit 0, prints `0`** — undefined behaviour, and on this machine the quiet kind |

**calc has never said what dividing by zero means.** Its `eval` clause refuses
it, but that clause reads `$right.val` and so is the interpreter's alone; a
compiled program has whatever the target does, and the two targets disagree.
That is the same hole `quotient` was written to close, one operator over: the
description borrowed each host's answer because it had not given one. It is
written down in [`calc.phx`](../languages/calc/calc.phx) beside the check that
misled, and left unfixed, because emitting a guard is a language decision this
calculator has not needed to make.

The pleasing part is the order. **The divergence was found on the same day as
the machinery that finds divergences, by using it.** Two backends existed for
six hours and had already caught something the interpreter could not see.

### Two claims reframed rather than picked

Two of the sweep's findings had no right answer and a better question.
`~12,900 lines of C11` counts `runtime.h`, 4,217 generated lines that are the
runtime re-emitted as a string literal — so the runtime is in the number twice.
Choosing 8,698 or 12,915 would have made one of two true readings disappear;
the ledger states both and says what separates them. Likewise
`languages/units/` was absent from a table of six languages in a tree with
seven directories, which reads as an oversight and is a decision — so the table
says so now, in a line, rather than leaving a reader to count.

> When a number has two honest readings, the fix is not to pick one. It is that
> the page never said which it meant.

### And one number that cannot be kept right, so it stopped being a number

The recount put `76 Solveig programs against solas` back in the README having
checked it. Two runs an hour later reported **77**, and then 76 again. Nothing
in this repository changed between them.

That leg counts `.sol` files in **another repository**, maintained by somebody
else on their own schedule. The number was never Phoenix's to know, and a page
that quotes it is a page that goes wrong on a commit made somewhere else — the
same dependency, one level up, that got `pascal.bnf`'s fixtures vendored into
this tree on 2026-09-01. [COMPLETED.md](COMPLETED.md) had already found the
right form and used it — *every `.sol` file in that repository* — so the README
now says that too, and lets the suite print whatever it counted.

> A number in a document is a promise to keep it right. Do not make that
> promise about a repository you do not control.

### And then the counts were made to run

The obvious answer to nine stale numbers is to be more careful. It is the wrong
answer, and the evidence was in the same sweep: **two of the nine were two
hours old**, written by somebody who had just measured them, in the session
that measured them. Care is what produced them. What was missing is what
[semantics.md](semantics.md) was missing before
`tests/grammars/semantics.phx` — something that *runs* the claim.

[`tests/counts.sh`](../tests/counts.sh) holds every count in the records
against `wc -l`, `--nodes` and the tree: eighteen checks, reported to the suite
as one. Each of the five kinds was mutated to confirm it bites, including
putting awk's stale `968` and `50` back and watching them fail.

**The interesting part was the count it cannot check.** The suite's own total
is the most visible number in the records and the one a test cannot assert,
because asserting it changes it. Making that a test would have meant a
fixpoint — *this check passes when the README says one more than the number of
checks that are not this one* — which is a puzzle wearing a check's clothes.

So it is not a test. It runs in `tests/run.sh` **after** the summary line,
where `pass` is final and nothing is still counting, and it fails the run
without being in it. The first time it ran it did exactly that, and `make` came
back with `Error 1` over a stale number, which this repository had never done
before.

*That immediately found a second thing.* The check fails on a machine without
`fpc` or Solveig, where the suite legitimately reports a smaller number — a
check about the records would have become a check about the machine. The fix
needed the suite to know what it had **not** run, and it did not: skips were
printed and never counted. They are counted now, and a guard declares how many
checks are behind it rather than how many lines it prints, so three Solveig
checks behind one guard count as three. An incomplete run says `193 passed, 0
failed, 4 skipped`, the summary the status sweep had wanted that morning and
could not have.

> A check that cannot say what it skipped is a check that reports a number it
> has no right to.

### The survey, and what a survey is actually for

The question was *what do comparable tools have that we do not*, and the useful
part of the answer was how little of it was new. [lineage.md](lineage.md)
already named JastAdd, Silver, Eli, UUAG, LISA, Kiama, Spoofax, Stratego,
Statix, Rascal, TXL, Nanopass, Coco/R, Cocktail and TREE-META. Of the features
those tools have and this one does not, **most were already refused with
evidence** — reference attributes lost to awk, scope graphs lost to Pascal
units, host-language actions and conditionals are design decisions with
reasoning attached.

So the survey's yield was three families the page had missed and two entries
that could be opened, and it is worth saying which came first: **the entries
did.** `languages/solvm/` has emitted `.sob` and been unable to read it since
the day it was written, and `languages/units/divergent/three-cycle.pas` has sat
there refusing to be refused. Both were recorded as *costs*. What the survey
supplied was not the problems but the **prior art** — Kaitai Struct's
`repeat-expr` for the first, JastAdd's circular attributes for the second — and
that is what moved them from a cost to somebody's solved problem.

> A survey of other tools does not tell you what you are missing. It tells you
> what the thing you already know you are missing is called.

The three families added are Kaitai and DFDL for binary layouts, Langium for
what a workbench looks like now, and the PEG error-reporting line — Ford's
farthest failure, then labeled failures, then recovery — which is the
literature for a limit this tool has and had never named.

### Two findings that are not roadmap entries, and why

**The parser reports one syntax error, at the wrong column.** Measured rather
than suspected: three bad statements give one message, where three bad *names*
give three. `print a +;` is reported at column 1 as *expected -, (, integer or
name, and found "print"*, because ordered choice discards why an alternative
failed and what surfaces is the outer position that gave up. That is a **wart**
— [5](ROADMAP.md#5-known-warts) — because no description is blocked by it. It
is also the weakest surface this tool has, for a project whose argument is that
a fault found while reading is found before anybody else sees it.

**The round trip rests on a hand-written renderer.** Three descriptions are
checked by rendering the tree and parsing it again, and this repository states
three separate times that a round trip can be green while the parse is
consistently wrong, *because what is written back out is wrong in the same
way*. Those renderers are 122 lines in awk, 51 in solvm, 46 in solveig, 16 in
calc, and **nothing checks that a `show` pass agrees with the grammar it
renders** — a person wrote both. SDF3 closes this by deriving the pretty-printer
from the grammar. It went into
[4](ROADMAP.md#4-what-a-description-is-checked-for), under *things no check can
reach*, rather than onto the roadmap, because no description is blocked and
that page's bar is a language that cannot say something.

Those two placements are the part of this worth remembering. The roadmap's
opening note says an entry names **why**, and its header says the next one
should arrive from a real language needing something — so a gap found by
*reading about other tools* does not qualify, however real it is. It goes where
the project already keeps things it knows and has not fixed.

### And a tenth stale number, in the record the check did not cover

[lineage.md](lineage.md) opened its argument with *5,300 lines of C11 against
the C standard library and nothing else*. The tool is 8,698 lines. Written on
2026-09-01 it was exact — 5,333 against a claimed 5,300 — and four days later
it understated by 63%.

**It survived a sweep that was looking for exactly this**, the morning after
`tests/counts.sh` was built to make the class impossible. Two reasons, and both
are instructive. The check covered `COMPLETED.md` and `postmortem.md` because
those are where the counts *were* — a check written from a list of known cases
rather than from the question *which records quote numbers*. And 5,300 is
close to what the **descriptions** now come to, 5,395, so the number reads as
plausibly about something. A stale number that looks wrong gets fixed; one that
looks like a different true number does not.

`tests/counts.sh` covers lineage.md now, and the mutation was run.

> A check written from the cases you found is a check against the cases you
> found. The question it should have been written from is *what kind of thing
> can be wrong*.

### `$pos` does survive a rewrite, and the check for it found something else

The standup's one untested item, answered: **it survives.** A `%rewrite` that
folds `2 * 3` to `6` gives a node claiming `1:3..1:5`, which is exactly the span
the `Binary` it replaced had. `run.c` copies `v->pos` and `v->endpos` into the
builder on purpose, with a comment saying why, and the behaviour matches the
comment at an inner node as well as at the root.

**Two corrections to what the standup said.** It claimed *nothing in the records
discusses it*. [reference.md](reference.md) has discussed it since `%rewrite`
shipped — *a node built by a rewrite takes the position of the node it
replaced, so a later diagnostic points at the program rather than at the rule.*
The claim was there and nothing ran it, which is the position `semantics.md` was
in before it became a test. It is two checks in
[`tests/grammars/fold.phx`](../tests/grammars/fold.phx) now, and breaking the
copy in `run.c` was tried, and caught.

### And the syntax-error wart was diagnosed wrong this morning

Written up a few hours earlier as *ordered choice throws away why an
alternative failed, so the error surfaces at the outer position that gave up.*
That is the textbook problem and it is **not** the one this tool has.

`parse.c` already implements Ford's farthest-failure heuristic — `note_want`
tracks the highest token index ever reached and the set of things wanted there.
The reference documents it. It works. There are two failure paths and the
second throws the answer away:

```c
if (got < t->n) {
    /* The goal matched, and there is more file. */
    p.furthest = got;
    report_failure(&p);
```

`furthest` is overwritten with the first leftover token — deliberately, and
defensibly, since that is the first thing the parse could not use — but
`p->wanted` is **not cleared**, because clearing it is `note_want`'s job and
`note_want` was bypassed. So the message pairs one position's token with
another position's expectations:

    print a +;
    ^ error: expected -, (, integer or name, and found "print"

`print` is legal at that column. The same file parses with the expression
finished. The expectations belong to the `;`, eight columns along.

**And a start rule that is a repetition can never fail outright.** `program = {
statement }` matches zero statements and succeeds, so in every language
described here *every* syntax error takes the second path. The wart is
universal and was recorded as a guess.

> The heuristic was not missing. A code path was discarding its answer, and the
> literature was the wrong place to look for that.

*What this says about the survey.* Reading about how other tools solve a
problem told me what the problem is called and predisposed me to assume Phoenix
had it in the textbook form. It did not. **Naming a limit from the outside is
worth doing and is not evidence about the inside** — the fifteen minutes in
`parse.c` were worth more than the afternoon of comparison, and would have been
worth more still if they had come first.

### And then it was fixed, which took four lines

The wart above lasted an afternoon. `parse_run` keeps the furthest point unless
nothing got past the leftover token, and clears `nwanted` in that fallback
because moving the position invalidates what was wanted at the old one:

```c
if (p.furthest < got) {
    p.furthest = got;
    p.nwanted  = 0;
}
```

Every case improved and none regressed. `let a := 1` with a missing semicolon
was reported at **1:1** — the first character of the file — and is now reported
at the `print` on line 2, which is where a person notices it too.

**Two things the fix turned up that the diagnosis had not.**

*A test was pinning the defect in place.*
`languages/awk/tests/divergent/spaced-regex.awk` asserted the message contained
`and found "BEGIN"`, which was the parser blaming the first token of a file for
a fault 34 columns into line 13. It read like a test of the divergence and was
a test of the bug. The new expectation is the **position**, which is what that
divergence is actually about — and the caret now lands on the `/ +/` the
description cannot read.

> A test written from observed output records the behaviour, not the intent.
> When the two differ, the test is what keeps them apart.

*And `tests/counts.sh` caught its own author, four hours old.* Editing
`parse.c` grew the tool by fourteen lines and three records went stale at once
— `COMPLETED.md` twice, `lineage.md`, and `postmortem.md`, which the check did
not yet cover and does now. The suite refused the build before the commit
existed. That is the first time a number in this repository has been wrong for
less than a minute.

### The sweep the standup asked for, and it found its own author twice

The carry-forward was *an expectation nothing derives* — a literal pasted from
a run rather than worked out from the intent. Every `prints`, `refuses` and
`warns` in the suite was read against that test. **Three hits out of
seventy-three**, and the shape of the misses is the more useful half.

**The fifty-three `refuses` are almost all right, and right in the same way.**
They match a distinctive phrase from the diagnostic's *intent* — `left-recursive`,
`a check runs before the attributes it guards`, `is a pass as well as a
rewrite`. A phrase like that is a restatement of the rule being enforced, so it
cannot be pasted from a run without saying what the run was for. That is a
pattern worth naming, because it was arrived at fifty-three times without being
written down anywhere.

**One `refuses` was the opposite failure**, and it is the more dangerous kind:

```sh
refuses "a reserved word as a name" "expected"
```

`"expected"` is in every parse error this tool emits. The test asserted that
`let print := 1;` was *refused* and nothing whatever about why — a missing
semicolon in an unrelated file satisfies it, which was checked. It has the
name and the position now, and the missing semicolon was checked again and no
longer passes.

> A test can fail to derive its expectation in two directions. A pasted literal
> says too much about one run; a fragment this loose says nothing about any.

**And the other two hits were three hours old and mine.** The checks written
that afternoon for `$pos` surviving a rewrite pasted a thirteen-column span
tree —

    ((2@1:1..1:1 + (3@1:5..1:5 * 4@1:9..1:9)@1:7..1:9)@1:3..1:9 + 1@1:13..1:13)@1:11..1:13

— which is exactly the thing the standup had complained about, written by the
person who wrote the complaint, in the same session. It is unreadable, and
worse, it silently encodes a rule nobody had written down.

*That rule is the fourth finding.* **A node's span is the syntax that built it,
not everything underneath it.** An action on a whole alternative gets the whole
alternative — `Print` covers `print a;` — but an action inside a repetition
gets that turn only, and every binary operator here is built by a left fold
where `$$` came from an earlier turn. So `Binary` starts at its **operator**:
in `1 + 2` it claims columns 3 to 5 while its left child is the `1` at column
1. **A parent's span does not necessarily enclose its children's.**

That is probably the right behaviour — it is what a diagnostic about an
operator wants — and it was undocumented, which is why the pasted literal could
not be checked by eye. `reference.md` says it now, and the test is `2 * 3`,
three tokens at columns 1, 3 and 5, verifiable by counting.

The rewrite check **derives** its span now: whatever the root claims before the
fold is what the folded node must claim after. Breaking the copy in `run.c` was
tried again and caught — `root claimed 1:11..1:13, folded said 15@1:1..1:1`.

> The discipline is not *write better literals*. It is that an expectation
> should be produced by something other than the code under test — the other
> backend, the other run, or arithmetic a reader can do.
### The first sentence, which was true of yacc as well

The page opened with *you write a language's grammar in EBNF and describe what
each construct means*. That is true, and it is also true of the front half of
yacc — the thing that separates this tool from yacc was sixty lines further
down, in the section arguing about the name. It leads now: **a compiler is a
grammar plus a sequence of tree walks, and both halves can be written down
instead of programmed**, then what a `.phx` file therefore holds and what comes
out of it.

Four copies carry it — this page's README, `CLAUDE.md`, the landing page and
the repository's own description on GitHub — and only the last had a limit
worth recording. A description there caps at 350 characters and the sentence is
357, so *standalone* came out of that copy and stayed in the others.

The meta tags took a **shorter form rather than the same one truncated**. A
search result is cut near 160 characters and a link preview near 200; the full
two sentences would have been severed mid-clause in front of exactly the
readers who have not arrived yet. 179 characters, same claim.

The hero was the one worth looking at twice. Pasted in full it became eight
lines of large type above the pipeline diagram, because `.hero .tag` is capped
at 46 characters wide — and the page's own three sections already say the
detail at more length than a lede should. It stops at *instead of programmed*.

### The name, asked properly and kept

The section arguing that *compiler-compiler* is the older and better word had
never said who else holds the shorter one. Asked directly, the answer is that
**the word is taken everywhere except here**: Elixir's framework owns the
search term, Arize's owns the AI-observability one, Apache Phoenix is SQL over
HBase, and none of the three is a compiler generator. Searching GitHub for one
that is turns up coursework.

The namesake in the same field is dead. **Microsoft Phoenix** was a compiler and
program-analysis framework out of Microsoft Research whose last SDK was the
June 2008 CTP; what outlived it was some of the static analysis in Visual
Studio 2010, and its Wikipedia article was deleted.

Then the question the other way round: what would a rename buy. **Every
myth-adjacent alternative collides nearer than the incumbents do.** Pyre is
Meta's Python type checker and Cinder is Instagram's CPython fork — both in
this field. **Bennu**, the Egyptian bird the Greek phoenix descends from and so
the clever version of the move, is already a JavaScript parser combinator
library and a game programming language. That is trading a distant collision
for a near one.

*Brooker* was the only candidate that survived the check — nothing above two
stars holds it, and it means precisely what the name section argues, since the
Compiler Compiler at Manchester had a notation for meaning and not only for
syntax. It loses anyway: a surname says nothing to a reader who does not know
the history, which is most readers, and it yields no better binary than `phx`.

> The word is contested everywhere except in the field that could confuse it
> for something else.

What is actually contested is not *Phoenix* but **`phx`**, which is how Elixir
spells its mix tasks. Homebrew has neither name, which is where it would
matter; npm, crates.io and PyPI each have a dead `phx`.

Three paragraphs of this are in the README now, under the section that was
already arguing about the word — including the precedent, which is the same
word: Mozilla shipped a browser called Phoenix in September 2002, renamed it
Firebird in April 2003 when Phoenix Technologies objected, and renamed it
Firefox in February 2004 when the Firebird database project objected in turn.
No star counts and no formula counts went in with it. A number that moves on
its own does not belong in a record nothing re-runs.

### The closeout said the tree was clean, and it was not

The day was closed out once already, and the standup's table said *clean,
nothing uncommitted* at `eb4e650`. Two records were sitting modified:
`COMPLETED.md`'s defect row and `postmortem.md` § 14 — **the very entries the
same standup listed as the day's durable half**. They had been written and not
committed, and the status table was filled in from what the closeout had done
rather than from what `git status` said.

That is the day's own carry-forward wearing different clothes. An expectation
produced by the thing it describes is worth nothing, and it does not stop being
worth nothing when the thing doing the describing is a closeout rather than a
test. They are committed now, as `0d27886`.

### What the next language would have to fail at

More descriptions do not add mechanisms; they produce the evidence that earns
one. The roadmap already says so in both open entries — *one is a workaround;
two is a mechanism* for [1.7](ROADMAP.md#17-a-repetition-that-counts), and a
customer *a person would notice* for
[2.5](ROADMAP.md#25-circular-attributes--from-jastadd). So the question is not
which language would be pleasant to write but which one would fail at
something.

Three candidates were considered and two rejected. **BASIC teaches nothing**:
its one distinctive shape is unstructured control flow, which `pascal.phx`
already parses and `pascal-c.phx` already emits as C `goto`, and there is no
canonical dialect to be right against — no arbiter, no row in the table.
**Lua would most likely produce a negative result at full price**: dynamic
values, hash tables and coercion are what awk already demanded, and its one new
thing, closures, is a set synthesised up the scope tree, which is what `%pass`
does. **Java is the right idea at the wrong size** — inherited-member lookup is
where reference attributes pay, and it is the only thing here that would
seriously retest 2.1's verdict, but the subset would be arbitrary and the
runtime enormous.

What survived is two shapes. An **assembler for an ISA with span-dependent
instructions**, which is 2.5's cheapest possible customer and is written up in
that entry. And **lex and yacc as described languages**, where a subset
construction and a FIRST/FOLLOW closure are fixpoints by definition, `flex` and
`bison` are the arbiters, and the tool whose name this one argues about becomes
a description in it. The second has a question in front of it: a yacc file
embeds arbitrary C in braces, so reading one means scanning nested braces,
strings and comments, and whether the lexical half can express that is an
experiment rather than a guess.
### A Z80 assembler, and the half of it that was supposed to be boring

The customer 2.5 has been waiting for, started the same evening it was named.
`z80asm` went on the machine and the first thing built was **the comparison**,
not the description: four programs, assembled by the oracle, and no expectation
typed anywhere. That is the day's carry-forward applied before there was
anything to be wrong about — every byte the suite checks came out of `z80asm`,
so there is no literal for a later reading to have pasted.

The subset is immediate loads, `inc`, `dec`, the three immediate arithmetic
instructions, absolute jumps and calls, `ret`, `nop`, `halt`, and labels. 190
lines. **`jr` is not in it on purpose**, and that is the whole design: every
instruction here has one encoding and one length, so `layout` threading a `pc`
and handing a label table back down — `solvm`'s two passes, unchanged — is
enough.

**All four programs agreed with `z80asm` on the first run.** That is the
control doing its job rather than luck: if a subset with no choice of encoding
had disagreed, the fault would have been in this description and the `jr`
experiment would have been run on a broken instrument. It agreed, so what
happens when `jr` is added is about the notation and nothing else.

*One thing the notation made pleasant.* A register is written in the grammar as
its **encoding** — `reg = "b" -> "0" | "c" -> "1"` and so on — because `ld r,
n` is `0x06 + 8r`, `inc r` is `0x04 + 8r` and `dec r` is `0x05 + 8r`. Three
clauses would otherwise each carry a copy of the same seven-entry table. It is
`solveig.phx`'s `relation = "<=" -> "lessOrEqual"` in a language whose
vocabulary happens to be numeric.

*And one small mystery closed.* An empty `a.bin` had appeared in the repository
root and nothing in the Makefile or the suite writes that name. `z80asm` writes
it when `-o` is left off, the way `cc` writes `a.out`. The oracle runner passes
`-o` into a temporary directory and says why in a comment.

### Five checks, and the three records that went stale at once

199 to 204, and the counts caught it before the commit existed — README.md and
CHANGELOG.md both still said 199, which is the check written this morning
working exactly as its own postmortem entry described: a wrong number surviving
for the gap between two commands rather than for days.

The third was `COMPLETED.md`'s languages table, and it went stale in two ways a
number does not usually go stale: a new row was needed, and the sentence under
it said **seven directories, six rows**. Both fixed — but the more useful part
is that `tests/counts.sh` iterated `pascal solveig awk solvm calc phx`, a list
with no z80 in it, so the new row's two numbers would have been unchecked from
the moment they were written.

That is [postmortem 14](postmortem.md#14-the-counts-check-scored-the-same-day-it-was-built)
arriving four hours after it was written up. Its finding was that a check
assembled from the cases a sweep found inherits the sweep's blind spot, and the
fix it named was to derive the check's inputs from the question instead. The
question is *which languages have a row*, so `z80` is in the loop now and the
row is held against the tree like the other six.
### `br`, and the two bytes that are the entry

The step the standup called three. `jr` went into the grammar as an ordinary
instruction — two bytes, a signed displacement from the byte after it — and
that on its own changes nothing, because a `jr` the programmer wrote has a
fixed size whether it reaches or not. What creates the problem is **`br`**: a
pseudo-instruction that assembles to `jr` when the target is in reach and `jp`
when it is not, so its size depends on a distance that depends on sizes.

*What one walk can actually do.* More than expected, and the shape of what it
cannot do is sharper for it. `layout` threads `seen`, the labels **already
met**, so a backward `br` is decided exactly. A forward one is not, and
assuming short and being wrong emits a jump to somewhere else, so it is assumed
long. Correct, and not minimal.

**The interesting witness is `chain.z80`**, because it rules out the cheap
answer. One `nop`, a forward `br`, 123 more `nop`s, a backward `br`, and
`halt`. With the forward `br` taking three bytes the backward one sits at 127
and its displacement is -129, one out of range, so it takes three too: 131
bytes. With the forward one taking two, the backward one sits at 126, the
displacement is exactly -128, and both fit: 129.

So a second walk is not the fix. The first shrink is what makes the second
possible and the second is what makes the first worth having — recompute until
nothing moves, which is the fixpoint ROADMAP 2.5 has been describing since it
opened, now with a program that a person can count the waste in.

> The notation can **check** a relative jump and cannot **choose** one. The
> check needs every address, which the second walk has; the choice needs a size
> the first walk is still deciding.

*And the tool asked for a third pass.* A rule cannot both compute `disp` and
complain about it — *a check runs before the attributes it guards* — and `phx`
refuses that with the fix in the message: write the expression out here, or
compute it in an earlier pass. Writing it out meant one subtraction copied into
six places, so `reach` is a pass of its own between `layout` and `code`, whose
whole job is how far each jump goes.

### A thread declared in the wrong place is not a thread, and nothing says so

`br` picked the long form for a **backward** target, which is the one case the
walk knows the answer to. The label table was arriving empty at every node.

The cause is position. `thread seen = empty` had been written in the middle of
the pass, under the rule that assigns it, and clauses are classified as they
are read — `pass.c` asks `is_thread` at that moment. A rule above the
declaration gets an ordinary synthesised attribute; a rule below it gets the
thread. **Two attributes, one name, no diagnostic.** Moving one line fixed it,
and the same file with the line in the other place is a different program.

Isolated, because a bug found through 326 lines of Z80 is not yet a bug:

    %pass late                     %pass early
      Num  : seen = $seen + 1 .      thread seen = 0
      thread seen = 0                Num  : seen = $seen + 1 .
      Prog : total = $seen .         Prog : total = $seen .

Three digits in, **0** on the left and **3** on the right.

It is written into [ROADMAP 5](ROADMAP.md#5-known-warts) and **not** pinned by
a test, on purpose. A test asserting 0 would encode the defect as intended
behaviour, which is precisely what `spaced-regex.awk` did this morning and what
took four hours to notice. The shadowed *thread* is already an error in this
tool; this belongs in the same family, and the fix is a sweep at the end of the
pass rather than another expectation.

### And the count read off a red run was already wrong

A small one, worth a line because it wasted a cycle. `make test` printed
`206 passed, 1 failed` — the failure being `counts.sh`, which had noticed the
z80 row's numbers move — so the records were updated to say 206. Fixing the
count turned that failing check into a passing one and the total became 207.

**The number of checks a red run reports is not the number a green one will.**
The check that holds the records to the total is the thing that caught it, one
command later, which is the third time today it has paid for itself.
### The wart, fixed in the other file

The sweep the standup asked for, and it went somewhere else than the standup
said. The prediction was *the end of `read_one_pass` in `pass.c`*, which is
where the classification happens and is the obvious place. It is wrong for one
reason: **a pass is only whole once every `%import` has been read.** A rule in
one module and the `thread` in another is the same defect, and a check running
at the end of each file would not see it. So it is in `check.c`, next to the
shadowed thread it is a family with, where the grammar is assembled.

A `C_SYNTH` clause whose name the pass declares as a thread can only have been
read before the declaration — anything after it was classified `C_THREAD` on
the way in — so the test is one comparison and needs no new bookkeeping. The
`otherwise` clauses needed a second loop, because `check_clause_order` walks
the rules and a default is not one.

    error: 'seen' is declared a thread further down this pass, so this clause
           is an ordinary attribute and not an update -- the thread reaches
           every node with the value it started at
    phx: move `thread seen = ...` above the rules that update it

Pinned now, which it deliberately was not four hours ago:
`tests/grammars/thread-declared-late.phx`. The difference is the direction of
the assertion. This morning the only test possible would have asserted **0**,
the wrong answer, which is what `spaced-regex.awk` did and what took four hours
to notice. A `refuses` asserts the complaint, and a complaint cannot be
satisfied by the defect coming back.

### What actually found it, which was not a test

Worth its own paragraph because it is a kind of finder this repository has not
recorded before, and it is the cheapest one in it.

The z80 description has two backends — the bytes and a listing — and the
listing exists only because `z80asm` cannot be handed a `br`. Neither is a
test. What found the defect is that **one of them says out loud what the other
encodes**: `jp top` where `jr top` was expected, in a five-line program. The
bytes were a correct jump. They would have stayed correct forever, three bytes
at a time, and the oracle would have agreed with them every run — because the
oracle is handed the listing, and the listing was wrong in exactly the same
way.

> A second backend is not redundancy. It is the same tree said twice, and the
> two ways of saying it fail differently.

`calc/` has been making that argument since its awk backend shipped, about
arithmetic. This is the same argument arriving from a direction nobody aimed
at, which is the better kind of confirmation.

*And the tool grew by 64 lines*, so `COMPLETED.md`, `lineage.md` and
`postmortem.md` all wanted the new number and `counts.sh` said so before the
commit existed. Third time today.
### The walk written out twice, which is the mechanism with the word missing

2.5 has had a customer since the afternoon and the obvious next move was to
build the circular attribute. What was cheaper, and turned out to settle more,
was to **unroll one round by hand**: `relax` is `layout` written a second time,
with `layout`'s table in hand, deciding forward `br`s against an estimate.

*Two things it proved that an argument would not have.*

**The direction matters, and it is the reason it terminates.** Every address in
`layout`'s table came from a walk in which nothing was shorter than it will
finally be, so a distance measured against it can only over-state. A `br` that
fits against an over-estimate still fits when everything settles — shrink only,
never grow back. That is not a claim in a comment now: `code` refuses a `br`
that took the short form and no longer reaches, so if the reasoning is wrong
the suite says so rather than a program jumping somewhere else.

**And one round is enough more often than expected.** `chain.z80` went 131 to
**129**, its minimum, and `short-forward.z80` 5 to 4. Both left `divergent/`
and are ordinary oracle fixtures now. The entry needed a witness one round
deeper, so it got one.

`two-rounds.z80` is two forward `br`s where the second one shrinking in walk
two is what brings the first into range in walk **three**. 131, then 130, and
129 is reachable. Nobody makes the third walk. Three would do for that file and
four for a longer one, which is the point: *no fixed number is right, and the
stopping rule is until nothing moves*.

> A workaround that is the mechanism run once by hand is worth more than a
> mechanism built to a specification nothing has run. The specification is now
> the diff.

*What the prototype settled about the mechanism.* The step is one pass, exactly
as written. The bottom is what `layout` already produces. The test is whether
any size changed. The guard is a bound with a diagnosis naming what was still
moving. **What is left is only where the repetition is written** — on the pass
or on the driver — and the driver reads better, because a driver is already the
claim about what runs in what order, and a pass repeated with a termination
test the tool owns is not [3.1](ROADMAP.md#31-an-interpreter-that-can-loop)'s
interpreter that loops.

*Two things the tool refused on the way, both correctly.* Two `Program` rules
in one pass — *clauses for one pattern go together in a single rule* — and a
warning that `layout` and `relax` both defined `short`, with the later one
winning. The second was a real hazard rather than pedantry: the first walk's
guess and the second walk's decision are different values, and only one of them
should reach the backends. `layout`'s is `first` now.

## 2026-09-21: the first C construct, and what starting it cost

Sixteen days since the last entry, and one commit in between that this journal
did not see: on 2026-09-06 another session wrote [ROADMAP 6](ROADMAP.md#6-a-c-compiler),
a C compiler as an arc with a first step and three predictions, and closed
without a changelog line or a paragraph here. This entry is where the arc
starts moving.

**The step is the smallest one the entry allows.** `int main(){return 42;}`:
a grammar of five rules, a tree of five node types, one emit pass, one driver.
`languages/c/c.phx` holds the language and `c-arm64.phx` imports it, so the
split is the one `languages/README.md` prescribes and a second target would
touch nothing above the emit pass. Four programs sit in `tests/oracle/` and
[`run.sh`](../languages/c/tests/oracle/run.sh) compiles each through `cc` and
through Phoenix's assembly through `cc`, and compares what they exit with.
Four agree. Two checks in the suite, 213 in all.

*Four decisions, each small, each written down because the next construct
will lean on it.*

**The lexical half is written, not imported.** `lib/lexical.phx` reads `#` as
a line comment, which C does not, and every rule the module carries becomes a
token kind whether the subset wants it or not. C has hex and octal constants,
suffixes, character literals and strings with escapes, and each will arrive
with the construct that needs it. The module's own README says to import only
what a language uses, and this is the first language where the answer was
*none of it*.

**Falling off the end returns 0.** A `mov x0, #0` sits between the body and the
epilogue's label, on the path that reaches the closing brace without a
`return`. C11 5.1.2.2.3 requires that of `main` and says nothing about any
other function, of which returning 0 is one legal outcome. `fall-off.c` is the
oracle program for it, and `cc` agrees.

**A constant is `ldr x0, =n`.** The assembler's pseudo-instruction takes any
value: a `mov` when it fits, a literal pool when it does not, and the
description does not have to know which. `wide.c` returns 1000000 and reaches
the shell as 64, on both sides. The alternative, `mov` and `movk` computed in
the emit pass, would have been Phoenix arithmetic modelling the target's,
which `docs/semantics.md` says to write out when it is needed and not before.

**The value is 64 bits wide in a register C calls a 32-bit `int`.** That is
chibicc's first shape too. It is left to the oracle: an operation whose answer
differs between the widths is a program on which `cc` and this description
disagree, and that program will be found by the construct that makes it
possible, not by guessing now.

*One slip the tool caught.* `Block(body: $1)` where the block is
`"{" { statement } "}"`: `$1` is the opening brace, and the repetition is
`$2`. `phx` refused the description at read time with *`.out` reads an
attribute, and this is text*, at the clause that reads `$body.out`. That is
the miscounted factor [reference.md](reference.md#lists) already warns about
under `...`, caught one rule earlier by a different check, and the lesson is
the same: a literal counts.

*What the oracle can and cannot see yet.* An exit status is eight bits, so
two programs that return values congruent modulo 256 are the same program to
it. That is the whole channel until a function can be called and `printf`
declared, which is several constructs away, and it is enough for constants
and arithmetic: a wrong answer is overwhelmingly a wrong low byte too. When it
is not enough the entry's own rule holds: no hand-written expectation, so the
answer is a `printf` and not a number typed into the suite.

*The predictions stand untested.* Nothing here asked the tool for anything, so
the first prediction, reaching `struct` with no change to it, has had no
chance to fail. The third, that the calling convention costs the most, is
several constructs away. What can be said is that the frame is already the
shape the convention wants: `x29` and `x30` saved, `sp` restored from `x29`,
so a call will find a function it can call.

*Later the same day: the second construct.* `+ - * /` and parentheses, and
the stack machine gets its push and pop. Two levels of C's fifteen, written
as `lib/expression.phx` writes them and not imported from it, because the
module's table is calc's: `and`, `or`, `not` and `<>` are in it and C has none
of them. Six more programs, ten in all, and `cc` agrees with every one.

**The tool refused the obvious layout, correctly.** Four rules, one per
operator, under a general `Binary` rule computing the shared push-and-pop as
an attribute: *`Binary(op: ...)` can never match, `Binary` above it already
takes everything it is for*. Clauses for one pattern go together, and first
match wins, both of which the reference says. What replaced it is one rule
and a four-row table from operator to instruction, which is shorter and puts
the whole encoding in one place, the way `z80.phx` keeps a register's code in
the grammar. The refusal was a better design review than the one the file got
before it was run.

**Sixteen bytes a push.** `sp` on this machine must be sixteen-aligned at
every instruction that uses it, so an eight-byte value takes a sixteen-byte
slot. chibicc on x86 pushes eight; on arm64 there is no cheaper honest
answer than this until the pass keeps a depth and pairs its pushes, and no
construct has asked for that.

**What the oracle saw.** Two groupings the fold decides, `100 - 50 - 25` and
`64 / 4 / 2`, where the other associativity gives 75 and 32; a quotient
`(0 - 7) / 2` that must be -3 and not -4, made with subtraction because there
is no unary minus yet; and a nest of parentheses whose pushes have to be
popped in the right order. Overflow is not in the oracle. Wrapping at 32 bits
is undefined in C, so a program that wraps is one on which `cc`'s answer is
an accident rather than a standard, and the 64-bit register stays an open
question the oracle cannot yet ask.

*And the third: unary minus and comparison.* Three more levels, eight in the
tree now, sixteen programs, and `cc` agrees with every one. `Negate` is one
instruction. `Compare` is the same push and pop as `Binary`, then `cmp` and
`cset` with the **signed** condition, which `signed-compare.c` holds: `-1 < 1`
is 1, and the unsigned condition would say 0.

**The oracle refused a valid program, and the fix names the refusal.** A
comparison chains in C: `3 > 2 > 1` is `(3 > 2) > 1`, which is 0, and C11
6.5.8 says so. This `cc` makes it an error, and `-w` does not reach it,
because the diagnostic is one clang promotes to an error on its own. The
program is the witness that the grammar groups to the left, so the oracle now
passes `-Wno-error=parentheses` and says why in the line above it. That is the
first place `cc` and C differ on a program in this directory, and the
principle is that the oracle is C, and `cc` is how C is asked.

**The width question was asked and not yet answered.** A comparison is where
64 and 32 bits could first disagree in a defined way, and they do not: the
operands are constants in `int`'s range, and a comparison of two values that
fit is the same at either width. What would differ is a value that got there
by overflowing, and overflow is undefined. So the register stays 64 bits wide
for one more construct, and the entry that might change that is `char`, whose
conversions are defined.

*And the fourth: a local `int`.* Declarations with and without an
initialiser, assignment as an expression, expression statements, and a
`locals` pass, the first in this language that can say no. Seven more
programs agree with `cc`, twenty-three in all, and three are refused with a
position. Nothing in the tool was touched, which is the first prediction still
standing.

**The pass is the reference's own example, and it worked first time.** A
thread of declarations set afresh at each function by a `down` clause, saved
into an ordinary `down` attribute at each block and restored by the block's
leaving clause, and a slot counter that is reset per function and never
restored, because a slot is taken whether or not its name is still in sight.
Every line of that is in reference.md under *Threads*, written for Pascal, and
C wanted it unchanged. `Function : frame = $slots` on leaving reads the count
the body left behind, before the next function's `down` resets it.

**Two nodes for a declaration, not one with an optional field.** `int x;` is
`Local` and `int x = e;` is `LocalInit`, and the emit pass says the second is
the first followed by an assignment. A node whose field is sometimes there
is a node every pass has to ask about, and the notation has no way to ask.

**Assignment is an expression.** `a = b = 21` sets both, and the value stays
in `x0` after the store, which is all it costs. The left side is a name and
nothing else, because there is nothing else it could be yet; `*p = 1` and
`a[i] = 1` arrive with `*` and `[]` and will make the left side a place
rather than a name, which is the construct that changes this rule.

**What the oracle saw.** Five locals in one frame, where a wrong slot width
makes two of them share; an assignment whose right side pushes and pops
between the store's address being decided and the load, which is where a
frame offset computed from `sp` instead of `x29` would have gone wrong; and
an expression statement whose value has to be thrown away and not stored
anywhere.

*And the fifth: `if`, `while`, `for`, and blocks as statements.* Eleven more
programs, thirty-four in all, and one more refusal. The emit pass invents its
first labels, from a thread counted on leaving, so the number a node takes is
one nothing before it in the walk took, its own children included; nested
loops are the witness. A `for` carries its three clauses as lists of at most
one, because an option is a list that is empty when it did not match, and the
emit pass joins each the way it joins a block. The one place that is not
enough is the missing condition, which must emit no test rather than a test
of nothing, and a two-row table on the list's size says so.

**The dangling else cost nothing.** The `else` alternative is tried first,
so an inner `if` gets the chance to take an `else` before the outer one does,
which is C11 6.8.4.1's rule. Ordered choice did that; nobody wrote it.

**The oracle caught a wrong refusal, and it was a wrong question.** The
first version refused `int x = 1; { int x = 2; }` as declared twice. C11
6.2.1 lets an inner block shadow an outer name; what it forbids is two
declarations in *one* scope. The pass had one table, of every name in sight,
and was asking it both questions. It has two threads now: `env`, which a read
asks, and `scope`, which only a declaration asks, and the second is reset at
every block. The reference's example saves and restores one thread; this
saves and restores two, with the same three clauses each.

> A wrong refusal is found the same way a wrong translation is: by a program
> the oracle accepts. `block-scope.c` was written to test shadowing's
> *offsets*, and it found the check instead.

**What is not here, and why.** `&&`, `||`, `!` and `%` are C, and chibicc
has them early, but ROADMAP 6.1's list does not name them and this arc walks
that list. They are an afternoon each and none of them asks the tool for
anything; the next construct, a function with parameters and a call, is the
one the entry predicts will cost the most, and it is next.

*And the sixth: functions with parameters, and calls.* The construct the
entry predicted would cost the most, and it did: three rounds against the
tool before the oracle ran, where every construct before it took one or none.
Eight more programs, forty-two in all, and seven more refusals, eleven.
[Postmortem 16](postmortem.md#16-the-calling-convention-cost-the-most-and-not-for-the-reason-given)
scores the prediction; this is what happened.

**The convention itself was the cheap part.** A parameter is a node, so
that it can take a slot the way a local does, and parameter k is slot k, so
its register is k - 1 and the prologue stores it there. An argument is a
node, so that it can know its index from a thread the call resets and its
count from an attribute the call hands down; every argument is pushed as it
is evaluated, and the registers are loaded from the stack afterwards, so an
argument that is itself a call finds the ones before it safe. Sixteen lines,
and `eight-params.c` weights each register so that a swap shows.

**C refused the forward call, and the awk answer was the wrong one.** The
first version gathered every function into a table on the way up and handed
it down, which is what `languages/awk/` does because awk lets a call come
above its function. `cc` refused `forward.c`: C99 6.5.2.2 wants a declaration
above every call. So the declared functions are a thread, a definition binds
itself on the way *in* so that its body can recurse, and a prototype is in
the grammar because that is what C offers instead. The gather pass stayed for
the two questions no order can answer, a function defined twice and one
declared with two arities, both asked at the top with the expressions written
out, because a check cannot read what its own rule computes.

**A rule with no action answers the one thing it matched.** `params` with
one parameter arrived as the `Param` itself and with two as a node called
`params`, and the emit pass wanted a list either way. The reference says so
under *No action at all*, and the collapse is the feature that keeps
`expression` from wrapping a number in six nodes; a list rule has to say
`-> $1` to keep its list. Both list rules now do, with a comment, because
this will catch the next person too.

*Two refusals from the tool, both mine.* Two `Function` rules in one pass,
the same slip as 2026-09-05's, and a check reading its own rule's
attribute, which `z80.phx` had already answered by writing the expression
out. Neither cost more than the message took to read.

*The day, read back.* Six constructs, six commits, forty-two programs, and
the oracle ran on every one before the records were written. Counting where
each round's cost landed: the tool refused five things at read time, all of
them slips the reference already names, and each cost the time it took to
read the message. The oracle refused three, and every one of those was C
rather than the machine: a chained comparison this `cc` rejects by default,
shadowing across blocks that one table could not tell from redeclaring, and
a call above its function that C99 forbids without a prototype. The machine
refused nothing. That is the shape postmortem 16 scores in the prediction
about the calling convention, and it held for the whole day: **the expensive
half of a C compiler in this notation is the rules of C, and the oracle is
where they are met.** Nothing in `phoenix/` was touched.


## 2026-09-22: `&` and `*`, and a place that turned out to be a rule

The seventh construct, and the one the roadmap's list said would change the
`assignment` rule. It did, on one line, and the line it changed was not the
interesting part of the day.

**A place is a rule, not a pass.** C11 6.5.3.2 wants an lvalue after `&` and
6.5.16 wants one before `=`, and both are the same question: *where can a
value be put?* The subset's answer is two alternatives:

```ebnf
place = "*" u:unary -> Deref(value: $u)
      | n:name      -> Variable(name: $n) .
```

Both `assignment` and unary `&` go through it, so `&1` and `1 = 2` are
refused by the parser, with a position, and nothing downstream had to ask what
kind of node it was handed. The shape that was nearly written instead was C's
own, `assignment = unary "=" assignment` with a pass rejecting the operands
that are not lvalues; that needs a pass that can ask what a node **is**, which
is a question about the tree rather than about the program, and answering it
would have meant an attribute on every node kind saying whether it was a
place. The grammar already distinguishes them for free, because it is the
thing that built them.

The rule is narrower than C by one alternative, and the narrowing is written
down here because nothing else records it: C lets a place be parenthesised, so
`(x) = 4` and `&(x)` are programs `cc` compiles and this subset refuses. They
are refused with a position rather than mis-compiled, which is the line this
arc holds, and the day something wants them the rule gains an alternative.

**A place is a second attribute, not a second node.** `x` on the right of an
`=` is a load and `x` on the left is an address, and both are the same
`Variable` in the tree. The emit pass gives that node two attributes: `out`,
the value, and `addr`, where the value lives. The parent asks for the one it
meant. `Deref` answers both too, and its `addr` is its child's
`out`, which is the whole of it: **`&*p` emits exactly what `p` emits**, and
the identity C11 6.5.3.2 states falls out of the shape of the tree rather than
being written down anywhere. Nothing else in the tree has an `addr`, and the
`place` rule is what guarantees nothing else is ever asked for one.

**One table, not two.** A name now means two things: which slot it lives in,
and how many stars stood in front of it. The second nearly arrived as a
second thread beside `env`. It would have needed the same `down` at a
function and the same save-and-restore at a block, and two copies of a scope
rule are two chances to disagree about what a scope is. So `env` binds a
**pair**, the name is looked up once and its halves are read off it with
`at`, and the `locals` pass's title gained a third clause: *which local is
which, where does it live, and what is it*. That is one question about a name
rather than two about the same name. The declarators are counted rather than
kept: a type in this subset is `int` and a number of stars, and a number is
what the node already carried.

**A third pass, and the one thing it is for.** Every value here is eight bytes,
so almost nothing comes out wrong from a pointer being taken for an `int`:
the same register holds both and the same `ldr` fetches both. C says otherwise
in one place, 6.5.6: `p + 1` is the **next `int`** and not the next byte.
Nothing in this subset has a size yet, so the `types` pass counts stars and
refuses that by name, along with `*x` on an `int`, which 6.5.3.2 forbids and
which would have compiled into a load from whatever the int happened to be.
What it deliberately does not do is check that what is assigned, or passed,
has the type it is given. 6.5.16.1 has a table for that and `cc` warns from
it, but the rule this pass was written to is narrower and load-bearing:
**refuse what would otherwise mis-compile, and nothing else.** A check that
only reproduces somebody else's diagnostic is a second opinion rather than a
compiler.

**The program that would show the eight-byte `int`, and why the oracle cannot
see it.** That rule is only honest if nothing *does* mis-compile from a type
being wrong, so the program that would break it was written:
`int q = 0; q = &x; int *p = q; return *p;`. Phoenix keeps sixty-four bits and
it works; `cc` puts the pointer in thirty-two and it does not. Except that
`cc` will not compile it at all. This one makes `-Wint-conversion` an error
by default and `-w` does not move it, the way `-w` did not move the chained
comparison on 09-21. The difference is that the chained comparison was C11 as
written and worth downgrading by name, and this is a constraint violation that
is worth leaving refused. So the only programs on which the width could show
are ones the oracle will not build, and the 09-21 note stands unchanged:
`char` is still where the width gets decided.

*Sixteen programs, seven refusals, and neither the oracle nor the tool refused
anything.* Fifty-eight against `cc` now, eighteen refused. All sixteen agreed
on the first run and `phx` read the description without complaint, which is
the first construct of which both are true. Yesterday's lesson was that the
expensive half of a C compiler here is C rather than the machine, and that the
oracle is where C is met; today C was met in 6.5.3.2 and 6.5.6 before anything
was written, and the oracle confirmed instead of correcting. That is either
the lesson working or the construct being small, and the next one will say
which: **arrays and `sizeof` are where the size this pass is missing has to
arrive**, and a size is a change to what a type *is* here rather than another
row in a table.

*Prediction one is seven constructs in and still untouched.* Nothing today
asked the tool for anything: a rule, an attribute, a pair in a table and a
pass, all of which the notation already had. Prediction two, that `typedef`
is the first thing to want a change, has still not been asked.

*The day read back, and one expectation moved.* The 09-21 entry left the
eight-byte `int` to the oracle and said `char` was where it would be decided.
Today found the first program on which the two compilers really do disagree
about it, and then found that `cc` refuses to compile that program, which is
why the note survived the morning unchanged. What did not survive was the
`char` part, and what moved it cost one command: asking `cc` about the
**next** construct rather than this one. `sizeof(int)` is 4 and
`sizeof(int *)` is 8, both are programs `cc` compiles without a word, and the
description as it stands would answer 8 to the first. So the width is settled
at `sizeof`, two constructs earlier than the last entry expected, by a
program the oracle cannot help seeing;
[ROADMAP 6.1](ROADMAP.md#61-step-one--a-subset-that-runs-and-cc-as-its-oracle)
states the choice and does not take it. The general form of that is the
cheaper lesson: **the construct after the one being written is a free place
to look for what will be expensive**, because its oracle programs can be run
against `cc` before a line of it is described.

## 2026-09-22: the width, decided after the day was closed

The closeout wrote the `sizeof` question onto the roadmap and left it there.
It was taken the same evening, because the argument turned out to be shorter
than expected and one leg of it turned out to be false.

**`sizeof(int)` is 4, and the value narrows to thirty-two bits.** Both answers
were available: the standard asks `int` to be at least sixteen bits, so a
sixty-four bit one is a conforming implementation and this subset would have
been a different implementation rather than a broken one. That is a real
defence and it is why this needed deciding instead of fixing.

*What settled it was not `sizeof`.* Looking for the argument turned up a
better thing: the subset **already** disagreed with `cc`, in the tree as
committed, in a program the second construct made possible on 09-21.

```c
int main() { int a = 2000000000; int b = a + a; return b / 1000000; }
```

218 against 160. Undefined behaviour on both sides, so neither compiler is
wrong, but the arc's rule is *where they differ, Phoenix is wrong until
somebody shows otherwise*, and the reason this one had never come up is that
nobody had written it. [postmortem 17](postmortem.md#17-left-to-the-oracle-is-not-a-decision-until-somebody-writes-the-program)
is about that rather than about the width.

**The machine made the choice cheap, which is the part worth writing down.**
On arm64 `w0` is not a second register, it is the low half of `x0`, and every
write to a `w` register zeroes the upper thirty-two bits. So `x0` always holds
the zero-extended `w0`, and:

| | |
| --- | --- |
| the stack machine | unchanged. `str x0, [sp, #-16]!` and `ldr x0, [sp], #16` are still lossless, because there is nothing above the low half to lose |
| the calling convention | unchanged. AAPCS64 passes a 32-bit `int` in `w0` to `w7`, which *are* `x0` to `x7`. The prologue's store becomes `str w0` and nothing else moves |
| the frame | unchanged. A scalar keeps its eight-byte slot, written with `str w0` and read with `ldr w0`, so `sub x0, x29, #8n` is still the address of it and the slot counter never hears about this |
| the operators | one letter, chosen by the node's type: `add w0, w0, w1` on ints, `add x0, x0, x1` on pointers. `sdiv w0` still truncates toward zero and `cmp w0` with `cset` still answers 0 or 1 |

So what looked like a rewrite of the emit pass is a second column on the table
it already has, and the `types` pass grows from *how many stars* to *how many
stars and how wide the base is*, which arrays were going to force anyway. One
instruction is genuinely new, `sxtw` where a 32-bit index meets a 64-bit
pointer, and it arrives with `a[i]`. Nothing here asks the tool for anything,
so prediction one is not threatened by the decision either.

*One argument was made, tested, and dropped.* The expectation was that a
sixty-four bit `int` would break `printf`, which ROADMAP 6.1 reaches through
the system libc with a declaration rather than an include, and which is how
the oracle gets a channel wider than eight bits at `char` and string literals.
It does not. Apple's arm64 variadic convention gives every argument an
eight-byte stack slot and `%d` reads the low four of it, little-endian, so
passing sixty-four bit values to `printf("%d %d %d\n", ...)` prints them
correctly. The argument was written out before it was run and would have been
the strongest one in this entry. It is recorded here because a reason that
sounds decisive and is false is worth more to a later reader than the three
that held.

## 2026-09-22: the width, built, and two tests made to fail on purpose

Decided in the evening and built in the same one, because the estimate in the
entry above turned out to be the whole of it.

**Nine clauses and a table with one row.** `lookup([[0, "w"]], t, "x")`: no
stars is an `int` and lives in a `w`, a star is a pointer and lives in an `x`.
The `types` pass did not change at all, because the star count it already
computed *is* the width once there is a table to read it through, and the
table is in `c-arm64.phx` where a register is allowed to be mentioned. What
moved: a constant, a load, a dereference, three stores, the arithmetic, the
negation and the comparison.

**Everything the estimate said would not change, did not.** The stack machine
still pushes and pops `x0`, the calling convention still loads `x0` to `x7`,
and the frame still gives a scalar eight bytes. All three for the same reason,
which is worth stating once as the fact it is: on this machine **a write to a
`w` register zeroes the upper half of its `x`**, so `x0` is always the
zero-extended `w0` and there is nothing above the low half to lose. Two places
in the pass now say so in a comment rather than leave a reader wondering why
they were not touched: the condition test, `cmp x0, #0`, which is right for an
`int` and a pointer both, and the argument load, which puts the right
thirty-two bits in `w{i}` by loading the whole of `x{i}`.

A store is `str w0` into an eight-byte slot, so the upper half of the slot
keeps whatever was there. Nothing reads it, and nothing may: the slot is one
`int` and its address is the low end of it. That stops being free when a
declaration takes more than one slot, which is arrays.

*The estimate is not scored in the [postmortem](postmortem.md), on purpose.*
It was made two hours earlier and three of its instructions had been
assembled by hand before it was written down. A prediction checked before it
is published is a plan, and scoring a plan as though it had been a guess would
make the file's other sixteen entries worth less.

**The three programs catch three different mistakes**, which is the part that
generalises. `overflow.c`, the witness recorded the day the decision was made,
catches an `int` that does not wrap: 218 against 160. It is undefined
behaviour, so `cc` is not right and this is not wrong, and what the test
actually asserts is that the two implementations agree about a width, which is
the thing the arc wants. The two added today are **defined**, and they catch
something `overflow.c` cannot: a narrowing that is half done.

```c
int main() { int x = 0; int *p = &x; *p = 0 - 5; return (*p < 0) * 10 + (*p + 15); }
```

`ldr w0` zero-extends, so a negative `int` sits in `x0` as `0x00000000FFFFFFFB`
and a comparison that asked `x0` rather than `w0` would call it positive. The
other does the same through the calling convention, where AAPCS64 leaves the
upper half of `x0` unspecified for a 32-bit argument and so nothing downstream
may read it.

Both were then **made to fail**, by forcing the comparison back to `x` and
running them: 20 against 10, and 30 against 10. A test written for a change
just made is the easiest kind to write so that it cannot fail, and the cost of
finding out was two minutes.

*Fifty-nine programs became sixty-one, and the suite is unchanged at 231
checks*, because the oracle is one check however many programs it runs.

## 2026-09-22: `sizeof`, which wanted nothing, and the one number it got wrong

The roadmap's next item is *arrays and `sizeof`*. They came apart on
inspection: `sizeof` is testable on its own and arrays are not testable
without it, so `sizeof` went first with the suite green, which is the rule
this arc was set up under.

**It wanted nothing.** Two alternatives in `unary`, two node types, two emit
clauses, and the `types` pass did not grow a line. The reason is worth having
written down, because it will stop being true: while `int` is the only base
type, **a star count already is a size**. No stars is four bytes and any star
is eight, so `lookup([[0, 4]], t, 8)` is the whole of `sizeof`, read from the
same table the register letter comes from and for its other column. When
`char` arrives that table gets a second row and a size stops being derivable,
and that is the day a type needs a node rather than a number.

**The type form goes before the expression form**, which ordered choice makes
a decision rather than a preference. `sizeof(x)` would otherwise be taken by
the expression form, whose primary is a parenthesised expression, and then
`sizeof(int)` would fail there because `int` is reserved and no expression
begins with it. Tried the other way round, both work.

**The operand is not evaluated**, C11 6.5.3.4, which is one absence in two
clauses: neither mentions `$value.out`. `sizeof(x = 2)` does not assign and
`sizeof bump(&x)` does not call, and both are oracle programs because an
absence is the kind of thing that is right by accident until somebody checks.
The earlier passes still walk the operand, so a name nothing declared and a
call with the wrong arity are refused inside a `sizeof` exactly as outside
one, which is also C.

**One number is wrong, and it is the first thing in this arc to be written
down as wrong rather than refused.** C makes `sizeof` worth a `size_t`, which
is eight bytes here; `size_t` is a **typedef**, and ROADMAP 6.1 stops the
subset before `typedef` on purpose, so there is no way to name the type this
answer ought to have. So `sizeof` is worth an `int`, and
`sizeof(sizeof(int))` is 8 under `cc` and 4 here.

Everything else agrees, because the answers themselves, 4 and 8, are `cc`'s.
The gap goes in `tests/divergent/`, which is the shape
`languages/awk/tests/divergent/` already established for the lexical seam, and
the suite asserts **both** numbers rather than the difference: closing it
fails the check with the old answers in it, which is what will happen when
`typedef` arrives and brings `size_t` with it. A refusal would have been
wrong here. `sizeof(sizeof(int))` is a legal program that this compiler
compiles and gets a different answer to, and calling that a refusal would hide
it behind a message.

*Eight oracle programs, sixty-nine in all, and all eight agreed on the first
run.* Two more refusals, twenty. Three more checks, 234.

## 2026-09-22: the place rule gains the alternative it was short

The narrowing written down in the first entry of the day, closed. C lets a
place be parenthesised and this rule did not, so `(x) = 4` and `&(x)` were
ordinary C and a syntax error here.

```ebnf
place = "*" u:unary     -> Deref(value: $u)
      | "(" p:place ")" -> $p
      | n:name          -> Variable(name: $n) .
```

One alternative, and its action answers the place inside the parentheses
rather than building anything, which is what parentheses are: they group and
they do not change what a thing is. It goes after the `*` and before the name
for the reason every ordered choice in this file does, which is that the
first token decides. Two oracle programs, seventy-one in all.

*The refusal it was keeping company with moved, and that is the part worth
recording.* `&1` was refused with *expected `*` or name*, and is now refused
with *expected `*`, `(` or name*. The suite asserted the old text, so widening
the rule turned a green check red with the message in it, which is exactly
what that check is for: the expectation is a statement about **what a place
is**, and the rule changed what a place is. It was updated rather than
loosened. A check written as *it was refused somehow* would have said nothing
here.
