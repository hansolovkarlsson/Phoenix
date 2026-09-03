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

**Start here:** [hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
is the same documentation with a front page in front of it.
[docs/tutorial-picture.md](docs/tutorial-picture.md) builds a
language and its compiler from nothing in half an hour.
[docs/manual.md](docs/manual.md) explains the notation,
[docs/reference.md](docs/reference.md) is the lookup, and
[docs/cheatsheet.md](docs/cheatsheet.md) is one page.

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

**All seven stages are done, and eight more since.** Phoenix reads a
description, and either runs it —
parsing a file, checking it, compiling it — or writes it out as a C program
that does the same thing without Phoenix. What a description compiles *to* is
its own business: C, another language, or a binary — Solveig's `.sob` bytecode
is emitted by [a description](languages/solveig/solveig-sob.phx), not by
Phoenix.

```sh
phx languages/pascal/pascal-c.phx -o pasc.c   # a Pascal-to-C compiler, one file
cc pasc.c -o pasc                     # no flags, no headers, no library
./pasc prog.pas > prog.c && cc prog.c -o prog && ./prog
```

Nothing in that chain but `cc`. What it compiles includes
[`languages/pascal/tests/grammar/gcd.pas`](languages/pascal/tests/grammar/), the fixture that has been in this
repository since the first commit — records, sets, enumerations, a `case`, a
`with`, `var` parameters and field widths — written for another tool years
before Phoenix existed:

```
greatest common divisor
   3   4
green was not seen
blue
    21
   1   4   9  16  25  36  49  64  81 100
       both positive
```

```sh
make
bin/phx languages/calc/calc-c.phx languages/calc/programs/sum.calc
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
ok    12 .sob files, byte for byte, from phx and from a compiler it wrote
```

**The third line is there because the first two were not enough.** They compare
text a person could read, and the description that emits *bytes* had never been
written out as a compiler at all — so nothing noticed that a literal holding a
NUL was frozen with `strlen` and arrived short, while the length beside it
still said otherwise. `phx` and the compiler it wrote disagreed, silently,
about a description they were both meant to be running.

"There is only one implementation" is a claim about the code. That it *holds*
is a claim about the tests, and it is only as strong as the widest thing they
compare.

What it costs is speed: the generated compiler interprets a PEG rather than
being one. [docs/performance.md](docs/performance.md) says how much — the
matcher is linear in every shape tried, at about 24 match-steps per token, and
20,000 lines of Pascal reach running C in 238 ms. If that ever matters, the
answer is to compile the tables to code *afterwards*, against a definition the
tables have already pinned down.

Each stage is useful on its own and tagged in git, so a design that turns out
wrong can be backed out of to the last stage that was right.
[docs/journal.md](docs/journal.md) records why each decision was made, which is
what makes backing out informed rather than archaeological, and
[docs/postmortem.md](docs/postmortem.md) scores those decisions against what
the evidence later said — including the predictions that were wrong, and the
one claim on that page that a later stage falsified outright.

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
$ bin/phx --nodes languages/calc/calc.phx
Program(body)
Print(value)
Let(name, value)
Binary(op, left, right)
Number(value)
Variable(name)
```

A type built with two different field lists is a warning, since a pass keyed on
it would have to handle both.

## `otherwise`: what a node answers when its rule does not

A clause is keyed on a node type, and some attributes are answered the same way
by nearly every type. `languages/pascal/pascal.phx` wrote `type = "void"`
twenty-one times, with a comment saying why: *so that a node above it can read
a type without asking which kind of statement it was.*

```
%pass typecheck
  otherwise type = "void"
  ...
```

One clause, for every node whose own rule works nothing out. It runs **after**
that rule, so it can read what the rule worked out, and only for the attributes
the rule left alone. A node with a *field* of that name reads the field —
`.name` reads a field before an attribute — which is the node saying so itself,
and is what this is "otherwise" to.

**It is still a clause about a node**, which is why it is this rather than a
function or a macro. A description that could call a function would be a
description with two kinds of thing in it, and the reason this tool is small is
that there is only ever one.

What it buys, besides twenty lines of Pascal: a list of nodes has a column of
whatever every node answers. `$body.runs` is the line table of a chunk and
`$body.fileidx` is its file table, and neither needed a way to map over a list —
they needed an attribute every node has.

## `%embed`: a file's bytes, under a name

A backend that emits a language needs that language's **runtime**, and a
description has nowhere to put one. `languages/pascal/pascal-c.phx` gets away
with four `#include`s because Pascal's types are C's types.
`languages/awk/awk-c.phx` needs seven hundred lines, because awk's value model
is a string and a number at once and its one aggregate is a hash table.

```
%embed runtime "awk-runtime.c" .
...
: out = join([$runtime, $declarations, ...], "\n") .
```

The file is read when the description is read, and its bytes are frozen into
whatever `-o` writes — so **one file, no headers, no library** still holds. It
is looked for beside the description and then in `lib/`, which is where
`%import` looks; `--imports` names it, because a Makefile that rebuilds on a
change wants it.

**The reason is not that the literals were ugly.** Seven hundred lines of C
inside a `.phx` cannot be *compiled*. That runtime was written as a standalone
file and checked against awk before being embedded — and then the file was
thrown away, so the artefact that had been tested was not the artefact in the
repository. Now it is one, and `make test` compiles it on its own.

## `%rewrite`: when the answer is a different node

A `%pass` **decorates**: it works out attributes and leaves the tree alone. A
`%rewrite` **replaces**:

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(text: a), right: Number(text: b))
    => Number(text: text(int($a) + int($b))) .
