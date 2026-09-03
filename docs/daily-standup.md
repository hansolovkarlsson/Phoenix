# Standup — 2026-09-03

*Written at the end of the day, to be read at the start of the next one. It is
overwritten each time; the durable record is [journal.md](journal.md) and the
scoring is [postmortem.md](postmortem.md).*

**This day was closed out twice.** The first closeout was written at `3025bec`
and the work below it kept going for another hour, so this replaces it rather
than following it. [journal.md](journal.md) has two entries for today, which is
what that looks like in the durable record.

## Where the tree is

`main`, clean, **pushed** — `bd13341`. **189 tests, 0 failing**; 186 of them
need nothing outside the repository. Started the day at 176.

The website is live at
[hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
and the last build was checked *by fetching the pages*, not by reading the
workflow's green tick: `journal.html`, `postmortem.html` and `COMPLETED.html`
each serve today's new text.

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
| `3025bec` | the first closeout: the day, the scoring in `postmortem.md` § 6 |
| `82dc15e` | known warts: the count corrected, and the three this week found |
| `bd13341` | **symbolic slot operands** — `local total`, `outer 1, n`, and the depth check writing the message found |

## What is outstanding

Nothing is blocked, and nothing is half-finished. In the order I would pick
them up:

- [ ] **Read `SOL_SOB_VERSION` rather than writing 14** into two descriptions.
      `PRODUCING.md` asks for it; the trade was made deliberately (it would
      couple a description to a path outside this repository) and the suite
      checks the two agree. Worth revisiting only if the version moves.
- [ ] **ROADMAP 1.2** — compiling the tables to code. The only entry left, and
      it is a measurement that has come out the same way three times.

That is the whole list. The assembler owes nothing now: symbolic slot operands
were the last deferred piece, and they went in with two refusals and a static
check the feature had not asked for.

## Nothing is on fire, but two things to know

**`make test` is not safe to run twice concurrently.** Both runs share
`build/oracle/`, and racing them gave three spurious failures that cost a
confusing few minutes. Not worth fixing; worth remembering before backgrounding
one.

**The `day-closeout` skill would damage this repository, and this was checked
rather than assumed.** Running it again is not a small mistake:

- `_write_roadmap` opens `docs/roadmap.md`. This filesystem is
  case-insensitive, so `Path("docs/roadmap.md").exists()` is **True** and that
  file *is* `docs/ROADMAP.md`. It looks for a `## Immediate` heading, does not
  find one, and appends regex-scraped `- [ ]` lines to the end of it.
- `_write_postmortem` opens `docs/postmortem.md`, which exists here with a
  different meaning and does start with `# Postmortem` — so it appends
  `**Learnings**: [Add learnings here]` stubs to a 19K curated document.
- `_write_standup` overwrites this file outright.

All of it is recoverable from git, and none of it should have to be. The
closeout goes into the repository's own conventions instead: the day to
[journal.md](journal.md), the scoring to [postmortem.md](postmortem.md),
and [COMPLETED.md](COMPLETED.md) and [ROADMAP.md](ROADMAP.md) kept current as
the work lands. **Anyone running it again should do the same.**

## The one thing worth carrying forward

The morning's lesson was about running documentation — three tutorials had
eight defects between them and the reference had none, because a tutorial's
subject is a session and a reference's subject is a tool that has tests. That
still holds and is in [postmortem.md](postmortem.md) § 6.

The afternoon sharpened it into something smaller and stranger. Adding
symbolic slots, the first message written for `outer 3, x` was *no slot is
called `x` here*. That is true. It is also not the mistake — the chunk is
nested none deep and cannot reach out at all — and noticing that turned up a
gap older than the feature: `outer 5, 1`, numeric, had always assembled
cleanly.

> **A diagnosis that is true and is not the mistake is a bug in the
> diagnosis** — and chasing one is how you find the check nobody wrote.

Three times this week a page or a message has found a defect the code did not.
