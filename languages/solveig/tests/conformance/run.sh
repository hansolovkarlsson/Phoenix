#!/bin/sh
# languages/solveig/tests/conformance/run.sh
#
# **A conformance suite for the Solveig language**, as against a test suite for
# any one implementation of it. Each `.sol` here is compiled, run, and its
# output compared with a `.expected` file byte for byte -- so anything claiming
# to compile Solveig can be held to the same programs.
#
#   run.sh                 all of them
#   run.sh arrays          one of them
#   run.sh --accept        write what the compiler produces as the expectation
#
# **What the expectations are.** They record what `solas` and `solvm` do, read
# against `docs/CHEATSHEET.md` and `docs/REFERENCE.md` rather than taken on
# trust. Where the two disagree, that is a finding and not a fixture: the
# programs below assert what the documentation says the language *is*, and a
# compiler that differs is wrong until somebody argues otherwise.
#
# Skipped and not failed where there is no Solveig: it is an oracle and not a
# dependency.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
sol=${SOLVEIG:-$here/../../../../../Solveig}

if [ ! -x "$sol/bin/solas" ] || [ ! -x "$sol/bin/solvm" ]; then
    echo "no Solveig at $sol -- the conformance suite is skipped, not failed"
    exit 0
fi

tmp="$root/build/conformance"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

accept=no
only=""
for arg in "$@"; do
    case "$arg" in
        --accept) accept=yes ;;
        *)        only=$arg ;;
    esac
done

pass=0
fail=0

for src in "$here"/*.sol; do
    name=$(basename "$src" .sol)
    [ -n "$only" ] && [ "$only" != "$name" ] && continue

    if ! "$sol/bin/solas" "$src" -o "$tmp/$name.sob" >"$tmp/$name.log" 2>&1; then
        printf '  FAIL  %-14s it would not compile\n' "$name"
        sed 's/^/          /' "$tmp/$name.log" | head -3
        fail=$((fail + 1))
        continue
    fi

    "$sol/bin/solvm" "$tmp/$name.sob" > "$tmp/$name.out" 2>&1

    if [ "$accept" = yes ]; then
        cp "$tmp/$name.out" "$here/$name.expected"
        printf '  --    %-14s expectation written\n' "$name"
        continue
    fi

    if [ ! -f "$here/$name.expected" ]; then
        printf '  FAIL  %-14s no expectation; run with --accept and read it\n' "$name"
        fail=$((fail + 1))
        continue
    fi

    if cmp -s "$tmp/$name.out" "$here/$name.expected"; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$name"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s\n' "$name"
        diff -u "$here/$name.expected" "$tmp/$name.out" | sed -n '3,14p' | sed 's/^/          /'
    fi
done

printf '\n%d programs conform, %d do not\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
