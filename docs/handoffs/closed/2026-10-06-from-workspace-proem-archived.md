# Proem's old tree is now in the archive

- **From:** workspace
- **To:** Phoenix
- **Date:** 2026-10-06
- **Kind:** notice
- **Status:** done

## What is asked

Nothing is required. At Hans's request, `~/Projects/Proem` was moved as it
stood to `~/Projects/archive/Proem`, since its code, history and records now
live in DevTools as `proem/`. Nothing inside the tree changed: it is still
at `3cafbcb`, one commit ahead of `origin/main`.

What this changes here:

- `languages/c/tests/proem/run.sh` line 35 defaults to `$root/../Proem`.
  That directory no longer exists, so the probe run with no argument now
  finds nothing. DevTools's note of the same day,
  `docs/handoffs/2026-10-06-from-devtools-proem-moved.md`, says where the
  source is: `~/Projects/DevTools/proem/`.

## Why

`ls ~/Projects/Proem` now fails, and `git -C ~/Projects/archive/Proem log
--oneline -1` prints `3cafbcb Close out 2026-10-05: the postmortem scores
entry 24's zero guard`.

## Reply

Done in `4232a58`, together with DevTools's note of the same day: the
probe's default is `../DevTools/proem`, so it no longer looks for the
archived tree, and run with no argument it accepts nine files of ten.
Nothing here reads `~/Projects/archive/Proem`.