```

Both halves were already here — a pattern tests and binds, and the evaluator
builds nodes — so what this adds is a traversal that puts the answer back. It
is the same matcher and the same evaluator a pass uses, so the two cannot
disagree about what a pattern means.

The strategy is a word and not a default, because getting it wrong is silent:
`2 + 3 * 4 + 1` folds to `15` bottom-up and stops at `((2 + 12) + 1)`
top-down, which asks about the outside of an expression before its inside.

| | |
| --- | --- |
| `bottomup` | children first, then this node, once |
| `topdown` | this node first, then the children of whatever it became |
| `innermost` | bottom-up, and again on the result until nothing matches |

**What it is for is the thing a clause cannot say.** A clause answers *about* a
node; some things are answered by there being a different node. Solveig's
`x:ifTrue({ ... })` compiles to a jump rather than to a block, and written as
clauses that would mean conditioning thirty of `Block`'s on whether its parent
inlined it. Written as a rewrite it is one rule: the block is not something to
compile differently, it is something that should not be there.

```
Send(to: c, message: "ifTrue", args: [Block(params: [], temps: [], body: b)])
  => IfTrue(cond: $c, body: $b) .
```

A rewrite is a stage of a `%driver` like a pass, and is named the same way:
`%driver sob = inline, sob -> out`.

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
| `languages/calc/calc.phx` | the grammar, the tree, `typecheck`, `eval` — none of which has an opinion about C |
| `languages/calc/calc-c.phx` | `%import "calc.phx"` and an emit pass |
| `languages/calc/calc-solveig.phx` | `%import "calc.phx"` and a different emit pass |

Everything upstream of emitting is about the source language. Only emit is per
target — which is why `calc-solveig.phx` went from ninety lines of duplicated
grammar, quietly wrong the first time `calc.phx` changed, to an emit pass and a
line naming the language.

### `%include`: the same question, one level down

`%import` is about the *description*. A target language often has the same
thing about its own files — Solveig writes `@include "library.sol"` — and that
one is not a pass and cannot be:

> **A pass is a walk over one tree that has already been read.** An include is
> a second file, which has to be read before there is a tree to walk. No clause
> can reach it, however it is written.

So it is a directive the reader acts on, and it says two things:

```ebnf
include = "@include" p:string -> Include(path: slice($p, 2, size($p) - 1)) .
%include Include path .
```

which node an include is built as, and which of its fields holds the file. What
happens then is fixed and is not a description's to vary: the file is read with
this same grammar, and **the items its root holds take the include node's place
in the list that held it**, before the first pass. A backend needs no clause for
an include and never meets one.

The quotes come off in the *action*, not in the reader, and that is deliberate:
how a language spells a string is the one thing only its own description knows.

**The rules are C's, for C's reasons.** A file is found beside the file that
includes it — never beside the directory you were standing in, so a program
survives being moved — and failing that on the search path, `-I dir` in the
order given. A file is read **once** however many ways it is reached, which is
also the whole of why a cycle ends: there is nothing to detect, because a file
that comes round to itself finds itself already read. `--no-includes` asks
about one file's own text instead, which is what a round trip is a question
about.

Two shapes are refused rather than guessed at: an include where a *field* is
expected, since a file is a number of things and a field holds one; and a file
whose root holds two parts, since nothing says which of them a statement
position wanted.

### `$pos`: where a node came from

Every node carries a position and nothing in a clause could reach it, so a
`.sob` written here had one line run for a whole chunk and no file table:
every message from a program it compiled said `[line 1]`. `$pos` is what reads
it, and it answers a **node**:

```
Position(line, column, file, endline, endcolumn)
```

which is the whole of the design. A number would have been smaller and would
have meant nothing to a description — every use a description has for a
position is a line or the name of a file. A node makes reading part of one an
ordinary field read, so the notation needs no new syntax and no library
function, and a fifth thing later is a field rather than a second reserved
name. `endline` and `endcolumn` arrived exactly that way.

**A node is a stretch of source and not a point.** That matters wherever
something is emitted after the things it is about: a send's own bytes go in
after its arguments, so the line they belong to is where the argument list
*ends*.

`.` over a list already means "that of each", so a table with a row per
statement is written the way every other list is:

```
Program : lines = bytes($body.pos.line, 4) .
```

`file` is the file that node's text came from, which after an `@include` is
not necessarily the one the command line named.

**One word is reserved.** `$pos` resolves before bindings, fields and
attributes, so that it means the same thing in every clause of every pass — and
a grammar that builds a node with a field called `pos` is refused when the
description is read rather than getting two answers later.

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
and `languages/calc/calc.phx` gets boolean operators and unary minus without writing
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
| an attribute with a field's name | a field is read before an attribute, so nothing outside the pass could see it |
| a threaded attribute with a field's name | the clause updating the thread reads the field, so the thread quietly skips that node. The sharper half of the line above, and an error rather than a warning |
| an inherited clause reading its own rule's work | `down` runs on the way in and the attribute is computed on the way out |
| a check reading the attributes it guards | a check runs first, by design |
| `%include` naming a node nothing builds | or a field that node has not got — the mechanism would then do nothing, quietly, and every include would reach a pass as a node it has no clause for |
| a field or an attribute called `pos` | the name every node says its position with, so it has to mean one thing everywhere |
| a rewrite named like a pass | a driver names a stage by its name, so which one it meant has to be one stage |
| a rewrite reading an attribute | it runs to change the tree, so the walk it would be reading has not happened |
| two `otherwise` clauses for one attribute | two answers to what a node answers when it has none of its own |

## The layout

```
phoenix/      the tool, in C11
lib/          modules any description may import
languages/    one directory per language described
  pascal/       the grammar, a typechecker, a compiler to C, and its tests
  solveig/      a front end and a bytecode backend, against that project's own
  awk/          pattern-action rules, and a compiler to C, against /usr/bin/awk
  solvm/        an assembler for Solveig's .sob bytecode, against solas
  calc/         the smallest language worth having a compiler for
  phx/          the notation described in itself
