# Phoenix

A compiler generator. You write a language's grammar in EBNF and describe what
each construct means; Phoenix writes the compiler.

```
pascal.phx  ──phx──▶  pascal.c  ──cc──▶  cpas
                                          │
myprogram.pas ────────────────────────────┴──▶ myprogram.c ──cc──▶ a program
```

C11, no dependencies, and nothing outside this repository is needed to build it
or to run its tests.

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

**All six stages are done.** Phoenix reads a description, and either runs it —
parsing a file, checking it, compiling it — or writes it out as a C program
that does the same thing without Phoenix.

```sh
phx examples/pascal.phx -o pascal.c   # a Pascal compiler, 4,800 lines
cc pascal.c -o pas                    # no flags, no headers, no library
./pas prog.pas
```

```sh
make
bin/phx examples/calc-c.phx examples/sum.calc
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
| **3** | `%driver` — several passes, ordered | **done** |
| **4** | an `emit` pass that writes C | **done** |
| **5** | `phx desc.phx -o desc.c` — the standalone compiler | **done** |

The emitted target belongs to the `.phx` file, not to Phoenix: an emit pass
synthesises a string and nothing cares what is in it, so a grammar that wants C
or assembly out of its compiler writes different emit clauses rather than
needing a different Phoenix. Stage 4 builds two backends from one `calc.phx`
specifically to keep that true.

## Writing a compiler out

A generator has two ways to produce a compiler. It can **emit code** — a
recursive-descent function per rule, a switch per pass — which is faster and is
what most of the yacc family does. Or it can **emit the description as data**
and ship the machine that already runs it.

Phoenix emits data, and the reason is the one this project keeps returning to:
the alternative is a second implementation of everything. A second matcher with
the same ordered-choice rules, a second evaluator with the same floored
division, a second pattern matcher. **Two implementations of one notation have
to agree**, and avoiding exactly that is why actions are not host-language
splices and why [semantics.md](docs/semantics.md) exists.

So a generated compiler runs *the same* `lex.c`, `parse.c`, `eval.c` and
`run.c` that `phx` runs, over a grammar frozen into static tables, all of it
written into one file. There is nothing for the two to disagree about, because
there is only one of them — and the test says so:

```
ok    sum.calc: identical to phx, byte for byte
ok    a Pascal compiler, and it agrees with phx
```

What it costs is speed: the generated compiler interprets a PEG rather than
being one. If that ever matters, the answer is to compile the tables to code
*afterwards*, against a definition the tables have already pinned down.

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

## Drivers

```
%driver c     = show, typecheck, emit-c -> out .
%driver run   = show, typecheck, eval   -> out .
%driver check = show, typecheck .
```

Passes in order, and which attribute of the root is the answer. A driver with
no `->` is a validation run: nothing is printed and the exit status is all it
says. The first declared is the default, for the same reason the first
syntactic rule is the default `%start`.

```sh
phx calc-c.phx prog.calc                # the first driver
phx calc-c.phx prog.calc --driver run   # by name
phx --drivers calc-c.phx                # what there is to choose from
phx --tree    calc-c.phx prog.calc      # the tree, whatever drivers exist
```

**Attributes stay on the nodes between passes**, which is what makes a sequence
worth having. `typecheck` can render the expression it is complaining about
using `show`, a pass that came from [`lib/expression.phx`](lib/expression.phx)
and knows nothing about calc:

```
print-a-bool.calc:3:3: error: print wants an int, and (n < 2) is bool
    print n < 2;
    ^
```

**A pass that reports an error stops the ones after it** — not because the
sequence could not continue but because it should not, since a later pass
reading what a failed one left produces consequences of the first mistake
rather than new information.

### A driver is a claim about order, and it is checked

If a pass reads `$left.type` and the driver forgot to run `typecheck`, the
alternative to catching it here is a message from inside a pass about a missing
attribute — naming neither the driver that got the order wrong nor the pass
that would have supplied it. What each pass defines and what it reads are both
decidable when the description is read:

```
misordered-driver.phx:20:15: error: driver 'bad' runs 'typecheck', which reads
                            '.show', and nothing before it defines one
