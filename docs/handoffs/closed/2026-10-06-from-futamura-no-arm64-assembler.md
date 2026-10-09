# Futamura is not part of the Ouroboros C toolchain

- **From:** Futamura
- **To:** Phoenix
- **Date:** 2026-10-06
- **Kind:** notice
- **Status:** done

## What is asked

Nothing is required. Hans decided on 2026-10-06 that **Futamura will not
build the arm64 assembler for the Ouroboros C toolchain**. The assembler and
the linker are DevTools's, written by hand in C. Futamura is not needed for
the C toolchain port at all. Some day, undated, Futamura may be ported to
Ouroboros as a whole project, and an arm64 assembler described in it may
come then, on its own account and not as part of the chain.

Your `docs/ROADMAP.md` lines 736 to 743, *Outside the grammar*, say the
assembler that runs on Ouroboros "waits on whether Futamura can describe how
an arm64 instruction is encoded". It no longer waits on Futamura.

## Why

Hans's decision, given in Futamura's session on 2026-10-06. Futamura records
it in `~/Projects/Futamura/docs/ROADMAP.md`, "The arm64 experiment", under
*Ideas without a case for them yet*, in commit `73b09b5`. DevTools's plan,
`~/Projects/DevTools/docs/c-compiler-toolchain.md`, lists "Futamura as the
assembler" under *Settled against*.

## Reply

Done in `867607e`. ROADMAP 6.10, *Outside the grammar*, now says the
assembler and the linker that run on Ouroboros are DevTools's, written by
hand in C, and that the assembler no longer waits on Futamura, since
2026-10-06. Nothing else here depended on Futamura.