tests/        tests of Phoenix rather than of any language
bench/        measuring the tool, with Pascal as its subject
docs/
```

**A language keeps its own tests.** `languages/pascal/tests/` holds the
published grammar it is checked against, the programs compared with `fpc`, and
the programs that must be refused — so a second language arrives beside the
first rather than mixed into it. [`languages/README.md`](languages/README.md)
says what goes where.

## Building

```sh
make            # bin/phx
make test       # 184 checks, covering 35 Pascal programs against fpc
                #   and 76 Solveig programs against solas, byte for byte
```

C11 and no dependencies. **The suite passes with nothing outside this
repository** — 181 of the 184 need only what is vendored here, and the two
that drive `solas` and `solvm` over a checkout of
[Solveig](https://github.com/hansolovkarlsson/Solveig) report themselves
skipped when it is absent rather than failing. The assembler is in the 177:
its programs are held against the bytes they assembled to last time, so it is
tested without SolVM and held *against* SolVM when there is one.

```sh
SOLVEIG=/path/to/Solveig make test    # the other two, and the assembler against solas
PHX_TEST_SOLVEIG=1 make test          # also emit Solveig from calc.phx and compile it
```

Both default to a sibling checkout's usual place, so neither is needed if
`Solveig` sits beside `Phoenix`. `fpc -Miso` is what the Pascal oracle wants,
and is likewise skipped rather than failed when it is not installed.

## What Phoenix emits, and what it is not tied to

**The language a generated compiler emits belongs to the `.phx` file, not to
Phoenix.** An emit pass builds a string and nothing anywhere cares what is in
it, so targeting C, or assembly, or something else, is a matter of writing
different clauses:

```
%pass emit-c
  Binary : out = "({} {} {})" of $left.out, $op, $right.out .
