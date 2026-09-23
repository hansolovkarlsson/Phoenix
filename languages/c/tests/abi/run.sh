#!/bin/sh
# languages/c/tests/abi/run.sh -- the calling convention, held against cc's.
#
# The oracle compiles each program whole, one way or the other, so it asks
# whether Phoenix agrees with *itself* about how a struct is passed, and it
# always will. What AAPCS64 is for is two compilers agreeing, so here the
# caller and the callee are two files and each is compiled by each: cc and
# cc, Phoenix and cc, cc and Phoenix. All three must print the same thing.
#
# It is the one witness for the caller's copy of a large struct. A callee
# Phoenix compiled copies the struct again and would never notice a caller
# that did not; a callee cc compiled writes into the memory it was handed.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/c/c-arm64.phx"

if [ "$(uname -m)" != "arm64" ]; then
    echo "this machine is not arm64 -- skipped, not failed"
    exit 0
fi

tmp="$root/build/c-abi"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

"$phx" --driver arm64 "$desc" "$here/caller.c" > "$tmp/caller.s" || exit 1
"$phx" --driver arm64 "$desc" "$here/callee.c" > "$tmp/callee.s" || exit 1
cc -w -o "$tmp/cc-cc"  "$here/caller.c" "$here/callee.c" || exit 1
cc -w -o "$tmp/phx-cc" "$tmp/caller.s"  "$here/callee.c" || exit 1
cc -w -o "$tmp/cc-phx" "$here/caller.c" "$tmp/callee.s"  || exit 1

want=$("$tmp/cc-cc")
fail=0
for pair in phx-cc cc-phx; do
    got=$("$tmp/$pair")
    if [ "$got" = "$want" ]; then
        printf '  ok    %s\n' "$pair"
    else
        printf '  FAIL  %s: cc says "%s" and this says "%s"\n' "$pair" "$want" "$got"
        fail=1
    fi
done
exit $fail
