# Standup — 2026-09-03

*Written at the end of the day, to be read at the start of the next one. It is
overwritten each time; the durable record is [journal.md](journal.md) and the
scoring is [postmortem.md](postmortem.md).*

## Where the tree is

`main`, clean, pushed. **189 tests, 0 failing** — 186 of them need nothing
outside the repository. Started the day at 176.

The website is live at
[hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
and rebuilds itself on every push that touches `docs/` or `www/`.

## What went in

| | |
| --- | --- |
| `d12f2e3` | manual, reference, cheatsheet and two tutorials for Phoenix |
| `5562f70`+3 | the website: `www/`, the Pages workflow, Liquid fix, README links |
| `fbaa56a` | **an assembler for SolVM** — `languages/solvm/` |
| `2dfb27c` | its manual, reference and cheatsheet |
| `dcee755` | its tutorial, and a fix so a failed check complains once |
| `15929c3` | ran that tutorial: four defects, and it is executable now |
| `3ccc639` | ran the other two: three defects, plus two assembler checks |
| `fa0a2fd` | slot names, and a field shadowing a thread is now an error |
| `bc068a9` | slot names for the Solveig backend, and a `--trace` oracle |
| `ee5c993` | **roadmap 1.6** — `\|` as an expression operator, for awk's `getline` |
| `34bb73b` | **roadmap 2.3** — Pascal units, settled against |
| `5a873a5` | `docs/reference.md` § 11 made executable — 66 claims |

## What is outstanding

Nothing is blocked, and nothing is half-finished. In the order I would pick
them up:

- [ ] **`ROADMAP.md` § 5, known warts** — likely stale. Labels, slots and
      threads all changed this week, and two entries there describe behaviour
      that is no longer what happens. A read-through against what is now true.
- [ ] **Symbolic slot operands** in the assembler — `local total` rather than
      `local 1`. Deferred on purpose when slot names went in; the frame already
      knows the names, so it is small. It changes the assembly language rather
      than its metadata, which is why it was not folded in.
- [ ] **Read `SOL_SOB_VERSION` rather than writing 14** into two descriptions.
      `PRODUCING.md` asks for it; the trade was made deliberately (it would
      couple a description to a path outside this repository) and the suite
      checks the two agree. Worth revisiting only if the version moves.
- [ ] **ROADMAP 1.2** — compiling the tables to code. The only entry left, and
      it is a measurement that has come out the same way three times.

## Nothing is on fire, but two things to know

**`make test` is not safe to run twice concurrently.** Both runs share
`build/oracle/`, and racing them gave three spurious failures that cost a
confusing few minutes. Not worth fixing; worth remembering before backgrounding
one.

**The `day-closeout` skill would have damaged this repository.** Its
`_write_roadmap` targets `docs/roadmap.md`, and this filesystem is
case-insensitive — that *is* `docs/ROADMAP.md`. Its `_write_postmortem` targets
a file that already exists here with a different meaning. This closeout was
written into the repository's own conventions instead: the day went to
`journal.md`, the scoring to `postmortem.md` § 6, and `COMPLETED.md` and
`ROADMAP.md` were already current.

## The one thing worth carrying forward

Three tutorials and one reference section were made executable this week. The
tutorials had eight defects between them; the reference had none.

> **Run the documentation whose claims are not already held by something else.**

A tutorial's subject is a session — a sequence of commands in a directory —
so it goes stale when anything around it moves. A reference's subject is the
tool, and the tool has tests.