```

`languages/calc/calc.phx` emits C. `languages/calc/calc-solveig.phx` is the same calculator
emitting [Solveig](https://github.com/hansolovkarlsson/Solveig) instead, and the
only difference between the two files is those clauses.

**And a target need not be text at all.**
[`languages/solveig/solveig-sob.phx`](languages/solveig/solveig-sob.phx)
compiles Solveig to SolVM `.sob` bytecode — a length-prefixed binary with
nested method chunks — which `solvm` runs. Fifty of the Solveig files in that
repository compile to bytecode that prints exactly what `solas`'s does.

That backend is what found the first thing the notation could not say, and it
was not the missing `if`: **a threaded attribute could not nest.** A method
chunk carries its own name and constant tables, so entering one has to start
them empty and leaving one has to put the enclosing tables back, and a single
chain along the walk has no stack in it. A `down` clause naming a thread now
sets it for the subtree, which makes the save an ordinary `down` attribute and
the restore an ordinary leaving clause. [docs/journal.md](docs/journal.md) has
the reasoning.

**Solveig is parked as an emit target for `calc` rather than removed.** Phoenix began as a generator of
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

**And that page is executable.** Every claim it makes is a check in
[`tests/grammars/semantics.phx`](tests/grammars/semantics.phx) and every
refusal is a clause in `semantics-refused.phx`, run through `phx` and through a
compiler `phx` wrote — which has to produce the same complaints byte for byte.

```
ok    44 claims from docs/semantics.md hold
ok    and every refusal it names
ok    and hold in a compiler phx wrote
ok    with the same complaints, byte for byte
```

A specification nothing runs is a document about a program, and drifts from it
one sentence at a time.

## The notation, described in itself

[`languages/phx/phoenix.phx`](languages/phx/phoenix.phx) is the `.phx` notation written in
`.phx`, and it **parses itself** — along with every other description in this
repository. That is Wirth's own argument for the notation he proposed, carried
out rather than asserted: a notation that can describe its own grammar has
demonstrably got enough in it.

It does not replace the hand-written reader, and could not: the PEG machine and
the scanner are not derived from any grammar. It describes the *shape* of a
`.phx` file, which is [level one of three](docs/journal.md).

Four things came out of writing it, and three were improvements:

| | |
| --- | --- |
| **an attribute should be its own token** | the reader used to tell `$left.val` from `$left .` by whether a space preceded the dot — the one place whitespace changed a meaning. The description says it as a lexical rule, *a dot with a lower-case letter immediately after*, and **the reader does that now**: no special case, and it covers `at($vars, 1).name`, an attribute of a call, which the old rule was never about |
| **a directive can be terminated** | `%fragment letter digit` ended at the end of a line, and a grammar over tokens cannot see one. A `.` after a directive is now accepted, as everything else in the notation already was |
| **reserved words cannot be opted out of** | every word-shaped literal becomes one, so `of` and `and` and `div` are operators here and good field names elsewhere. A place wanting a plain name has to list them |
| **the optional production terminator is undescribable** | ending a production without its `.` needs two-token lookahead, and `!` is lexical only. The one real gap |

## The oracle

[`languages/pascal/tests/oracle/`](languages/pascal/tests/oracle/) holds Pascal programs that are compiled twice
— once by `fpc -Miso`, once by Phoenix — run, and compared byte for byte.
**fpc is the oracle**: where they differ, Phoenix is wrong until somebody shows
otherwise, because fpc has been read by more people than this repository has.

It is skipped rather than failed where there is no fpc. Fourteen programs agree
with `fpc -Miso` byte for byte; the first eight found **six bugs at once**:

| | |
| --- | --- |
| `mod` was C's `%` | ISO Pascal's is the non-negative remainder: `-7 mod 2` is **1**, not −1, and `7 mod -2` is an error |
| an integer had no default width | Pascal right-justifies in 11; `writeln(15)` prints nine spaces first |
| a boolean printed as `1` | it is ` true` and `false`, in a field of five |
| a real printed as `1.5` | it is ` 1.5000000000000000e+000` — scientific, sixteen digits, a **three**-digit exponent where C's `%e` gives two |
| a recursive function would not compile | the result variable took the function's name, so `Fact(n-1)` called a `long` |
| a signed constant and a signed expression shared a node | and only one of them can answer what type it is |

Every one is a place C's obvious answer is not Pascal's, and none would have
been found by reading the output and thinking it looked right.

Twenty-four programs agree now. Six more — the standard functions, chars,
enumerations, sets, `case` with several labels, a `with` inside a `with` —
found **four more**, and two of them were in Phoenix rather than in the
description:

| | |
| --- | --- |
| **`each` ran to the shorter list** | so `abs(i)` came out as `abs()`. The first list is what a call puts before each argument, and a call to something undeclared puts nothing before anything — so the first list was empty and so was the answer |
| **`lookup` compared only text** | an integer key silently never matched, so `lookup([[1, "char"]], size(t), "string")` answered `"string"` for every length. It compares the way `=` does now |
| Pascal's standard functions | `abs`, `sqr`, `odd`, `ord`, `chr`, `succ`, `pred`, `round`, `trunc` — none is a C function, and `abs` and `succ` depend on their argument's type |
| a one-character literal is a **char** | `c := 'a'` was a type error, and `ord('A')` took the address of a C string |

### And what it does not cover

An oracle says the subset is right. It says nothing about what is outside it,
and **a silent wrong answer looks like success**: `set of 0 .. 200` compiled
quietly and answered `no` where Pascal answers `yes`, because a set is a bit
per member in a `long` and the two-hundredth bit is not there.

[`languages/pascal/tests/refused/`](languages/pascal/tests/refused/) is the other half — programs that must fail,
each with a message naming the feature at a position in the Pascal. A program
there that starts *compiling* is as much a failure as one in `languages/pascal/tests/oracle/`
that starts disagreeing.

### The bugs it found

Four more after the first ten, of which one is the reason to be careful about
what an oracle proves:

| | |
| --- | --- |
| **an array not starting at 1 wrote outside itself** | `array [5..9]` had one subtracted instead of five, so it wrote indices 4–8 of a five-element array and `[-3..3]` wrote index −4. **The oracle agreed with it**, because the write and the read used the same wrong offset — the answers matched and the memory did not |
| set operators | `+ - *` on sets are union, difference and intersection, which on a bit per member are `\| &~ &` |
| a set range | `[2..6]` is a run of bits, and a member is one bit, and a set constructor cannot ask which it has — so a member has a node of its own now |
| an attribute shadowed by a field | `Subrange` has a field called `low`, so an attribute of that name was invisible from outside. The second time that has happened |

And six more, of which two agreed with fpc while being wrong, then six more
again:

| | |
| --- | --- |
| **comparing text compared pointers** | `'abc' < 'abd'` became `("abc" < "abd")`, which C leaves undefined — and which **agreed with fpc**, because the compiler had pooled the literals and laid them out in order. `strcmp` now |
| **reaching into a record lost the type** | `b.name` is a `char` and printed as `66`. The accessors were a *list*, so nothing could ask what `b.corners[2]` was before saying what `.x` is. They nest now, and each step asks the step below it |
| a set range double-shifted | `[2..6]` is a run of bits and a member is one bit; a set constructor could not ask which it had |
| Pascal's `mod`, widths, formats | as above |
| **an array passed by value was not copied** | Pascal copies it; a C array decays to a pointer, so the callee wrote the caller's memory. Arrays are wrapped in a struct now, which copies — and that took away the special case `var` arrays needed, because a struct does not decay |
| **a `for` limit was evaluated every time round** | Pascal evaluates it once, before the loop |

### And what a second oracle found

Thirty-five Pascal programs agree with `fpc` now, and five more that are
outside the subset are refused loudly rather than mistranslated.

`solas` and `solvm` do the same for Solveig, and the test is stronger: not
"does the output read correctly" but "does the compiled program print the same
thing". **Every Solveig program in that repository** compiles to bytecode that
prints what `solas`'s does, byte for byte, tracebacks included — the file and
the line a message points at are compared like any other byte, and nothing is
normalised or counted apart. It found two bugs in the front end and one in
Phoenix itself, and **none of the three was reachable by rendering the tree
back to source**:

| | |
| --- | --- |
| **`-2^2` was 4 and should be −4** | `^` binds tighter than a leading minus. `(-2)^2` and `-(2^2)` both write back out as themselves, so the round trip saw nothing; running it saw it at once |
| **`self` was slot 0 of the wrong frame** | it is slot 0 of *every* frame, not of the outermost block of a nest — a block installed on a class is a method, and its slot 0 is the receiver |
| **spreading a non-list was silent** | `[$e, ...$3]` where `$3` is the third *item* rather than the repetition built the first element twice and dropped the rest. The parse was wrong, the tree was wrong, and what was written back out was wrong *in the same way* — so it re-parsed to an identical tree and the round trip passed. `...` of a non-list is an error now, and that found the same miscount twice more **in Phoenix's own self-description** |

The last one is the sharpest argument in this repository for why an oracle is
not optional. Three tests agreed with each other for months because they all
asked the same wrong question.

## Where this sits

Every mechanism in Phoenix has prior art and the combination is what is
unusual. [docs/lineage.md](docs/lineage.md) places it against the metacompilers
it most resembles (TREE-META's unparse rules are a `%pass emit` in 1967), the
attribute-grammar systems it borrows from (JastAdd, Silver, Eli — whose LIDO
already had the threaded attribute, under the name CHAIN), the rewriting systems
that solved `%rewrite` already (Stratego), and the yacc family it is trying not
to be.

[docs/ROADMAP.md](docs/ROADMAP.md) says what is **not** built and why;
[docs/COMPLETED.md](docs/COMPLETED.md) is the other half — the tool, the
languages, the notation, and every roadmap entry that has left with a verdict,
including the one that was settled *against* building it.

| | |
| --- | --- |
| [manual.md](docs/manual.md) | the notation, explained in the order you would learn it |
| [reference.md](docs/reference.md) | every directive, clause form, operator and library function |
| [cheatsheet.md](docs/cheatsheet.md) | one page |
| [tutorial-picture.md](docs/tutorial-picture.md) | a language and a compiler, from nothing, in half an hour |
| [tutorial-assembler.md](docs/tutorial-assembler.md) | two passes, a thread, and a forward reference |
| [COMPLETED.md](docs/COMPLETED.md) | what exists, and what each piece cost against what it was predicted to cost |
| [ROADMAP.md](docs/ROADMAP.md) | what does not, and why |
| [journal.md](docs/journal.md) | the day-by-day, including every wrong turn |
| [postmortem.md](docs/postmortem.md) | the scoring — what was believed, and what the evidence said |
| [semantics.md](docs/semantics.md) | what the meta-language's own expressions mean, executably |
| [performance.md](docs/performance.md) | measured, three languages |
| [lineage.md](docs/lineage.md) | whose ideas these are |

## Evidence

**Three languages, and the third is the one that was not written for this.**
Pascal came with Wirth's grammar and Solveig with its own `solum.bnf`, both
vendored and read unmodified. There is no awk grammar on this machine, so
[`languages/awk/`](languages/awk/) is the POSIX definition transcribed — and
the check that it is *right* is not a grammar at all, it is six awk programs
that e2fsprogs, ncurses and vim ship, run under `/usr/bin/awk` before and after
this description rewrites them:

```
ok    28 awk programs parse, render, and parse to the same tree, 0 do not
ok    7 awk programs and 6 other people wrote do the same thing rendered, 0 do not
ok    13 awk programs and 6 other people wrote compile to C that prints what awk prints
```

The second line is the one that earns its place. The first was green while two
constructs were being written back out as programs awk rejects — `if (c) { a };
else { b }` and `do { a }; while (c)`, where a `;` after a block ends the
statement and orphans what follows. Both read back as the *same tree*, which is
exactly the failure a round trip cannot see.

The third is the one that says the most. `et_c.awk` is 269 lines of awk that
e2fsprogs uses to generate C error tables; compiled by
[`languages/awk/awk-c.phx`](languages/awk/awk-c.phx) it becomes 1,149 lines of
C and prints the same 56 lines that `/usr/bin/awk` does. **Nobody involved in
writing it had heard of this project.**

**And the fourth is a target rather than a language.**
[`languages/solvm/`](languages/solvm/) is an assembler for Solveig's `.sob`
bytecode: 21 mnemonics, labels, and blocks whose chunks nest. It is the
tutorial's two-pass shape at full size — a threaded byte counter for the
addresses, a gathered table for the labels — and the oracle is the same program
written twice, in Solveig for `solas` and in assembly for this, compared
*instruction by instruction* rather than only on what it prints:

```
ok    25 checks: the bytes, the round trip, the refusals, and solas
```

`count.sasm` is the loop and conditional whose disassembly is printed in
SolVM's own `docs/BYTECODE.md`, written back out by hand — and it assembles to
that listing exactly, `EXITIFF 17 -> 37` and `LOOP 30 -> 7` included.
**Phoenix can emit `.sob` and cannot read it**, which is a fact about the
notation rather than a gap: a length-prefixed format needs the match to depend
on a count it has just read, and there is no computed repetition to say that
with. So `solvm --dump` is the reading half, and comparing what it prints for
two producers of one program is what makes the check above possible.

The strongest available check that this reads real published grammars rather
than only its own examples: [`languages/pascal/tests/grammar/pascal.bnf`](languages/pascal/tests/grammar/) is
Wirth's Pascal in Wirth's notation, ~185 lines, together with files that
`fpc -Miso` accepts and files it rejects. Phoenix reads that grammar unmodified,
accepts both good programs and rejects all four bad ones, each with a line, a
column and a caret.

```
missing-semicolon.pas:13:3: error: expected else, ; or end, and found "n"
    n := n + 1;
    ^
```

[`languages/pascal/pascal.phx`](languages/pascal/pascal.phx) is that grammar with `->` clauses
added — 56 node types, an abstract tree with no punctuation in it, and a pass
that reads packed arrays, pointer types, records, sets and `var` parameters back
out:

```
$ bin/phx languages/pascal/pascal.phx languages/pascal/tests/grammar/features.pas
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
$ bin/phx --driver check languages/pascal/pascal.phx wrong.pas
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
already finished with. That is why it needed nothing — and when a language that
needs a *forward* reference was finally described, awk, two passes answered it
in twenty lines, so [reference attributes](docs/COMPLETED.md#21-reference-attributes--from-jastadd)
were settled against rather than built.

When a PEG fails at the top it has usually backtracked a long way from the real
mistake, so the position reported is the one the match got *furthest*, not the
one it stopped at.
