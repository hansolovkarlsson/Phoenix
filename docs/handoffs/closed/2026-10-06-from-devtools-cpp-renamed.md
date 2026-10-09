# Proem is cpp again, and its directory is `DevTools/cpp`

- **From:** DevTools
- **To:** Phoenix
- **Date:** 2026-10-06
- **Kind:** notice
- **Status:** done

## What is asked

Nothing is required. This follows
`closed/2026-10-06-from-devtools-proem-moved.md`, which you answered by
pointing the Proem probe at `../DevTools/proem` (`4232a58`). Later the same
day, inside DevTools, the preprocessor went back to its first name, cpp,
and its directory with it: the checkout is now `../DevTools/cpp`, and
`../DevTools/proem` no longer exists.

- `languages/c/tests/proem/run.sh` line 36 defaults to
  `$root/../DevTools/proem`, so it now stops with "no Proem checkout".
  Pointed at `../DevTools/cpp` it finds the same `lib/` and `driver/`, with
  one change: the driver is `driver/cpp.c`, not `driver/proem.c`, and the
  library's identifiers are `cpp_...` instead of `proem_...`. The probe's
  stub headers, if they name a Proem identifier, would follow.
- The probe's directory is `tests/proem/`; whether it keeps that name is
  yours to decide.

Hans decided the rename on 2026-10-06: Proem was a name for a project of its
own, and in DevTools, beside a C compiler in `cc/`, the Unix name says what
the tool is.

## Why

`ls ~/Projects/DevTools/cpp/lib ~/Projects/DevTools/cpp/driver` lists the
library and `cpp.c`; `ls ~/Projects/DevTools/proem` fails.
`~/Projects/DevTools/docs/ROADMAP.md`, "Rename Proem back to cpp", records
the decision.

## Reply

Done in `867607e`. `languages/c/tests/proem/run.sh` reads
`../DevTools/cpp` by default, and its comment says so; run with no argument
it accepts nine files of ten, `driver/cpp.c` among them, and stops in
`pp.c` at line 971, as it did against `../DevTools/proem`. The stubs named
no Proem identifier, so none changed. The probe keeps its directory,
`tests/proem/`, since the records cite it by that name. The links in
ROADMAP section 6 and COMPLETED point at `../../DevTools/cpp/`, with CPP
and Proem kept as the names it had before; quotations of `proem_...`
source in the journal, postmortem and ROADMAP stay as they were printed.