phx: 'show' defines 'show' — did the driver mean to run it first?
```

**That message is the reason to declare a driver** rather than to run passes in
whatever order they were typed.

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

## What a `.phx` file is called

Worth settling, because the docs say it on every page.

A `.phx` file is a **description** — it describes a language: how it is written
and what it means. Phoenix turns a description into a compiler, which is the
same word the compiler-generator literature uses and the one that says what the
file is *for* rather than what it is made of. It is not a program: nothing runs
it. It is not a grammar either, not since it grew passes.

When the file is being talked about as a **unit** — one of several, importable,
sitting in a directory — it is a **module**. `%import` brings in a module. A
module with a `%start` can stand on its own; one without is only ever imported,
and that is the whole of the distinction. There is no separate word for the
partial kind, and deliberately so: *fragment* is already spoken for by
`%fragment`, and a second meaning for it would be a trap.

So: **a description, assembled from modules, describing a language.**

## `%import`, and what belongs in `lib/`

```ebnf
%import "lexical.phx"
%skip space line-comment
```

A description is read into one grammar however many files it came from, and a
file is read **once** however many times it is named — so two modules may both
import a third, and two modules may import each other, without anybody arranging
for it. A module is looked for beside the file that names it, and then in the
library beside the `phx` executable (`$PHX_LIB` overrides). `--imports` lists
what a description was assembled from, and a diagnostic always names the file it
came from, with that file's own line numbers.

**The split that matters is not grammar-versus-passes.** It is *the language*
against *the target*:

| | |
| --- | --- |
| `examples/calc.phx` | the grammar, the tree, `typecheck`, `eval` — none of which has an opinion about C |
| `examples/calc-c.phx` | `%import "calc.phx"` and an emit pass |
| `examples/calc-solveig.phx` | `%import "calc.phx"` and a different emit pass |

Everything upstream of emitting is about the source language. Only emit is per
target — which is why `calc-solveig.phx` went from ninety lines of duplicated
grammar, quietly wrong the first time `calc.phx` changed, to an emit pass and a
line naming the language.

### Modules declare their holes

An expression grammar cannot know what a language's atoms are — a number, a
name, a call, an index — and that is the one thing every language differs
about. So a module says what it needs and leaves it open:

```ebnf
%require primary
...
unary = "-" u:unary -> Negate(value: $u) | "(" expression ")" -> $2 | primary .
```

A description with an open hole reads fine — that is what a module *is* — and
is refused, by name, the moment something asks it to parse a file. A module
system needs an interface in both directions, and `%require` is the half that
is easy to forget.

### What goes in `lib/`

[`lib/expression.phx`](lib/expression.phx) is infix with the precedence
everybody expects: `or`, `and`, `not`, the six comparisons, `+ -`, `* /`, unary
minus and grouping, folded left. Fill in `primary` and you have expressions:

```ebnf
%import "expression.phx"
primary = integer -> Number(text: $1) | name -> Variable(name: $1) .
```

`a + 2 * -b < 10 and not c` then parses as `(((a + (2 * -b)) < 10) and not c)`,
and `examples/calc.phx` gets boolean operators and unary minus without writing
a line of grammar for them.

**Importing a grammar module costs two things, and both are worth stating.**
It **reserves words** — `and`, `or` and `not` cannot be identifiers in a
language that imports this one, which is why `div` and `mod` are deliberately
*not* in it. And it **hands you a vocabulary**: the tree will contain `Logical`,
`Not` and `Negate`, and your passes have to answer for them. Phoenix names the
missing clause the first time a program reaches for one.

[`lib/lexical.phx`](lib/lexical.phx) is the other citizen and the simpler one: `name`, `integer`, `real`, `hex`, `text` with
escapes, three comment shapes, `space`, and the `%fragment` declarations that
keep `letter` from arriving as a token. Every language needs most of that and
the fiddly parts are fiddly in the same way each time.

`%skip` is *not* in it, on purpose. Whether whitespace is thrown away is the
language's business — a layout-sensitive one keeps it — so the importing
description says so.

**A pass is only reusable together with the grammar that produces the nodes it
keys on** — a pass naming `Binary` needs something to build one. That much held
up. What did not is the expectation that followed from it: building
`expression.phx` turned up exactly **one** pass worth sharing, and it is not a
typechecker.

`show` renders an expression back to something close to what was read, for
putting inside a diagnostic — *"cannot add {} and {}"* — and it qualifies
because it depends on the shape of these nodes and on nothing else. A
typechecker over the same nodes would need the importing language's type
system; an emit pass would need its target. Both are the caller's, so both stay
the caller's.

So a `lib/` module is mostly grammar, occasionally with a pass attached, and
`lexical.phx` being pure grammar is not the exception it looked like — it is
upstream of any node at all.

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
| a clause nothing can reach | a general pattern above a specific one takes every case the specific one was for — the ordering hazard again, one level up |
| `$n` past the last factor | and `$label` naming no factor — yacc's silent drift, made loud |
| one node type, two shapes | a pass keyed on it would have to handle both |

## Building

```sh
make            # bin/phx
make test       # 90 checks, including Solveig's pascal.bnf when it is present
```

C11, no dependencies, and the test suite is hermetic — it reads nothing outside
this repository.

## What Phoenix emits, and what it is not tied to

**The language a generated compiler emits belongs to the `.phx` file, not to
Phoenix.** An emit pass builds a string and nothing anywhere cares what is in
it, so targeting C, or assembly, or something else, is a matter of writing
different clauses:

```
%pass emit-c
  Binary : out = "({} {} {})" of $left.out, $op, $right.out .
