#!/bin/sh
# languages/awk/tests/roundtrip.sh -- parse it, write it back, parse that.
#
# **A check on the tree rather than a pretty-printer.** Every awk program here
# is parsed, written back out by the `show` pass, and parsed again; the two
# trees must be identical. That catches a node built with the wrong shape, an
# argument list dropped, or a fold that went the wrong way.
#
# It is not a round trip of *source*: comments are skipped and do not come
# back, statements come out separated by `;` whatever they were written with,
# and a line break inside an expression is gone. It is a round trip of
# **structure**, and it works because a parenthesis is a `Group` node -- no
# bracket comes back that was not written, and none that was written is lost.
#
# `corpus/` is awk other people wrote, for reasons of their own: e2fsprogs,
# ncurses and vim ship these. `outside/` is the one that is **not** POSIX awk
# and is here anyway, because structure is structure. `not-yet/` is awk the
# backend does not compile, which has nothing to do with reading it.
#
# `divergent/` is **not** here: it holds the programs this description reads
# differently from awk, or does not read at all, and a round trip of those is
# not a question worth asking.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/awk/awk.phx"

tmp="$root/build/awk-roundtrip"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

same=0; differ=0
for f in "$here"/corpus/*.awk "$here"/outside/*.awk "$here"/conformance/*.awk \
         "$here"/backend/*.awk "$here"/not-yet/*.awk; do
    [ -f "$f" ] || continue
    if ! "$phx" --tree "$desc" "$f" > "$tmp/a" 2>/dev/null; then
        differ=$((differ+1)); echo "  will not parse: $f"; continue
    fi
    "$phx" "$desc" "$f" > "$tmp/rt.awk" 2>/dev/null
    if ! "$phx" --tree "$desc" "$tmp/rt.awk" > "$tmp/b" 2>/dev/null; then
        differ=$((differ+1)); echo "  what it wrote will not parse: $f"; continue
    fi
    if cmp -s "$tmp/a" "$tmp/b"; then same=$((same+1))
    else differ=$((differ+1)); echo "  tree differs: $f"; fi
done
printf '%d awk programs parse, render, and parse to the same tree, %d do not\n' \
       "$same" "$differ"
[ "$differ" -eq 0 ]
