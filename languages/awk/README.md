# awk

The third language described here, and the first whose grammar is **not
vendored**.

`languages/pascal/` holds Wirth's report grammar and `languages/solveig/` holds
that project's `solum.bnf`, both character for character, so that a claim about
reading the published grammar can be checked. There is no awk grammar on this
machine. [`awk.phx`](awk.phx) is the POSIX definition **transcribed** into
Wirth's notation, and saying so is the honest version of the difference.

What carries the weight instead is the oracle. `/usr/bin/awk` decides what awk
means, and [`tests/corpus/`](tests/corpus/) is six awk programs written by other
people for reasons of their own — e2fsprogs, ncurses and vim ship them.

## Why awk

Pascal has statements, expressions and a type system, and fifty-one node types.
Solveig has one thing that happens — a message is sent — and twelve. awk has
neither shape, and forty-six:

- a program is a list of **pattern–action rules**, run over every line of input,
  with no main and no entry point;
- **nothing is declared.** A variable exists because it was mentioned, its type
  is whatever it last held, and an array springs into being on first subscript;
- **concatenation has no operator.** Two things beside each other are joined,
  which is why awk's grammar is not LL(1) and why `concat` here is a repetition
  of the rung below it;
- a function may be **called above where it is defined**, which is the forward
  reference [ROADMAP 2.1](../../docs/ROADMAP.md) has been waiting for a
  language to need.

## What is here

```
awk.phx                 the grammar, the tree, and a `show` pass
tests/
  corpus/               awk other people wrote: e2fsprogs, ncurses, vim
  conformance/          programs and the output each must produce under awk
  divergent/            two programs this reads differently from awk, on purpose
  outside/              gawk, kept for the round trip and nothing else
  roundtrip.sh          parse, render, parse, and compare the trees
  oracle.sh             run both under awk and compare what they print
```

## The one place it guesses, and it is awk's fault

**`/` is division and `/re/` is a regular expression, and which one it is
depends on the parser.** A real awk lexer asks whether the previous token could
end an expression. Phoenix's scanner is longest match over the token rules and
has no such feedback — deliberately, and
[ROADMAP 3.3](../../docs/ROADMAP.md) says why: a tool that guesses the
lexical/syntactic seam reports a correct file as broken, which is the worst
thing it could do.

So the *description* guesses instead, which is its business rather than the
tool's: `ere` requires the character after the `/` to be neither a space, a tab
nor an `=`, and requires the closing `/` on the same line. That reads every
regexp in the corpus and every division in it, because nobody writes `a/b/c`
without spaces.

**It has a shape it gets wrong**, and that shape is checked in:
[`tests/divergent/slash.awk`](tests/divergent/slash.awk) is `a/b/c`, which this
reads as `a` concatenated with the regexp `/b/` concatenated with `c`.
Rendering it puts the spaces in, so the divergence is visible rather than
silent — which is the most that can be done about a guess.

The second divergence is next to it. `f (1)` with a space is **not a call** in
awk: POSIX makes `FUNC_NAME` a name *immediately* followed by `(`. Saying that
here means putting the `(` inside the token, and then `if(`, `while(` and
`print(` become function names too. So this reads a call, and
[`spaced-call.awk`](tests/divergent/spaced-call.awk) says so.

## How it is checked

**Round trip.** Every program here is parsed, written back out and parsed
again; the two trees must be identical. It is a round trip of *structure* and
not of source — comments are gone, statements come out separated by `;` — and
it works because a parenthesis is a `Group` node, so no bracket comes back that
was not written.

**The oracle**, which is the one that matters. A round trip can be green while
the parse is consistently wrong: what is written back out is wrong in the same
way, so it re-parses to the same tree, and
[the journal](../../docs/journal.md) has that mistake twice. So each program is
*run* under `awk`, before and after rendering, and must print the same thing.

It found two bugs the round trip could not, and both are about a **terminator**
rather than a tree:

| | |
| --- | --- |
| `if (c) { a }; else { b }` | a `;` after a block ends the `if`, leaving the `else` orphaned — and is *required* when the branch is not a block. Two clauses now, chosen by the shape of the branch |
| `do { a }; while (c)` | the same thing again, and found the same way |

Each read back as the same tree and neither is awk.

## The call check, and what it says about the roadmap

**awk resolves a call by name over the whole program**, so a function may be
used above where it is defined. That is the forward reference
[ROADMAP 2.1](../../docs/ROADMAP.md) has been waiting for a language to need,
and it is **two passes**:

```
%pass functions
  thread known = []
  Function : known = [...$known, [$name, size($params)]] .
  Program  : table = $known .

%pass calls
  Program : down declared = $table .
  Apply ! not defined($declared, $name) : "'{}' is not a function ..." of $name
```

One walk collects the functions and leaves the table on the root — a leaving
clause runs after the whole subtree, so every function is in it wherever it was
written. The next hands it back down. Attributes stay on the nodes between
passes, which is what makes a sequence of them worth having.

It finds while *reading* the program what awk finds when the call *runs*, and
it flags [`outside/hello.awk`](tests/outside/hello.awk) for calling a gawk
builtin that POSIX awk has not got.

So the entry that was waiting for this language got its answer, and the answer
is no: what reference attributes would have bought is one walk instead of two.

## The backend

