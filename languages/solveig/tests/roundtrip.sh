#!/bin/sh
# languages/solveig/tests/roundtrip.sh -- parse it, write it back, parse that.
#
# **A check on the tree rather than a pretty-printer.** Every `.sol` file there
# is is parsed, written back out by the `show` pass, and parsed again; the two
# trees must be identical. That catches a node built with the wrong shape, an
# argument list dropped, or a chain folded the wrong way round -- over every
# file in the Solveig repository rather than over the ones somebody thought to
# look at, including a 2,800-line compiler written in Solveig.
#
# It is not a round trip of *source*: `@expr(a + b)` comes back as `a:add(b)`,
# because the region is a spelling and the tree holds the sends. It is a round
# trip of *meaning*, and it works because the lowering is idempotent.
#
# `--no-includes` because the question is about **this file**. Following an
# `@include` is what a compilation does, and a tree with another file already
# spliced into it would be a round trip of two files at once -- checking the
# library over and over and never once checking that an `@include` is written
# back as one.
#
# The conformance programs get the stronger check as well: what comes out is
# compiled by `solas` and run, and must print what the original printed.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/solveig/solveig.phx"
sol=${SOLVEIG:-$root/../Solveig}

tmp="$root/build/roundtrip"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

files="$here/conformance/*.sol"
[ -d "$sol" ] && files="$sol/examples/*.sol $sol/programs/*.sol $sol/lib/*.sol $files"

same=0; differ=0
for f in $files; do
    [ -f "$f" ] || continue
    "$phx" --no-includes --tree "$desc" "$f" > "$tmp/a" 2>/dev/null || { differ=$((differ+1)); echo "  will not parse: $f"; continue; }
    "$phx" --no-includes "$desc" "$f" > "$tmp/rt.sol" 2>/dev/null
    "$phx" --no-includes --tree "$desc" "$tmp/rt.sol" > "$tmp/b" 2>/dev/null
    if cmp -s "$tmp/a" "$tmp/b"; then same=$((same+1))
    else differ=$((differ+1)); echo "  tree differs: $f"; fi
done
printf '%d files round-trip to an identical tree, %d do not\n' "$same" "$differ"

# The conformance programs, all the way: rendered, compiled by solas, run.
ran=0; wrong=0
if [ -x "$sol/bin/solas" ]; then
    for f in "$here"/conformance/*.sol; do
        n=$(basename "$f" .sol)
        "$phx" --no-includes "$desc" "$f" > "$tmp/rt.sol" 2>/dev/null
        "$sol/bin/solas" "$tmp/rt.sol" -o "$tmp/rt.sob" >/dev/null 2>&1 \
            && "$sol/bin/solvm" "$tmp/rt.sob" > "$tmp/out" 2>&1
        if cmp -s "$tmp/out" "$here/conformance/$n.expected"; then ran=$((ran+1))
        else wrong=$((wrong+1)); echo "  behaves differently after a round trip: $n"; fi
    done
    printf '%d rendered programs still behave the same, %d do not\n' "$ran" "$wrong"
fi

[ "$differ" -eq 0 ] && [ "$wrong" -eq 0 ]
