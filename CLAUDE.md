# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Start here

`scratch/daily-standup.md` — written at the end of the previous working day to
be read at the start of the next: where the tree was left, what went in, and
what is outstanding. `scratch/` is gitignored and is not part of this
repository, so the file is absent on a fresh clone and on any day that was not
closed out. When it is absent, `git log` and the documents named below are the
way in.

## What this is

A compiler generator. You write a language's grammar in EBNF and describe what
each construct means; Phoenix writes the compiler. C11, no dependencies, and
nothing outside this repository is needed to build it or to run its tests.

## Commands

`make`, `make test`, `make clean`.

## The records

Five documents in `docs/`, each answering a different question. Putting the
same paragraph in two of them means at least one is wrong.

- `journal.md` — why each decision was made, in the order it was made.
- `postmortem.md` — predictions scored against what actually happened.
- `COMPLETED.md` is what exists, `ROADMAP.md` is what does not. An item moves
  from one to the other when it is settled, **including settled against**.
- `CHANGELOG.md` — *when* it shipped, for a reader not reading the source.

Each of those opens with an italic note stating its own job. That note is the
specification for what belongs in it — follow it over any general instruction.