[`awk-c.phx`](awk-c.phx) compiles awk to C. It is **the first target here where
a value is not a machine word**: `pascal-c.phx` emits four `#include`s and lets
C's types do the work, and `solveig-sob.phx` emits opcodes for a machine that
already knows what a value is. awk has one type and it is not C's, so a
compiled awk program carries a runtime — 682 lines of it, in
[`awk-runtime.c`](awk-runtime.c), which the description `%embed`s.

That file is **compiled by `make test` on its own**, which is the point of it
being a file: it was written and checked against awk before anything embedded
it, and for two stages the artefact that had been tested was not the artefact
in the repository.

```
typedef struct { char *s; double n; int isnum, strnum; Map *map; } Cell;
```

A string and a number at once, which is the whole of awk's type system.
`isnum` says the number is the one to use; `strnum` says the string came from
input and looked like a number, so a comparison treats it as one. That is what
makes `$1 == 10` true for a field of ` 10 ` and `x == 0` *and* `x == ""` both
true for a variable never set.

The `map` is the other half: **a variable becomes an array by being
subscripted**, which is why the map hangs off a value rather than being a kind
of its own. It is also what makes an array passed to a function by reference
and a scalar by value, which awk decides by what the callee does — so a
variable handed to a function has its map made first, whichever way it turns
out to be used.

```
ok    13 awk programs and 6 other people wrote compile to C that prints what awk prints
```

**The six are the corpus** — awk that e2fsprogs, ncurses and vim ship, compiled
to C, built by `cc`, and run against `/usr/bin/awk` on the same input with the
same arguments. `et_c.awk` is 269 lines of awk that generates C error tables;
it becomes 1,149 lines of C and prints the same 56 lines either way.

### What it compiles

Values, fields, the main loop, `print` and `printf`, arithmetic, comparison,
concatenation, control flow, **arrays** with `in`, `delete` and `for`-in,
**functions** with locals, recursion, forward calls and arrays by reference,
**regular expressions** — patterns, `~`, `!~`, `match`, `sub`, `gsub`, `split`,
and a multi-character `FS` — over POSIX `<regex.h>`, **output** to a file, an
appended file or a pipe with `close`, **range patterns**, and the input awk
takes: the files named on the command line, `FILENAME`, `FNR`, and
`name=value` operands including `-v`.

**What is left is `getline`**, and it is the only thing here whose *grammar* is
the problem rather than its runtime. Four of its six forms are described;
`cmd | getline` is the other two and needs `|` to be an expression operator,
which it is not. Both are in [`tests/not-yet/`](tests/not-yet/) and
[`tests/divergent/`](tests/divergent/), and both are refused with a position.

**It is described even though nothing compiles it**, and that is the
interesting part: `getline` is not a keyword unless some rule says so, and
without one `getline line` reads as *two variables concatenated* — a silent
mis-parse of ordinary awk. Mentioning the word is what makes it reserved.

### Two things the backend taught the front end

Writing it found two bugs in `awk.phx` that reading 800 lines of other people's
awk had not:

| | |
| --- | --- |
| `for (;;)` would not parse | the rule for "any number of newlines or semicolons between two things" was being used inside a `for` header, where the semicolons belong to the header. POSIX writes `newline_opt` there and this now has a separate `nl` for exactly that |
| `For` shadowed its own fields | the emit pass named attributes `init`, `cond` and `step`, which are the node's *fields* — so nothing outside the pass could have seen them. Phoenix's own check said so, and said it again about `Regex.text` |
| an array's name was **text** | `Index(array: "a", ...)` meant the pass that collects the program's variables never saw it, because it only looks at `Var` nodes. An array name is a variable and now builds one, which is the same lesson as `Nothing` below: fix the tree, not the pass |
| a regexp beginning with a space | `split($0, parts, / +/)` is ordinary awk and the guess above will not read it. Found by writing a conformance program rather than by thinking about it, and checked in beside the other two |

**A backend is the test a front end cannot be given any other way**, which is
the argument for building one at all.

### And one thing it taught the notation

`lookup` is a function, so **both answers are worked out** before it chooses —
which is fine until one of them cannot be. An omitted `for` part was a nil, and
`"{};" of $init.out` on a nil is an error however the condition comes out.

The fix was in the *grammar*, not the pass: an omitted part now builds a
`Nothing` node that renders as nothing, so every part is emitted the same way
whether it is there or not and the question disappears. See
[ROADMAP 3.5](../../docs/ROADMAP.md).

**And `otherwise` carried three questions this backend could not otherwise
ask**, all of them "what is this node, when it is used *here*":

| | |
| --- | --- |
| `stmt` | an expression used as a statement wants a `;`. The tree cannot say which `x = 1` is, so every node answers both and nine statement kinds override |
| `argout` | a variable handed to a function has its array made first; anything else is passed as it stands |
| `reout` | a regexp is a match against the record on its own and a *pattern* when handed to `sub` or `split`. `Match` can ask with a clause pattern because the regexp is a field of it; an argument is in a list, so the argument answers instead |

Each is one line plus the nodes that differ. Without them each would have been
the same clause written once per node type.

## What it does not do

**Compile all of awk.** This is stage one: a grammar, a tree, a check, a way to
write it back out, and a compiler for the part of the language that does not
need a hash table or a regular expression engine. `languages/solveig/` was built the same way round, and the reason is
that a backend for a language whose parse is wrong is a backend written twice.

**`getline`**, which is refused rather than mis-read: it is the one construct
in awk whose grammar depends on where it appears, and it appears nowhere in the
corpus.
