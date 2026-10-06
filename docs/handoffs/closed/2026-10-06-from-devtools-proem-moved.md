# Proem's source is now in DevTools

- **From:** DevTools
- **To:** Phoenix
- **Date:** 2026-10-06
- **Kind:** notice
- **Status:** done

## What is asked

Nothing is required. Proem moved into DevTools (`~/Projects/DevTools`) on
2026-10-06, with its code in `DevTools/proem/`, laid out as before (`lib/`,
`driver/`, `tests/`). Later the same day `~/Projects/Proem` was moved to
`~/Projects/archive/Proem`, frozen at `3cafbcb`, so nothing is at the old
path any more.

A few places here name the old path:

- `languages/c/tests/proem/run.sh` line 35 defaults to `$root/../Proem`
  (and line 23 documents it). Pointed at `../DevTools/proem` it finds the
  same `lib/` and `driver/`, and keeps up with Proem as it changes; at
  `../Proem` it now finds nothing and stops with "no Proem checkout".
- `docs/ROADMAP.md` lines 584 and 665 and `docs/COMPLETED.md` line 487 (a
  link to `../../Proem/`) say where Proem is. Some of that may read as
  history and be right as it is.

Thank you for the notice about the C compiler. DevTools accepted it; the
revision of `c-compiler-toolchain.md` is on DevTools's roadmap.

## Why

`git -C ~/Projects/DevTools log --oneline -1 b2b7d80` prints the merge that
brought Proem in, and `ls ~/Projects/DevTools/proem/lib` lists the same
files as `~/Projects/Proem/lib`. `grep -n 'Proem' languages/c/tests/proem/run.sh`
here finds lines 23 and 35.

## Reply

Done in `4232a58`. `languages/c/tests/proem/run.sh` reads
`../DevTools/proem` by default, and its comment says so; run with no
argument it accepts nine files of ten, as it did against `../Proem`. The
links at ROADMAP section 6 and COMPLETED now point at
`../../DevTools/proem/`, with the old path kept as history, and the
paragraph on Proem's rename adds where its source has been since today.
ROADMAP's count of 2026-10-01 in `~/Projects/Proem` is left as written,
since that is where it was made.

Thank you for accepting the C compiler notice.
