# Phoenix for VS Code

Syntax colouring, bracket matching and comment toggling for `.phx`
descriptions.

## What is coloured

| | |
| --- | --- |
| comments | `(* … *)` and `;` to the end of the line, with `**bold**` and `` `code` `` inside a block comment shown as such |
| literals | `"…"` and `'…'`, their escapes, and the `{}` holes a message or template is filled through |
| directives | `%pass`, `%rewrite`, `%driver`, `%names` and the rest, and the name each one introduces |
| productions | the rule a line defines, `function = …` |
| passes | the attribute a clause defines, `: type = …`, `: down env = …`, `thread`, `otherwise`; `$name`, `$1`, `$$` and `.attr`; a check's `!` |
| nodes | a capitalised name, `Call(name: $n)`, and its fields; a grammar label, `n:name` |
| the library | `lookup`, `bind`, `size` and the other functions in [docs/cheatsheet.md](../../docs/cheatsheet.md), and `empty`, `true`, `false`, `nil` |

`Cmd+/` writes `(* … *)`, which is how every description here writes a
comment.

## Installing it

From a checkout, link this directory into VS Code's extensions and reload
the window (**Developer: Reload Window**):

```sh
ln -s "$PWD/editors/vscode" ~/.vscode/extensions/hansolovkarlsson.phoenix-0.1.0
```

A version of VS Code that keeps `~/.vscode/extensions/extensions.json` also
wants an entry there naming the directory, in the shape the others have.

## Checking it

```sh
make && python3 editors/vscode/test.py
```

The grammar is held against the notation's description of itself:
[`languages/phx/phoenix.phx`](../../languages/phx/phoenix.phx) says what a
`.phx` file's tokens are, and `phx` lexes every `.phx` file in the repository
with it. Every token must be outside a comment, every literal a string, and
every character coloured as code inside a token, so a comment the grammar
missed is found as well as one it invented. What a token stream cannot say,
which name is a production and which an attribute, is held by a list of lines
at the end of `test.py`.

It is not part of `make test`, which needs nothing outside this repository,
and this needs `python3`.
