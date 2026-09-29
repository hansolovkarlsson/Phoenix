#!/bin/sh
# languages/c/tests/link/run.sh -- linkage, which one file cannot show.
#
# A `static` function or global is its file's own, C11 6.2.2p3, and in a
# program of one file it behaves as any other. So here two files each have
# a `static int count`, a `static long total`, a `static int seen[2]`, a
# `static int helper`, and a `later` declared `static` and then defined
# without it, which C11 6.2.2p4 makes the file's own too. They link only if
# each `helper` and `later` is its file's own, and print what `cc` prints
# only if each `count`, `total` and `seen` is: a zero global the linker
# merged with the other file's would link and print something else, which
# is the way this could go wrong quietly.
#
# Each file is compiled by each compiler, as `tests/abi/` does: both by
# Phoenix, and each by Phoenix beside the other by `cc`.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
. "$root/tests/limit.sh"
desc="$root/languages/c/c-arm64.phx"

if [ "$(uname -m)" != "arm64" ]; then
    echo "this machine is not arm64 -- skipped, not failed"
    exit 0
fi

tmp="$root/build/c-link"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

bounded "$phx" --driver arm64 "$desc" "$here/first.c"  > "$tmp/first.s"  || exit 1
bounded "$phx" --driver arm64 "$desc" "$here/second.c" > "$tmp/second.s" || exit 1
cc -w -o "$tmp/cc-cc"   "$here/first.c" "$here/second.c" || exit 1
cc -w -o "$tmp/phx-phx" "$tmp/first.s"  "$tmp/second.s"  || exit 1
cc -w -o "$tmp/phx-cc"  "$tmp/first.s"  "$here/second.c" || exit 1
cc -w -o "$tmp/cc-phx"  "$here/first.c" "$tmp/second.s"  || exit 1

want=$(bounded "$tmp/cc-cc"); want_status=$?
fail=0
for pair in phx-phx phx-cc cc-phx; do
    got=$(bounded "$tmp/$pair"); got_status=$?
    if [ "$got" = "$want" ] && [ "$got_status" = "$want_status" ]; then
        printf '  ok    %s\n' "$pair"
    else
        printf '  FAIL  %s: cc says "%s", %s, and this says "%s", %s\n' \
            "$pair" "$want" "$want_status" "$got" "$got_status"
        fail=1
    fi
done
exit $fail
