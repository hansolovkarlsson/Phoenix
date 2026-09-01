# Phoenix

A compiler generator. You write a language's grammar in EBNF and describe what
each construct means; Phoenix writes the compiler, in
[Solveig](https://github.com/hansolovkarlsson/Solveig).

```
pascal.phx  ──phx──▶  pascal.sol  ──solas──▶  pascal.sob
                                                  │
myprogram.pas ────────────────────────────────────┴──▶ myprogram.sol
                                          ──solas──▶ myprogram.sob ──solvm──▶ output
```

## The name

**Phoenix is a *compiler-compiler*, and that is a claim rather than a
description.** The two terms mean the same thing and the literature uses them
interchangeably; what differs is what each has come to suggest.

The phrase belongs to Brooker and Morris, whose Compiler Compiler ran at
Manchester around 1960, and it meant something larger than a parser: their
system had a notation for what constructs *meant*, not only for what they
looked like.

**yacc borrowed the name and delivered a fraction of it.** *Yet Another
Compiler-Compiler* is a parser generator. It gives you the front of the problem
and leaves you at the syntax tree, which is the complaint this project starts
from -- and because yacc is by far the most famous bearer of the term,
"compiler-compiler" now reads as "thing like yacc" to most people who meet it.

So the first line of this page says **compiler generator**, which is
unambiguous and is what the tools Phoenix most resembles -- JastAdd, Silver,
Eli -- call themselves. The older phrase is kept for the argument it carries:
describing syntax *and* meaning is what a compiler-compiler was for before it
was narrowed, and Phoenix has a better claim on the word than yacc ever did.

*Phoenix* is the bird that is rebuilt from what is left of the one before it,
which is what a compiler generator does to a language description and,
separately, what this repository is.

A third term, **metacompiler**, carries a narrower sense from META II (Schorre,
1964): a compiler-writing tool written in its own notation, able to compile
itself. Phoenix is not one -- `phx` is C, and the `.phx` notation is read by a
hand-written parser. It could become one; see
[self-hosting](docs/journal.md#2026-09-01--what-self-hosting-would-and-would-not-prove)
for what that would and would not prove.

## Why not lex and yacc

Because they solve the front of the problem and leave you at the AST -- which
is the same sentence as above, and is the whole reason for the name section
preceding it.

After the parser you still hand-write forward-declaration collection, type
checking, optimisation and code generation — four large modules that are mostly
traversal boilerplate and a little content, written again for every language.
Phoenix's claim is that **a compiler is a grammar plus a sequence of tree
walks**, and that both halves can be written down instead of programmed.

## Where it is

**Stage 2 of six.** Phoenix reads a `.phx` file, parses a source file with it,
builds the AST its `->` clauses describe, and runs the `%pass` blocks that say
what the program *means* — interpreting it, or compiling it.

```sh
make
bin/phx examples/calc.phx examples/sum.calc
```

```
Program
`- body: [3]
   |- Let
   |  |- name: "width"
   |  `- value: Binary
   |     |- op: "+"
   |     |- left: Number
   |     |  `- value: "3"
   |     `- right: Number
   |        `- value: "4"
...
```

Nothing yet describes what a program *means*. That is stage 2.

| Stage | | |
| --- | --- | --- |
| **0** | EBNF in, parse tree out | **done** |
| **1** | `->` names the AST node a production builds | **done** |
| **2** | `%pass` — attributes over the tree, interpreted | **done** |
| 3 | `%driver` — several passes, ordered, diagnostics gathered | |
| 4 | an `emit` pass that writes Solveig source **and C** | **done early** |
| 5 | `phx calc.phx -o calc.sol` — the standalone compiler | |

The emitted target belongs to the `.phx` file, not to Phoenix: an emit pass
synthesises a string and nothing cares what is in it, so a grammar that wants C
or assembly out of its compiler writes different emit clauses rather than
needing a different Phoenix. Stage 4 builds two backends from one `calc.phx`
specifically to keep that true.

Each stage is useful on its own and tagged in git, so a design that turns out
wrong can be backed out of to the last stage that was right.
[docs/journal.md](docs/journal.md) records why each decision was made, which is
what makes backing out informed rather than archaeological.

## What a production builds

`->` after an alternative says what it *means*, as against what it looks like.
Without one, a rule answers what it matched and the tree is the concrete one,
every bracket and semicolon in it.

```ebnf
program   = { statement } -> Program(body: $1) .

statement = "print" e:expression ";"           -> Print(value: $e)
          | "let" n:name ":=" e:expression ";" -> Let(name: $n, value: $e) .

factor    = number             -> Number(value: $1)
          | name               -> Variable(name: $1)
          | "(" expression ")" -> $2 .
```

`$n` is the n'th factor, counting from one and counting everything. A factor can
be given a name instead — `e:expression`, then `$e` — which survives the
alternative being edited. **Both are checked when the grammar is read**, because
`$3` drifting after a factor is inserted before it is yacc's most famous silent
failure: the grammar still builds and the tree is quietly wrong.

### `$$`, and why a fold needs saying only once

`$$` is what has been built so far. An action mentioning it **replaces** the
value before it rather than following it — which is a left fold, and is how the
flat repetition every grammar writes for a binary operator becomes the tree it
means:

```ebnf
expression = term { ( "+" | "-" ) term -> Binary(op: $1, left: $$, right: $2) } .
term       = factor { ( "*" | "/" ) factor -> Binary(op: $1, left: $$, right: $2) } .
```

Precedence comes from the grammar, associativity from the fold, and
`width * height - 1` comes out as `Binary(-, Binary(*, width, height), 1)`.

### Interior nodes are never built

One rule decides what a production answers, and it has no exceptions:

> **A body that produced one value answers that value. A body that produced any
> other number answers a node named after the rule, holding them.**

So a chain of rules that each pass one thing along — `expression` to `term` to
`factor` to a number — collapses to the number, and nobody had to say so. The
useless interior nodes that every hand-written tree-builder exists to strip are
not stripped; they are never built.

### The vocabulary

`--nodes` prints the node types a grammar can build and the fields each carries
— which is the surface a pass will be written against:

```
$ bin/phx --nodes examples/calc.phx
Program(body)
Print(value)
Let(name, value)
Binary(op, left, right)
Number(value)
Variable(name)
```

A type built with two different field lists is a warning, since a pass keyed on
it would have to handle both.

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
| `$n` past the last factor | and `$label` naming no factor — yacc's silent drift, made loud |
| one node type, two shapes | a pass keyed on it would have to handle both |

## Building

```sh
make            # bin/phx
make test       # 37 checks, including Solveig's pascal.bnf when it is present
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
