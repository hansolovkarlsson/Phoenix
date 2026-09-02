# Languages

**One directory per language described.** Each holds the descriptions, the
programs written in it, and the tests that keep it honest — so a second
language arrives *beside* the first rather than mixed into it.

| | |
| --- | --- |
| [`pascal/`](pascal/) | ISO 7185 Pascal: a grammar, a typechecker, a compiler to C, and an outline tool. The one that is taken seriously — 24 programs checked against `fpc -Miso` |
| [`calc/`](calc/) | the smallest language worth having a compiler for. What the stages were built against, and still the fastest thing to try a change on |
| [`solveig/`](solveig/) | [Solveig](https://github.com/hansolovkarlsson/Solveig): a conformance suite written before anything aimed at it, and a description that parses every `.sol` file there is and writes each one back to the same tree |
| [`phx/`](phx/) | the `.phx` notation described in itself. It parses itself and every other description here |

## What goes where

```
pascal/
  pascal.phx            the language: grammar, tree, symbols, typecheck
  pascal-c.phx          a target: %import the language, add an emit pass
  pascal-outline.phx    another target
  programs/             programs written in the language, with expected output
  tests/
    grammar/            the published grammar and files that must parse or not
    oracle/             programs compiled twice and compared against fpc
    refused/            programs that must fail, with a message
```

**The split inside a language is the one `%import` makes**: everything upstream
of emitting belongs to the language and has no opinion about a target, so
`pascal.phx` is imported by both `pascal-c.phx` and `pascal-outline.phx` and
knows about neither.

## What is not here

[`../lib/`](../lib/) holds modules any description may import — the lexical
rules every language wants, and infix expressions with a hole where its atoms
go. A module earns a place there by being wanted twice; `pascal.phx` uses
neither, and [the journal](../docs/journal.md) says why that was worth
finding out.

[`../tests/`](../tests/) tests Phoenix rather than any language: the notation,
the checks it makes about a description, and the machinery underneath.
