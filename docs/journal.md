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
