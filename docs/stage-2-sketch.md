# Stage 2, sketched

*A proposal, not a decision. Nothing here is built. The point is to have
something concrete enough to be wrong about before it costs anything.*

Stage 1 left a vocabulary — `Binary(op, left, right)`, `Let(name, value)` — and
nothing that reads it. Stage 2 is `%pass`: clauses keyed on that vocabulary,
computing attributes over the tree.

---

## The two open questions, answered

### 1. Clauses match on shape, not only on type

Keying on the type alone forces a conditional back into every interesting
clause:

```
Binary : val = if $op = "+" then $left.val + $right.val
               else if $op = "-" then $left.val - $right.val
               else ...
```

Keying on shape makes the same thing a definition:

```
Binary(op: "+") : val = $left.val + $right.val .
Binary(op: "-") : val = $left.val - $right.val .
```

Clauses are tried **in order, first match wins** — the same dispatch discipline
as the PEG in the syntactic half, so the tool has one rule about ordering
rather than two.

A pattern binds as well as tests: `Number(value: n)` matches a `Number` and
binds `n` to its field.

**This is also most of the `%rewrite` mechanism that was deferred.** Once
patterns match on shape and bind, constant folding is the matcher already built
plus a way to say what replaces the match:

```
%rewrite fold bottomup
  Binary(op: "+", left: Number(value: a), right: Number(value: b))
    => Number(value: a + b) .
```

That is worth knowing now: the deferred second mechanism is cheaper than it
looked, because this stage pays for its expensive half.

### 2. The expression language is small, and infix

Solveig has no operators, and that is the right call *there* — one kind of
thing, one thing that happens to it. Phoenix is not Solveig and a compiler
description is read far more often than it is written, so:

| | |
| --- | --- |
| `+ - * /` `%` | arithmetic |
| `= <> < > <= >=` | comparison |
| `and or not` | logic, short-circuit |
| `f(a, b)` | a call — the whole standard library is functions |
| `$field` | a field of the node being matched |
| `$child.attr` | an attribute of a child |
| `"text {} {}" of a, b` | formatting — one construct instead of N concatenations |
| `[a, b]` `...a` | lists and spread, as stage 1 already has |
| `Type(f: v)` | building a node, as stage 1 already has |

`of` is deliberate. An emit pass is almost entirely templates with holes, and
`"@expr({} {} {})" of $left.out, $op, $right.out` is one line where
concatenation is four. Solveig spells the same idea `:fill([...])`.

**No `if`.** Shape matching covers what conditionals were for, and leaving it
out keeps the notation declarative. If a clause genuinely needs a choice, that
is evidence for another clause.

---

## Three kinds of attribute, and what each one pays for

This is the part that decides whether the design survives contact with a real
compiler.

| Written | Flows | Pays for |
| --- | --- | --- |
| `attr = expr` | **up**, from children | types, generated code, computed values |
| `down attr = expr` | **down**, to children | scope depth, target register, whether we are inside a loop |
| `thread attr` | **along**, in document order | symbol tables, label counters, forward declarations |

The first two are Knuth's synthesized and inherited attributes. **The third is
the one that matters**, and it is the answer to the weakness recorded in the
journal at the start of this project.

A threaded attribute enters a node, may be changed by it, and leaves to the
*next node in document order* — not to its children, and not to its parent. It
is the shape of a fold over the whole tree.

That single construct covers all three things attribute grammars were said to
be bad at:

- **forward declarations** — a symbol table threaded through a list of
  declarations, each one adding to what the next one sees
- **label counters** — `next = $next + 1`, which is what an assembly backend
  needs and what makes a flat target reachable at all
- **register allocation** — the same shape again

So the `%rewrite` mechanism is not the escape hatch. `thread` is, and it is
three lines of notation rather than a second language.

---

## The calculator, whole

The vocabulary from stage 1, with `Number`'s field renamed `text` so that the
example does not have to explain a collision:

```
Program(body)   Print(value)   Let(name, value)
Binary(op, left, right)   Number(text)   Variable(name)
```

### A pass that checks

```
%pass resolve
  thread env

  Program  : env = empty .
  Let      : env = bind($env, $name) .
  Variable : error("'{}' is not defined" of $name)
               when not defined($env, $name) .
```

Three lines and a declaration. The hand-written version is a visitor class, an
environment type, and a traversal.

### A pass that computes — the interpreter

```
%pass eval
  Number          : val = number($text) .
  Variable        : val = lookup($env, $name) .
  Binary(op: "+") : val = $left.val + $right.val .
  Binary(op: "-") : val = $left.val - $right.val .
  Binary(op: "*") : val = $left.val * $right.val .
  Binary(op: "/") : error("division by zero") when $right.val = 0 .
                  : val = $left.val / $right.val .
  Print           : out = "{}\n" of $value.val .
  Program         : out = join($body.out) .
```

`phx --run prog.calc` prints the root's `out`. **This is the whole of
"interpreted evaluator language"** — the language runs without a line of code
being generated, which is what makes a target language cheap to iterate on.

### A pass that emits — two of them, from one description

```
%pass emit-sol
  Number          : out = "#{}" of $text .
  Variable        : out = "{}" of $name .
  Binary          : out = "@expr({} {} {})" of $left.out, $op, $right.out .
  Let             : out = "{} := {}." of $name, $value.out .
  Print           : out = "{}:print." of $value.out .
  Program         : out = join($body.out) .

%pass emit-c
  Number          : out = "{}" of $text .
  Variable        : out = "{}" of $name .
  Binary          : out = "({} {} {})" of $left.out, $op, $right.out .
  Let             : out = "long {} = {};" of $name, $value.out .
  Print           : out = "printf(\"%ld\\n\", {});" of $value.out .
  Program         : out = "int main(void){{\n{}\nreturn 0;}}" of join($body.out) .
```

**Nothing in either pass knows what Phoenix's own output language is.** That is
the property that has to be true, and writing both now is how it stays true.

### The driver

```
%driver
  parse, resolve, eval        -> run
  parse, resolve, emit-sol    -> sol
  parse, resolve, emit-c      -> c
```

`phx calc.phx prog.calc --to c` picks one. A pass that reports errors stops the
ones after it.

---

## How it would actually run

**Threaded attributes force a traversal**; synthesized and inherited ones do
not. So a pass is one walk in document order, threading what is threaded, and
demanding the rest lazily as clauses ask for them.

**Attributes are demand-driven and memoised** — evaluated when first asked for,
remembered on the node. This is JastAdd's approach and it removes the static
scheduling problem entirely: no dependency analysis, no ordering declarations.
The cost is that a circular definition is caught when it runs rather than when
it is read, so an attribute already being evaluated when it is asked for again
is an error naming the cycle.

**Checks have to be forced.** A diagnostic nothing depends on would never be
demanded, so the walk evaluates every `error ... when ...` clause at every node
it matches. That is the difference between a check and an attribute, and it is
the only place the two behave differently.

---

## What this does not answer

**Passes that are not tree walks.** Left-recursion detection is a Warshall
closure over a rule graph; dataflow analysis, call graphs and alias analysis are
the same shape. `thread` handles a fold in document order and nothing wider.
Whether `%pass` needs an escape hatch to arbitrary computation is still open,
and attempting to describe Phoenix in Phoenix is what would settle it.

**Where the standard library stops.** `bind`, `lookup`, `defined`, `join`,
`number` are functions the sketch assumes. Every one is a decision, and a
compiler generator whose library keeps growing has failed at something.
