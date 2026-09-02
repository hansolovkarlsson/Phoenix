#!/bin/sh
# languages/awk/tests/oracle.sh -- awk itself is the arbiter.
#
# A round trip can be green while the parse is consistently wrong: what is
# written back out is wrong in the same way, so it re-parses to the same tree.
# `docs/journal.md` has that mistake twice. So the real test is not whether the
# rendering *reads* the same, it is whether it **does** the same.
#
# Two halves:
#
#   - **conformance**, where each program's output under `/usr/bin/awk` is
#     checked in beside it. That pins the programs -- if awk ever disagrees
#     with the file, the file is what is wrong -- and then the rendering has to
#     produce that same output. Ten of the eleven things awk has are in here,
#     including a function called above where it is defined.
#
#   - **the corpus**, which is awk other people wrote and which needs input
#     this repository does not have. Both versions are run on nothing, which
#     exercises `BEGIN`, `END` and whether awk accepts the program at all. The
#     line number inside awk's *own* error messages is normalised away: it
#     names a line of the file it was given, and the rendering has fewer.
#
# Nothing here writes outside Phoenix: every program runs with its working
# directory in `build/`, because `printing.awk` writes a file on purpose.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/awk/awk.phx"

command -v awk >/dev/null 2>&1 || { echo "  --    needs awk, which is not here"; exit 0; }

out="$root/build/awk-oracle"; rm -rf "$out"; mkdir -p "$out/run"
trap 'rm -rf "$out"' EXIT

# What awk prints for a program, run in a directory of its own.
run() {
    ( cd "$out/run" && awk -f "$1" "$2" 2>&1 ) \
        | sed 's/source line number [0-9]*/source line number N/
               s#source file [^ ]*#source file F#'
}

same=0; differ=0
for f in "$here"/conformance/*.awk; do
    n=$(basename "$f" .awk)
    in=/dev/null; [ -f "$here/conformance/$n.in" ] && in="$here/conformance/$n.in"

    # The program against what is checked in beside it.
    run "$f" "$in" > "$out/want"
    if ! cmp -s "$out/want" "$here/conformance/$n.expected"; then
        differ=$((differ+1)); echo "  $n.awk no longer prints what $n.expected says"
        diff "$here/conformance/$n.expected" "$out/want" | head -4 | sed 's/^/      /'
        continue
    fi

    # And the rendering against the same.
    "$phx" "$desc" "$f" > "$out/rt.awk" 2>/dev/null
    run "$out/rt.awk" "$in" > "$out/mine"
    if cmp -s "$out/want" "$out/mine"; then same=$((same+1))
    else
        differ=$((differ+1)); echo "  rendered $n.awk behaves differently"
        diff "$out/want" "$out/mine" | head -6 | sed 's/^/      /'
    fi
done

corpus=0
for f in "$here"/corpus/*.awk; do
    "$phx" "$desc" "$f" > "$out/rt.awk" 2>/dev/null
    run "$f" /dev/null > "$out/want"
    run "$out/rt.awk" /dev/null > "$out/mine"
    if cmp -s "$out/want" "$out/mine"; then corpus=$((corpus+1))
    else
        differ=$((differ+1)); echo "  rendered $(basename "$f") behaves differently"
        diff "$out/want" "$out/mine" | head -6 | sed 's/^/      /'
    fi
done

printf '%d awk programs and %d other people wrote do the same thing rendered' \
       "$same" "$corpus"
printf ', %d do not\n' "$differ"
[ "$differ" -eq 0 ]
