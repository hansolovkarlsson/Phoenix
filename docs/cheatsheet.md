# Phoenix cheatsheet

*One page. [manual.md](manual.md) explains, [reference.md](reference.md) is
exhaustive, [tutorial-picture.md](tutorial-picture.md) starts from nothing.*

## Command line

```sh
phx desc.phx                  read the description, check it, print it back
phx desc.phx prog.src         run the default driver over prog.src
phx desc.phx prog.src --driver run     a driver by name
phx desc.phx -o desc.c        write the description out as a C program
```

| | |
| --- | --- |
| `--tree` | the tree, whatever drivers exist |
| `--tokens` | the token stream, and stop |
| `--nodes` | the node types the grammar builds, and their fields |
| `--drivers` | what there is to choose from |
| `--imports` | the files the description was assembled from |
| `--grammar` | the grammar as it was understood |
| `--run PASS` | run one `%pass` on its own |
| `--show ATTR` | print this attribute of the root instead of the driver's |
| `--raw` | write the answer with no trailing newline (binary targets) |
| `--stats` | how much work reading the source took |
| `--quiet` | say nothing on success; the exit status is the answer |
| `-I DIR` | where to look for a file the *source* includes. Repeatable |
| `--no-includes` | do not follow `%include`; leave the include nodes in |

Exit status: `0` fine, `1` the description or the program was refused, `2` the
command line was.

## The shape of a file

```ebnf
(* a comment *)
%import "lexical.phx" .          (* modules, merged into one grammar *)

%tokens .                        (* the default; characters to tokens *)
%fragment letter digit .         (* helpers, never tokens on their own *)
%skip space comment .            (* produced, then thrown away *)
%ignorecase .                    (* letters compare without regard to case *)

%syntax .                        (* from here, matched over tokens *)
%start program .                 (* the goal rule; the first if unsaid *)

%pass name       ... clauses ...
%rewrite name strategy  ... rules ...
%driver name = pass, pass -> attr .
```

## Grammar

| | |
| --- | --- |
| `a = b c .` | a production; `=`, `:=` and `::=` all define, `.` optional |
| `a \| b` | ordered choice — `b` is tried only if `a` failed |
| `[ a ]` | optional. Its value is a **list**: empty, or what it matched |
| `{ a }` | repetition. Its value is a **list**, flattening every iteration |
| `( a )` | grouping |
| `"lit"` | a literal |
| `"a" .. "z"` | a character range — **lexical only** |
| `! a` | one character, provided `a` does not match here — **lexical only** |
| `l:factor` | a label, read back as `$l` |

Escapes inside a literal: `\" \\ \n \t \r \0 \' \xHH`.

## Actions

```ebnf
statement = "print" e:expression ";"   -> Print(value: $e)
          | "(" expression ")"         -> $2 .
expression = term { "+" term -> Binary(op: $1, left: $$, right: $2) } .
```

| | |
| --- | --- |
| `$1` | the n'th factor, from one, **counting everything** including literals |
| `$name` | a labelled factor |
| `$$` | what has been built so far — mentioning it makes the action a left fold |
| `$pos` | where this node came from: `Position(line, column, file, endline, endcolumn)` |

No `->` at all: **a body that produced one value answers that value; any other
number answers a node named after the rule**, holding them.

## Passes

```
%pass typecheck
  thread env = empty                   (* declared before it is updated *)
  otherwise type = "void"              (* what a node with no clause answers *)

  Variable : type = lookup($env, $name)
           ! not defined($env, $name) : "'{}' is not defined" of $name .

  Let      : env  = bind($env, $name, $value.type)
           : type = "void" .

  Block    : down indent = "{}    " of $indent .
```

| | |
| --- | --- |
| `: attr = e` | **synthesised** — leaving, after the children |
| `: down attr = e` | **inherited** — entering, before the children, visible below |
| `: attr = e` where `attr` is threaded | **threaded** — leaving, and it flows on |
| `! cond : message` | a check. It runs **before** the attributes it guards |
| `otherwise attr = e` | for every node whose own rule answers nothing for `attr` |
| `thread attr = e` | declares a thread and its starting value |
| `down` on a threaded attribute | sets the thread for the subtree — this is how a thread nests |

`$child.attr` reads a child's attribute; over a list it means *that of each*.
A node's **field** is read before an attribute of the same name.

## Rewrites

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(text: a), right: Number(text: b))
    => Number(text: text(int($a) + int($b))) .
```

`bottomup` children first · `topdown` this node first · `innermost` bottom-up,
again until nothing matches. A rewrite sees its bindings, the matched node's
fields and `$pos` — never an attribute.

## Patterns

| | |
| --- | --- |
| `Binary` | a node of that type |
| `Binary(op: "+", left: a)` | a field written with a value tests it, with a name binds it, left out is not looked at |
| `[a, b]`, `[]` | a list of **exactly** that many |
| `"text"`, `45`, `true`, `nil` | that value |
| `name` | anything, bound to that name |
| `_` | anything |

First match wins. A general pattern above a specific one is refused.

## Expressions

Precedence, tightest first:

```
f(x)  $a.b          call, attribute
not  -              unary
*  /  div  mod
+  -
=  <>  <  >  <=  >=
and                 short-circuits
or                  short-circuits
of                  formatting, loosest
```

Six kinds of value: **integer** (64-bit, traps on overflow), **float**
(IEEE 754), **text** (bytes, one-based, both ends inclusive), **boolean**,
**nil**, **node** and **list**. `1 + 1.0` is an error — nothing converts
implicitly. `div` and `mod` are **floored**; `quotient` and `remainder`
truncate. `=` and `<>` compare structurally across any two values; `< > <= >=`
only within a kind.

`"a {} b {}" of x, y` fills the holes left to right. `{{` and `}}` are literal
braces. A nil, a node or a list has no written form.

## The library

| | |
| --- | --- |
| `empty` | the empty environment (a bare lower-case name is a call with no arguments) |
| `bind(env, name, value)` | a new environment. `name` may be a list of names |
| `lookup(env, name)`, `lookup(env, name, default)` | `nil` when absent, or the default |
| `defined(env, name)` | a boolean |
| `positions(list)` | `[value, index]` pairs — **zero-based**, first occurrence wins |
| `int(t)`, `int(t, base)`, `float(x)`, `text(x)` | conversions |
| `floor(f)`, `ceiling(f)`, `round(f)`, `truncate(f)` | float to integer, named |
| `quotient(a, b)`, `remainder(a, b)` | division that **truncates**, as C does |
| `size(x)` | bytes of text, elements of a list, fields of a node |
| `sizes(list)` | the same for each element |
| `at(list, i)` | one-based |
| `slice(t, from, to)` | one-based, both ends included |
| `split(t, sep)` | a list of text |
| `join(list)`, `join(list, between)` | text |
| `flatten(list)` | one level |
| `each(list, template)`, `each(a, b, template)` | the template's `{}` is the element; two lists run in step, to the **longer** |
| `bytes(n, width)` | 1–8 bytes, little-endian. A list of numbers gives a list of encodings |

## Directives

`%tokens` `%syntax` `%fragment` `%skip` `%start` `%ignorecase` `%import`
`%embed` `%require` `%include` `%pass` `%rewrite` `%driver`

```
%import "expression.phx" .       beside this file, then in lib/
%embed  runtime "rt.c" .         the file's bytes, under a name
%require primary .               a hole this module leaves open
%include Include path .          which node is an include, and which field is the file
%driver c = show, typecheck, emit-c -> out .
```

A driver with no `->` is a validation run: the exit status is all it says.
