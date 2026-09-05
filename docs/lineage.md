# Lineage

*Where Phoenix sits among the tools it is related to. **Every mechanism in it
has prior art, and the combination is what is unusual** — this page is the
evidence for both halves of that sentence, arranged by how close each relative
sits.*

---

## The closest ancestors — metacompilers proper

**TREE-META** (SRI, mid-1960s, descended from Schorre's META II of 1964) is the
sharpest comparison and the one worth reading first. Its syntax rules build a
tree, and then **"unparse rules" pattern-match on tree shapes to emit code** —
which is structurally what a `%pass emit-c` is, `Binary(op: "+")` clauses and
all. The idea in its original form is there.

**CWIC** (Systems Development Corporation, ~1970 — Book, Schorre, Sheridan)
went further: its "generators" did pattern matching over trees with
backtracking.

The metacompiler family is where *compiler-compiler* meant more than a parser,
which is the argument [the README's name section](../README.md) makes from
Brooker and Morris. TREE-META is the concrete evidence for it.

## Attribute grammar systems — the `%pass` family

| | |
| --- | --- |
| **JastAdd** (Lund — Hedin, Ekman) | **Reference attribute grammars**: an attribute may *point at another node*, so a `Variable` holds a reference to its declaration. JastAddJ is a full Java compiler written this way. The system `%pass` most resembles — **and the one whose central feature Phoenix lacks.** |
| **Silver** (Minnesota — Van Wyk) | Attribute grammars plus **forwarding**, for language *extension*: you describe a construct by saying what it is shorthand for. `ableC` is an extensible C compiler. |
| **Eli** (Waite, Gray, Heuring, Levi, Sloane) | A complete compiler-construction system. Its specification language LIDO has **CHAIN** — precisely the threaded attribute Phoenix arrived at independently, which is good confirmation that `thread` is a real concept with a settled name. |
| **UUAG** (Utrecht, Haskell) | Used to build the Utrecht Haskell Compiler — evidence that attribute grammars scale to a real language. |
| **LISA** (Maribor — Mernik) | Generates compilers *and* interpreters from one description, with visualisation. |
| **Kiama** (Sloane, Scala) | A *library* rather than a tool: attribute grammars and strategic rewriting embedded in a host language. |
| **Ox** (Bischoff) | An attribute-grammar preprocessor bolted onto lex and yacc — the minimal version of the idea. |

## Transformation and rewriting

**Spoofax**, with **SDF3** and **Stratego** (Delft, the late Eelco Visser's
group), is the most complete modern realisation of this whole ambition and the
most instructive thing to compare against. Stratego's transformations are
written with explicit **strategies** — `topdown`, `bottomup`, `innermost` —
which is the vocabulary a `%rewrite` would need, already worked out. Their
**NaBL2** and **Statix** describe name binding and type checking declaratively
through *scope graphs*, a considerably more principled answer to symbol tables
than threading an environment along a walk.

Also **Rascal** (CWI, successor to ASF+SDF), **TXL** (Cordy — transformation by
example) and **Maude** (rewriting logic).

## Binary formats — the family this page had missed

**Kaitai Struct** (a `.ksy` description compiled to parsers in eleven host
languages) and **DFDL** (the OGC standard, from the data-format world) are the
literature for *describing a binary layout declaratively*. Kaitai's repetition
is the part that matters here: `repeat-expr` takes **a count computed from a
field already read**, and `repeat-until` takes a predicate.

That is the one thing Phoenix has written down as impossible.
[`languages/solvm/`](../languages/solvm/) emits `.sob` and cannot read it,
because a length-prefixed format needs a match to depend on a number the parse
has just produced, and `{ }` here means *until it stops matching*. `solvm
--dump` is the reading half, which is an external tool doing a job the notation
cannot ask for. See [ROADMAP 1.7](ROADMAP.md#17-a-repetition-that-counts).

**Construct** (Python) is the same idea as a library rather than a language, and
worth a look for how small the vocabulary can be: a handful of combinators
covers most real formats.

## "A compiler is a sequence of passes"

**Nanopass** (Dybvig and Keep, Indiana — Scheme and Racket) is this project's
opening complaint stated as a research programme: you define a *series* of small
intermediate languages, each a delta on the last, and the framework derives the
traversal boilerplate. If there is prior art for *a compiler is a sequence of
tree walks and the boilerplate should be free*, it is that.

## Error reporting — the literature for a limit this tool has

Phoenix's matcher is a PEG, and PEGs have a known and well-studied weakness
that this page had not named: **ordered choice throws away why an alternative
failed**, so the error surfaces at the outer position that gave up rather than
the inner one that got stuck. `print a +;` is reported at the `print`.

| | |
| --- | --- |
| **Ford** (2002) | the **farthest-failure** heuristic — track the rightmost position the parse ever reached and report *that*. It needs nothing from the grammar writer, which is its whole appeal |
| **Maidl, Mascarenhas, Medeiros, Ierusalimschy** | **labeled failures**: a PEG names its kinds of failure and each ordered choice says which it catches, so a rule can commit and explain rather than backtrack silently |
| **Medeiros and Fabio Mascarenhas** | error *recovery* in PEGs — recovery expressions that let a parse continue past a failure, which is what reporting more than one syntax error requires |

The three are a ladder: the first is a heuristic and costs nothing, the second
is a notation change, the third changes what a parse is. See
[ROADMAP 5](ROADMAP.md#5-known-warts).

## Parser generators only — the yacc family

lex, yacc and bison; **ANTLR** (Parr); JavaCC; Menhir; tree-sitter; Ragel.

**Langium** (TypeStack/Eclipse) is what a workbench looks like now and belongs
beside Xtext rather than beside yacc: one grammar, and the tool generates the
AST types *and* a Language Server — completion, go-to-definition, diagnostics,
formatting — for every editor that speaks LSP. It is the clearest statement of
the thing Phoenix does not do and has not wanted to: **the deliverable is an
editor experience, not a compiler.**

**Coco/R** (Mössenböck, ETH Zürich and later Linz) deserves its own line: EBNF
with attributes, generating recursive descent — but its actions are
host-language fragments, which is the yacc bargain again.

**Cocktail** (Grosch, GMD) is a fair answer to *what did a complete 1990s
version look like*: Rex, Lalr, Ast, Ag, and **Puma** for pattern-matching tree
transformation.

---

## Where Phoenix actually sits

**Not novel in its ideas.** Every mechanism above has a name and a literature.
What is distinctive is the combination:

- **8,698 lines of C11 against the C standard library and nothing else.** The
  point is not the language — Eli is a C-based system too — it is the footprint:
  Eli and Spoofax are *systems*, with toolchains and generators and editors.
  Phoenix is one binary and a `lib/` directory. That buys much less and costs
  almost nothing to have around.
- **Actions are not host-language splices.** This is the real separator from
  yacc, Coco/R and ANTLR, and it is what made *could the generated compiler be
  C instead of Solveig* an answerable question rather than a rewrite.
- **The meta-language owns its arithmetic** — [semantics.md](semantics.md).
  Most of these tools inherit their host's semantics implicitly, which is fine
  with one host and a latent divergence bug with two.

## What was worth stealing, scored

This section listed three candidates when the page was written and said *all
are on the roadmap*. None of them is on it now, and that is the interesting
part: **one was taken, and two were tested against a real language and lost.**
A page about influences is worth little if it only records the borrowing that
worked.

| | |
| --- | --- |
| **Stratego's strategies** → `%rewrite` | **Taken, unchanged.** `topdown`, `bottomup` and `innermost` are the words for the thing and there was no reason to invent others. What Phoenix added is nothing: the traversal puts a built node back where the matched one was, and that is all a `%rewrite` is. The customer was not term rewriting but an **optimisation** — an inlined block is a node that should not be there, and no clause *about* a node can say that ([2.2](COMPLETED.md#22-strategies--from-stratego)) |
| **JastAdd's reference attributes** | **Refused on evidence.** The entry was narrowed to one case — a reference pointing *forward* — and awk was the language that needed it. Two passes and twenty lines did it, because a leaving clause on the root runs after the whole subtree. Reference attributes would have bought one walk instead of two and cost demand-driven evaluation and cycle detection ([2.1](COMPLETED.md#21-reference-attributes--from-jastadd)) |
| **Statix's scope graphs** | **Refused on evidence.** `languages/units/` was written *specifically* to test it — Turbo Pascal units have all three properties the entry asked for — and resolution stayed a list. A cycle between two implementations costs nothing, because visibility does not compose, so there is no traversal for a cycle to be a cycle in ([2.3](COMPLETED.md#23-scope-graphs--from-statix)) |

> Two of three lost to *describe the language and see*. That is the method this
> page should be read as recommending, more than any particular borrowing.

## What is worth stealing next

Two, and both are on the [roadmap](ROADMAP.md) because a description already
here has run into them and the failure is written down.

**Kaitai's counted repetition** — [1.7](ROADMAP.md#17-a-repetition-that-counts).
`languages/solvm/` emits `.sob` and cannot read it. That is not a preference;
it is a repetition whose count is a value the parse has just produced, and the
notation has no way to say one.

**JastAdd's circular attributes** — [2.5](ROADMAP.md#25-circular-attributes--from-jastadd).
An attribute defined by a fixpoint rather than in one walk.
[`languages/units/`](../languages/units/) cannot refuse `A -> B -> C -> A` and
cannot order initialisation, and both are in its `divergent/` directory with a
test keeping them honest. Reachability and topological sort are the same
missing thing twice.

**And one that is not on the roadmap and should not be.** Silver's
**forwarding** — a construct says what it is shorthand for, and unanswered
attribute queries delegate to the tree it forwards to — addresses a cost this
project has now *measured*: nine of `calc-awk.phx`'s twenty-four clause lines
answer for nodes `lib/expression.phx` brought, and calc's own grammar declares
none of them ([postmortem 12](postmortem.md#12-about-fifteen-lines-and-what-a-second-backend-actually-cost)).
`otherwise` took the cheap half of that already. Forwarding is a large
mechanism and no description here is blocked, so it waits for a language that
is — which is the same bar reference attributes and scope graphs were held to,
and lost.