```

`examples/calc.phx` emits C. `examples/calc-solveig.phx` is the same calculator
emitting [Solveig](https://github.com/hansolovkarlsson/Solveig) instead, and the
only difference between the two files is those clauses.

**Solveig is parked rather than removed.** Phoenix began as a generator of
Solveig compilers and will likely emit Solveig again. It does not now, for two
reasons: Solveig is still changing, and keeping a second backend in step with a
moving language is maintenance spent proving a property that
[docs/semantics.md](docs/semantics.md) and the conformance test below already
prove. The parked example is still *read* by the test suite, so the notation
cannot drift out from under it; `PHX_TEST_SOLVEIG=1 make test` runs the round
trip for anyone who has `solas` to hand.

### The conformance rule

> The same `.phx`, interpreted and through every backend, produces identical
> output.

That is a test on every build, and it is what keeps the meta-language honest
now that there is one target rather than two. `--run eval` and `--run emit-c`
are **two independent implementations of the same notation** — a C interpreter
and generated C — and they have to agree on 97. Everything they could disagree
about is fixed in [docs/semantics.md](docs/semantics.md), in Phoenix's own terms
rather than any host language's: integers that trap rather than wrap, floored
division, no implicit conversion, structural equality.

## Where this sits

Every mechanism in Phoenix has prior art and the combination is what is
unusual. [docs/lineage.md](docs/lineage.md) places it against the metacompilers
it most resembles (TREE-META's unparse rules are a `%pass emit` in 1967), the
attribute-grammar systems it borrows from (JastAdd, Silver, Eli — whose LIDO
already had the threaded attribute, under the name CHAIN), the rewriting systems
that solved `%rewrite` already (Stratego), and the yacc family it is trying not
to be.

[docs/ROADMAP.md](docs/ROADMAP.md) says what is coming, what is worth stealing
from whom, and what is deliberately absent.

## Evidence

The strongest available check that this reads real published grammars rather
than only its own examples: [`tests/pascal/pascal.bnf`](tests/pascal/) is
Wirth's Pascal in Wirth's notation, ~185 lines, together with files that
`fpc -Miso` accepts and files it rejects. Phoenix reads that grammar unmodified,
accepts both good programs and rejects all four bad ones, each with a line, a
column and a caret.

```
missing-semicolon.pas:13:3: error: expected else, ; or end, and found "n"
    n := n + 1;
    ^
```

[`examples/pascal.phx`](examples/pascal.phx) is that grammar with `->` clauses
added — 51 node types, an abstract tree with no punctuation in it, and a pass
that reads packed arrays, pointer types, records, sets and `var` parameters back
out:

```
$ bin/phx examples/pascal.phx tests/pascal/features.pas
program Features(input, output)
  const     Max = 100
  type      Str = packed array [1..80] of char
  type      Node = record key: integer; left, right: Tree
  var       d : Digits
  procedure Walk(t : Tree; var count : integer)
```

It also checks programs. A `symbols` pass gathers each block's declarations on
the way up, and a `typecheck` pass reads them on the way down — two passes,
because an inherited attribute runs *before* a node's children and gathering
runs after, so one walk cannot do both:

```
$ bin/phx --driver check examples/pascal.phx wrong.pas
wrong.pas:8:3: error: cannot assign integer to boolean
    ok := n;
    ^
wrong.pas:9:21: error: 'nope' is not declared
    if n then writeln(nope);
                      ^
```

The value of doing this to Pascal rather than to another toy is that the grammar
was written by somebody else, for another purpose, years before Phoenix existed.
What it could not say is recorded in [the journal](docs/journal.md).

The checker follows records and forward declarations, which took no mechanism
beyond what was there. A value can *be* a node, so an environment that binds a
name to the thing it was declared as is an ordinary list of pairs — and
`with origin do ... x ...` is four hops through it:

```
origin   → NamedType(name: "Point")     the variable's declared type
"Point"  → RecordType(fields: [...])    what that type is
fields   → what each FieldDecl declares
```

**Every hop points backwards**, at a node the single post-order walk has
already finished with. That is why it needed nothing, and it is why the
[roadmap's](docs/ROADMAP.md) entry on reference attributes is now about
*forward* references only.

When a PEG fails at the top it has usually backtracked a long way from the real
mistake, so the position reported is the one the match got *furthest*, not the
one it stopped at.
