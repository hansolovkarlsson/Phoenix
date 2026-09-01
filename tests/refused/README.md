# Programs that must be refused

**Correct within a subset means two things**, and this directory is the second.
The first is that everything inside the subset gives Pascal's answer, which
[`../oracle/`](../oracle/) checks against `fpc -Miso`. The second is that
everything *outside* it is refused, with a message, rather than compiled into
something that runs and is wrong.

The second is the one that is easy to get wrong, because a silent wrong answer
looks like success. `set of 0 .. 200` compiled quietly and answered `no` where
Pascal answers `yes` — a set is a bit per member in a `long`, and the two
hundredth bit is not there. Nothing said so until a program was written that
asked.

| | |
| --- | --- |
| `nested-routine.pas` | C has no nested functions and this does not hoist them |
| `big-set.pas` | a set is a bit per member in a `long`, so 63 members is the most |
| `pointers.pas` | `^T`, `new` and `dispose` are not compiled |
| `files.pas` | `file of T` is not compiled |

Each has to fail with a message naming what is wrong, at a position in the
Pascal. A program here that starts *compiling* is as much a failure as one in
`../oracle/` that starts disagreeing.
