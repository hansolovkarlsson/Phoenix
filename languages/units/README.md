# Pascal units — an experiment, and what it answered

*A subset of Turbo Pascal's unit system, described to find out whether name
resolution here ever needs a scope graph. It does not, and the interesting part
is **why not**.*

```sh
bin/phx languages/units/units.phx languages/units/programs/shadowing.pas
languages/units/tests/run.sh
```

| | |
| --- | --- |
| [`units.phx`](units.phx) | the language: `unit`, `interface`, `implementation`, `uses`, and names that refer to declarations |
| [`programs/`](programs/) | programs that agree with `fpc -Mtp` exactly, with what each prints beside it |
| [`tests/`](tests/) | what must be refused, each carrying the message `fpc` refuses it with |
| [`divergent/`](divergent/) | the two things this gets wrong, written down inside the files |

## The question

[ROADMAP 2.3](../../docs/ROADMAP.md) names three things that would make a scope
graph earn its place: **modules that import each other**, **scopes visible from
more than one place**, and **a name whose meaning depends on which path you
reached it by**. Pascal as described in [`../pascal/`](../pascal/) has none of
them; Solveig has one flat namespace and awk has two.

Turbo Pascal units have all three, and they are not invented for the occasion.
Every rule below was settled against `fpc -Mtp` before a line of grammar was
written:

| | |
| --- | --- |
| 1 | `uses a, b` and both export `x` — **b wins**. Later shadows earlier |
| 2 | A unit's or a program's own declarations shadow anything it uses |
| 3 | **Visibility does not compose.** `uses c`, where `c`'s interface uses `b`, does not give you `b`'s names |
| 4 | A cycle between two **implementation** `uses` clauses is legal |
| 5 | A cycle between two **interface** `uses` clauses is refused |

And one more that a reading of those five gets wrong, which is why it was
checked: inside a unit's initialisation section, **the unit's own interface
shadows what its implementation uses**.

## The answer: no graph, and rule 3 is the reason

All four scopes compose into one list, and the order falls out of the walk:

```
Init : down env = [...$implexp, ...$ifexp, ...$env] .
```

Own implementation declarations, then own interface declarations, then what
the thread accumulated — which is the `uses` clauses, later-used first.

**Rule 1 needed no list reversed**, and that matters because this notation has
no way to reverse one. Each used unit is a *node*, so walking a `uses` clause
**is** the fold: `uses a, b` visits `a` and then `b`, each putting its exports
on the front, so `b` is found first.

**Rule 4 costs nothing at all**, and this is the whole finding. Because
visibility does not compose, resolving a `uses` is **one lookup in a table that
the first pass built** — not a walk. There is no traversal for a cycle to be a
cycle in. Two units that use each other resolve exactly as two that do not.

So the roadmap's first criterion — *modules that import each other* — turns out
**not to be sufficient**. A cycle is only dangerous to a resolver that has to
follow it, and non-transitive visibility means nothing follows it.

## What the notation did ask for

**Two, and both were answered by things already built.**

`interface` and `implementation` had to become **nodes**. A `down` clause is
about a node and reaches all of it, so a `Unit` holding four lists could not
hand one environment to its interface's declarations and a larger one to its
implementation's. Splitting them is what the language meant anyway — the
notation pushed the tree into a truer shape.

And an implementation needs its **sibling** interface's exports, which no
clause can reach. What makes it reachable is that `exports` was worked out in
the pass before: a parent can read a child's attribute on the way *in* and hand
it to the other child. That is the same answer a forward reference gets, and it
is the only mechanism this description needed that a single walk does not have.

## What *is* graph-shaped here, and neither is resolution

Both are in [`divergent/`](divergent/), and both are honest about it.

**Rule 5 is reachability.** Detecting a circular interface `uses` is a question
about the *uses graph*, and this description answers it only two units deep —
does the unit I use use me back. `A -> B -> C -> A` is not caught, because
catching it needs the transitive closure, and closure needs iteration to a
fixpoint over **data**. A `%rewrite innermost` reaches a fixpoint over the shape
of a tree, not over a table.

It is also worth knowing *why* `fpc` refuses this at all: separate compilation.
Neither `.ppu` can be written without the other. It is a well-formedness rule
about files, not a rule about scopes, and in a single file it constrains
nothing.

**Initialisation order is a topological sort.** `fpc` runs a unit's
initialisation after the units it depends on; this runs them in the order they
are written. Every name still resolves identically — what differs is *when
things run*, which is a different question from *what a name means*.

## The verdict, and the sharper test it suggests

**2.3 is settled against, with evidence rather than scepticism.** The strongest
candidate short of ML functors or a class hierarchy resolves with an
association list, and the two things that wanted a graph are not name
resolution.

But the experiment also says which criterion to test next, and it is not the
one the entry leads with. Mutual imports are harmless. What would actually bite
is a language where **visibility composes** — where using a module gives you
what *it* used, so a name's meaning depends on the path you reached it by.
Rust's `pub use`, ML's `open` inside a signature, a class hierarchy where a
name resolves through a chain that several classes share. That is the shape to
look for, and Pascal units are not it.

## Why the units are in one file

Turbo Pascal puts each in its own, and reading a second file before there is a
tree to walk is [`%include`](../../docs/reference.md#include)'s question —
already answered, and answered the same way a cycle in rule 4 ends: a file is
read **once** however many ways it is reached. Re-proving that would say
nothing about resolution.

`tests/run.sh` splits each file back into the units it describes and hands them
to `fpc -Mtp`, so the arbiter sees real separate units and this description
sees the question it was written for.
