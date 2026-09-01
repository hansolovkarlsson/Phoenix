# Phoenix

A compiler-compiler. You write a language's grammar in EBNF and describe what
each construct means; Phoenix writes the compiler, in
[Solveig](https://github.com/hansolovkarlsson/Solveig).

```
pascal.phx  ──phx──▶  pascal.sol  ──solas──▶  pascal.sob
                                                  │
myprogram.pas ────────────────────────────────────┴──▶ myprogram.sol
                                          ──solas──▶ myprogram.sob ──solvm──▶ output
```

## Why not lex and yacc

Because they solve the front of the problem and leave you at the AST.

After the parser you still hand-write forward-declaration collection, type
checking, optimisation and code generation — four large modules that are mostly
traversal boilerplate and a little content, written again for every language.
Phoenix's claim is that **a compiler is a grammar plus a sequence of tree
walks**, and that both halves can be written down instead of programmed.

## Where it is

**Stage 0 of six.** The grammar half works: Phoenix reads a `.phx` file, scans
a source file with the lexical rules, matches it against the syntactic rules,
and prints the tree.

```sh
make
bin/phx examples/calc.phx examples/sum.calc
```

```
program
|- statement
|  |- "let"
|  |- name "width"
|  |- ":="
|  |- expression
|  |  |- term
|  |  |  `- factor
|  |  |     `- number "3"
|  |  |- "+"
|  |  `- term
...
```

Nothing yet describes what a program *means*. That is stage 2.

| Stage | | |
| --- | --- | --- |
| **0** | EBNF in, parse tree out | **done** |
| 1 | `->` names the AST node a production builds | |
| 2 | `%pass` — attributes over the tree, interpreted | |
| 3 | `%driver` — several passes, ordered, diagnostics gathered | |
| 4 | an `emit` pass that writes Solveig source | |
| 5 | `phx calc.phx -o calc.sol` — the standalone compiler | |

Each stage is useful on its own and tagged in git, so a design that turns out
wrong can be backed out of to the last stage that was right.
[docs/journal.md](docs/journal.md) records why each decision was made, which is
what makes backing out informed rather than archaeological.

## The notation

Wirth's, from *What can we do about the unnecessary diversity of notation for
syntactic definitions* (1977) and the Pascal report — the one nearly every
published grammar is written in, and one that describes itself:

```ebnf
production = identifier "=" expression "." .
expression = term { "|" term } .
term       = factor { factor } .
factor     = identifier | literal | "(" expression ")"
           | "[" expression "]" | "{" expression "}" .
```

The older shape is read by the same reader, because "a file in BNF" means that
one at least as often: `<name>` is a name, `=` and `:=` and `::=` are all the
definition symbol, and the trailing `.` is optional.

**Three additions, and no more.** Wirth's notation cannot describe a lexer — no
range, no negation, no way to write a tab — and each is needed before one file
can be read:

| | |
| --- | --- |
| `"a" .. "z"` | a range of one character |
| `! factor` | one character, provided that does not match here — `"{" { ! "}" } "}"` is a comment |
| `"\n" "\t"` | the escapes, inside a literal |

All three are lexical only. Using one where there are only tokens is an error
with a line number.

## The two halves

A grammar for a language is written over **tokens**, and says nothing about how
characters become them. Wirth's report gives the lexical rules too, in the same
notation, and that is the arrangement here: one file, one notation, two halves,
with a directive naming the seam.

```ebnf
%fragment letter digit
letter = "a" .. "z" .
digit  = "0" .. "9" .
name   = letter { letter | digit } .
space  = " " { " " } .
%skip space

%syntax
%start program
program = "print" name ";" .
```

| Directive | |
| --- | --- |
| `%tokens` | what follows is lexical — the default, so it is optional |
| `%syntax` | what follows is matched over tokens |
| `%fragment a b` | these lexical rules are helpers and never tokens on their own |
| `%skip a b` | these token kinds are produced and then thrown away |
| `%start name` | the goal rule; the first syntactic rule if unsaid |
| `%ignorecase` | letters compare without regard to case |

The seam is declared rather than guessed. A rule is not lexical because of
anything about its shape — `identifier` and `expression` look alike — and a
tool that guesses wrong reports a correct file as broken, which is the worst
thing this one could do.

**`%fragment` is the one that has to be learned.** `letter` and `digit` are
lexical rules and are not tokens; they are what the token rules are written out
of. Nothing about their shape says so, and a scanner taking the longest match
with ties broken by declaration order returns a file as a stream of `letter`,
because both rules match `x` and `letter` is first. There is a warning for
having forgotten, and a directive for saying what was meant.

**Reserved words are worked out rather than declared.** Every word-shaped
literal in the syntactic half is one, so `begin` cannot arrive as an identifier
and no grammar had to say so.

## What the matcher is

The two halves match differently, and the difference is the point.

**The lexical half takes the longest match** over every token rule, ties going
to the rule declared first — which is what every lexer does, and what makes
`"<" | "<="` a question nobody has to answer there.

**The syntactic half is ordered choice with local backtracking** — a PEG, not a
general parser. `a | b` tries `a`, and tries `b` only if `a` failed; if `a`
succeeds and the rule around it fails later, the choice is not revisited.

That is a real restriction, and it is said here rather than buried, because the
failure it produces is a syntax error on a file that is correct. It costs
nothing on an LL(1) grammar, which is what Wirth's Pascal is and what almost
every published grammar is. It costs something on a grammar with an alternative
that is a proper prefix of a later one — and *within a rule*, ordered choice
applies to the lexical half too, so `symbol = ":=" | ":"` must put the longer
first. Phoenix warns when it does not.

## What it checks before it runs

Every one of these exists because getting it wrong produces the same failure:
a correct file reported as broken, at a place that is not the mistake.

| | |
| --- | --- |
| left recursion | `a = a "+" b` is an infinite descent for ordered choice. Warshall over leftmost-reachability, so mutual recursion is caught too |
| a name that is not a rule | and one named by a directive but never defined |
| `..` or `!` over tokens | asking about characters where there are none |
| a literal nothing spells | `","` in the syntactic half when no token rule produces a comma — the rule can never match, and without this the message arrives at the first file with a comma in it |
| alternatives in the wrong order | `"<" | "<="`, in the lexical half where it matters |
| a fragment not declared one | the `letter` trap above |
| a rule nothing reaches | a leftover or a typo |

## Building

```sh
make            # bin/phx
make test       # 22 checks, including Solveig's pascal.bnf when it is present
```

C11, no dependencies.

## Evidence

The strongest available check that this reads real published grammars rather
than only its own examples: Solveig ships
[`pascal.bnf`](https://github.com/hansolovkarlsson/Solveig), Wirth's Pascal in
Wirth's notation, ~200 lines, together with files that `fpc -Miso` accepts and
files it rejects. Phoenix reads that grammar unmodified, accepts both good
programs and rejects all four bad ones, each with a line, a column and a caret.

```
missing-semicolon.pas:13:3: error: expected else, ; or end, and found "n"
    n := n + 1;
    ^
```

When a PEG fails at the top it has usually backtracked a long way from the real
mistake, so the position reported is the one the match got *furthest*, not the
one it stopped at.
