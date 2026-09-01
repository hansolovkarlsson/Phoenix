# Stage 3, sketched

*A proposal. Nothing here is built yet. Stage 2's sketch was wrong about one
thing in a way that only building it revealed, which is the point of writing
one.*

---

## The shape

```
%driver c    = typecheck, emit-c -> out .
%driver run  = typecheck, eval   -> out .
%driver check = typecheck .
```

A driver names passes in order and, optionally, which attribute of the root is
the answer. A driver with no `->` is a validation run: nothing is printed and
the exit status is the whole of what it says.

Drivers live in the file that has the passes to order — which is the *target*
file, since that is where an emit pass is. `calc-c.phx` declares `c` and `run`;
`calc.phx`, which knows nothing about any target, declares none.

**On the command line:**

```sh
phx calc-c.phx prog.calc                 # the first driver declared
phx calc-c.phx prog.calc --driver run    # by name
phx --drivers calc-c.phx                 # what there is to choose from
```

The first driver declared is the default, for the same reason the first
syntactic rule is the default `%start`: one rule about defaults rather than two.
`--run PASS --show ATTR` stays, for looking at one pass in isolation.

---

## What running one means

**Each pass is a complete walk**, in the order written. Attributes stay on the
nodes between passes, which is what makes a sequence worth having: `typecheck`
leaves `type` behind and `emit-c` can read it, without either knowing the other
exists.

**A pass that reports an error stops the ones after it.** Not because the
sequence could not continue, but because it should not: a later pass reading
attributes that a failed pass left poisoned produces consequences of the first
mistake rather than new information. This is *checks are guards* from stage 2,
one level up — and it is the same argument, so it gets the same answer.

---

## The check that makes a driver worth declaring

**A driver is a claim about order, and a claim about order can be wrong.** If
`emit-c` reads `$left.type` and the driver forgot `typecheck`, today that is a
runtime message about a missing attribute, arriving from inside a pass, naming
neither the driver nor the pass that would have supplied it.

It is decidable when the description is read. For each pass:

- what it **defines** — the attribute names on the left of its clauses
- what it **reads** — the `.name` in every `$x.name` it mentions

Then for a driver `p1, p2, p3`, everything `pi` reads must be defined by `pi`
itself or by some `pj` before it. Otherwise:

```
calc-c.phx:12:3: error: driver 'c' runs 'emit-c', which reads '.type',
                        and nothing before it defines one
phx: 'typecheck' defines 'type' -- did the driver mean to run it first?
```

**That message is the reason to have `%driver` at all**, as against just running
passes in the order you happen to type them. The ordering is the thing a
sequence-of-passes compiler gets wrong, and it is the thing a tool that knows
about passes can check.

---

## What it deliberately does not do

**No conditional passes.** A driver is a list, not a program. If which passes
run depends on something, that is two drivers.

**No repeating a pass until nothing changes.** Fixpoint belongs to the
`%rewrite` [strategies](ROADMAP.md#22-strategies--from-stratego) — `innermost`
already means *until nothing changes* — and putting a second, weaker version of
it in the driver would be inventing a word for something that already has one.

**No passes over part of a tree.** A pass walks the whole thing. Restricting one
to a subtree is what a pattern in the clause already does.

---

## Open, and worth deciding before building

**Two passes in one driver defining the same attribute.** `eval` and `emit-c`
both define `out`, which is fine because no driver runs both — but nothing stops
one. The later would silently win. *Proposal: a warning, not an error*, since
refining an earlier pass's attribute is a legitimate thing to want and this is
only a hazard when it was not meant.

**Whether a failing pass should stop the run or the driver.** Proposed above:
stop. The alternative — run every pass to gather more errors — sounds friendlier
and produces the cascade stage 2 spent an afternoon removing.

**What `--show` means once drivers exist.** Proposal: it stays, and overrides
the driver's `->`. It is a debugging flag and debugging wants to see attributes
the driver does not print.
