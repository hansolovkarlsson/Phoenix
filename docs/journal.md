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
existed. `examples/pascal.phx` is `tests/pascal/pascal.bnf` with `->` clauses
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

`examples/pascal.phx` now has a `symbols` pass and a `typecheck` pass, and
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
concrete argument for [reference attributes](ROADMAP.md#21-reference-attributes--from-jastadd),
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
