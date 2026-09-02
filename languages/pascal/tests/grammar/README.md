# Pascal, as a test fixture

`pascal.bnf` is Wirth's Pascal in Wirth's own notation — the grammar from
*Pascal User Manual and Report*, rearranged only enough to be matched by ordered
choice. It is here because it is the strongest available evidence that Phoenix
reads a **real published grammar** and not only the examples written to suit it.

The six `.pas` files come with it and are the point of the exercise:

| | |
| --- | --- |
| `gcd.pas`, `features.pas` | accepted by `fpc -Miso`, and must be accepted here |
| `keyword.pas` | uses `end` as a variable — the reserved-word rule |
| `missing-semicolon.pas` | a statement separator left out |
| `unclosed.pas` | a `begin` with no `end` |
| `lexical.pas` | two characters no token rule matches, **on two lines** — both must be reported, because a scan that stops at the first tells you least about the file you know least about |

**These are copies, taken from the Solveig repository where they were written
for `programs/check_syntax.sol`, and they are copies on purpose.** Reading them
out of a sibling checkout made Phoenix's test suite fail whenever that
repository was reorganised, for reasons having nothing to do with Phoenix. A
fixture that is vendored is a fixture that cannot move.

They are not kept in step with the original, and they do not need to be: what
they test is that a grammar of this shape is read correctly, and that does not
change when their first home does.
