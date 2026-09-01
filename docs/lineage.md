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

## "A compiler is a sequence of passes"

**Nanopass** (Dybvig and Keep, Indiana — Scheme and Racket) is this project's
opening complaint stated as a research programme: you define a *series* of small
intermediate languages, each a delta on the last, and the framework derives the
traversal boilerplate. If there is prior art for *a compiler is a sequence of
tree walks and the boilerplate should be free*, it is that.

## Parser generators only — the yacc family

lex, yacc and bison; **ANTLR** (Parr); JavaCC; Menhir; tree-sitter; Ragel.

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

- **5,300 lines of C11 against the C standard library and nothing else.** The
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

## What is worth stealing

Three things, in the order the project is likely to want them. All are on the
[roadmap](ROADMAP.md).

**JastAdd's reference attributes** would fix the exact limit stage 2 ran into:
an attribute cannot refer *forward* to a node the walk has not reached, so a
forward declaration needs two passes where a reference attribute would need
none.

**Stratego's strategies** are the ready-made design for the `%rewrite` that was
deferred at the start of this project. `bottomup` and `innermost` are the words
for the thing, and there is no reason to invent others.

**Statix's scope graphs**, if symbol tables ever get painful enough that
threading an environment stops feeling adequate. Not yet — `thread` is doing
fine on the languages tried so far — but this is what the next answer looks
like, rather than a bigger version of the current one.
