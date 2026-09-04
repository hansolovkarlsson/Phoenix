# Standup — 2026-09-03

*Written at the end of the day, to be read at the start of the next one. It is
overwritten each time; the durable record is [journal.md](journal.md) and the
scoring is [postmortem.md](postmortem.md).*

**This day was closed out three times.** The first was `3025bec` and the work
kept going after each. That is not a problem to fix — it is what the file being
overwritten is for — but it means [journal.md](journal.md) carries three
entries dated today, and they are the record. This page is only the way in.

## Where the tree is

`main`, clean, **pushed** — `ccd8cb1`. **189 tests, 0 failing**; 186 of them
need nothing outside the repository. Started the day at 176.

The website is live at
[hansolovkarlsson.github.io/Phoenix](https://hansolovkarlsson.github.io/Phoenix/)
and the last deploy was checked *by fetching the pages*, not by reading the
workflow's green tick.

## What went in

| | |
| --- | --- |
| `d12f2e3` | manual, reference, cheatsheet and two tutorials for Phoenix |
| `5562f70`+3 | the website: `www/`, the Pages workflow, Liquid fix, README links |
| `fbaa56a` | **an assembler for SolVM** — `languages/solvm/` |
| `2dfb27c`+2 | its manual, reference, cheatsheet and tutorial, and a fix so a failed check complains once |
| `15929c3`, `3ccc639` | ran all three tutorials: seven defects, and they are executable now |
| `fa0a2fd`, `bc068a9` | slot names, in the assembler and the Solveig backend |
| `ee5c993` | **roadmap 1.6** — `\|` as an expression operator, for awk's `getline` |
| `34bb73b` | **roadmap 2.3** — Pascal units, settled against |
| `5a873a5` | `docs/reference.md` § 11 made executable — 66 claims |
| `3025bec`, `82dc15e` | the first closeout, and the known warts corrected |
| `bd13341` | **symbolic slot operands** — `local total`, `outer 1, n` |
| `b98d255` | the second closeout, and a day I had mis-dated |
| `1db93b8` | **`outer 0` is not a roundabout `local`**, and the manual said it was |
| `28f0045` | the slot bound moved to the language, and a cousin found unreachable |
| `6e2cd0d` | the third closeout: the verifier audit, and the day's scoring |
| `f28203c` | the `day-closeout` skill removed; the closeout said in a line |
| `4509fc1` | **[CHANGELOG.md](CHANGELOG.md)** — the one page that says *when* |
| `00a963f` | `COMPLETED.md`'s stage table corrected, and the plan told from the delivery |
| `ccd8cb1` | the changelog corrected an hour after publishing it |

## What is outstanding

Two, and neither is in the assembler.

- [ ] **Read `SOL_SOB_VERSION` rather than writing 14** into two descriptions.
      `PRODUCING.md` asks for it; the trade was made deliberately (it would
      couple a description to a path outside this repository) and the suite
      checks the two agree. Worth revisiting only if the version moves.
- [ ] **ROADMAP 1.2** — compiling the tables to code. The only entry left, and
      it is a measurement that has come out the same way three times.

**The assembler owes nothing, and this is now a checkable claim rather than an
impression.** `verify_chunk` in `solum/src/serialize.c` has eleven rules: four
hold by construction, six are checked here, and one is `verify_stack_heights`,
which is a dataflow analysis and out of reach of a walk over a tree.
[`languages/solvm/README.md`](../languages/solvm/README.md) carries the table,
so the next person can re-check it in a minute.

## Nothing is on fire, but two things to know

**`make test` is not safe to run twice concurrently.** Both runs share
`build/oracle/`, and racing them gave three spurious failures. Not worth
fixing; worth remembering before backgrounding one.

**The closeout is written by hand**, into this repository's own conventions:
the day to [journal.md](journal.md), the scoring to
[postmortem.md](postmortem.md), and [COMPLETED.md](COMPLETED.md) and
[ROADMAP.md](ROADMAP.md) kept current as the work lands.

## A document was added, and two were corrected

[CHANGELOG.md](CHANGELOG.md) is new and is linked from the README and the site.
Four records existed and none said **when**; this is that one, keyed to the
`stage-*` tags.

Writing it corrected two others. `COMPLETED.md`'s stage table had `-o` at 4 and
Pascal at 5 where the tags and the journal have them the other way round — and
the README turned out to hold a *second* stage table, which is the original
plan rather than the delivery. Neither was wrong about its own subject; neither
said what its subject was. Both do now.

## The one thing worth carrying forward

The morning's lesson was *run the documentation whose claims are not already
held by something else* — three tutorials had eight defects and the reference
had none, because a tutorial's subject is a session and a reference's subject
is a tool that has tests. That is [postmortem.md](postmortem.md) § 6.

The afternoon found the same shape one level down, twice. `outer 0, n`
assembled cleanly and would not load, because a depth bound had been
transcribed from *reasoning about behaviour* rather than from
`serialize.c:817`, which states both halves on one line. Then the nesting limit
looked identical on both sides — and looking is what had just been wrong, so
sixteen nested blocks got generated instead. That one held.

> **A bound is a claim. Generate the program that sits on it.**

Five defects today. Two came from reading a bound instead of running one, one
from writing a count from memory when `grep -c` was right there, and two from a
page published in the afternoon that was wrong within the hour — caught by
running `git log -S` for every feature it dates rather than re-reading it.

`postmortem.md` § 9 scores the pattern, including where it fails: **asking
*anything open?* audits what has settled, and cannot audit what was written
since the asking.** The newest page is the likeliest to be wrong.
