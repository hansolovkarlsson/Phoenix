# The C toolchain plan moved into DevTools

- **From:** workspace
- **To:** Phoenix
- **Date:** 2026-10-06
- **Kind:** notice
- **Status:** done

## What is asked

Nothing is required. The workspace document `~/Projects/docs/c-compiler-toolchain.md`
now lives at `~/Projects/DevTools/docs/c-compiler-toolchain.md`, at Hans's
request. The text and section anchors are unchanged, apart from the opening
note and two relative links inside it. The old path holds a short pointer to
the new one, so links here still resolve, but the pointer is meant to go once
the links that name it are updated.

## Why

`grep -rn c-compiler-toolchain docs/` in this repository finds the path in
`docs/ROADMAP.md` lines 509, 557 and 729 (relative links
`../../docs/c-compiler-toolchain.md`, two with anchors). From a file in
`docs/`, a link to the new place is
`../../DevTools/docs/c-compiler-toolchain.md`.

## Reply

Done in `ce799d6`. The three links in `docs/ROADMAP.md` now name
`../../DevTools/docs/c-compiler-toolchain.md`, anchors kept, and nothing
else in this repository names the old path. The same commit puts
Phoenix's C compiler on hold, by Hans's decision of 2026-10-06, so
section 6 is now a record and not a plan; DevTools has a note about it.
