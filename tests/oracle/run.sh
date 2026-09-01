#!/bin/sh
# tests/oracle/run.sh -- the same Pascal, compiled two ways, giving one answer.
#
# Every program here is compiled by `fpc -Miso` and by Phoenix, both are run,
# and their output is compared byte for byte. **fpc is the oracle**: where they
# differ, Phoenix is wrong until somebody shows otherwise, because fpc has been
# read by more people than this repository has.
#
# It is the method Solveig's PASCAL.md uses for the same reason, and it is what
# turns "the output looks right" into "the output is Pascal's".
#
#   tests/oracle/run.sh            all of them
#   tests/oracle/run.sh reals      one of them
#
# **An oracle can agree with a wrong program.** `bounds.pas` passed while the
# compiler was writing outside its arrays: both the write and the read used the
# same wrong offset, so the answers matched and the memory did not. Agreement
# is evidence and not proof, and a program that only reads back what it wrote
# is the case to be suspicious of.
#
# Skipped, not failed, when there is no fpc: it is an oracle and not a
# dependency.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../.." && pwd)
phx="$root/bin/phx"
desc="$root/examples/pascal-c.phx"

if ! command -v fpc >/dev/null 2>&1; then
    echo "no fpc on this machine -- the oracle is skipped, not failed"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
only=${1:-}

for src in "$here"/*.pas; do
    name=$(basename "$src" .pas)
    [ -n "$only" ] && [ "$only" != "$name" ] && continue

    cp "$src" "$tmp/$name.pas"

    # The oracle.
    if ! (cd "$tmp" && fpc -Miso "$name.pas" >"$name.fpc.log" 2>&1); then
        printf '  SKIP  %-12s fpc would not compile it\n' "$name"
        sed 's/^/          /' "$tmp/$name.fpc.log" | grep -i 'error\|fatal' | head -2
        continue
    fi
    # stdout only: fpc's runtime errors carry an address that changes every
    # run, so what is compared is what the program *wrote*.
    want=$("$tmp/$name" 2>/dev/null)

    # Phoenix.
    if ! "$phx" --driver c "$desc" "$src" > "$tmp/$name.c" 2>"$tmp/$name.phx.log"; then
        printf '  FAIL  %-12s phoenix would not compile it\n' "$name"
        sed 's/^/          /' "$tmp/$name.phx.log" | head -3
        fail=$((fail + 1))
        continue
    fi
    if ! cc -o "$tmp/$name.bin" "$tmp/$name.c" 2>"$tmp/$name.cc.log"; then
        printf '  FAIL  %-12s the C it emitted would not compile\n' "$name"
        sed 's/^/          /' "$tmp/$name.cc.log" | head -3
        fail=$((fail + 1))
        continue
    fi
    got=$("$tmp/$name.bin" 2>/dev/null)

    if [ "$want" = "$got" ]; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$name"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s\n' "$name"
        printf '%s\n' "$want" > "$tmp/want"
        printf '%s\n' "$got"  > "$tmp/got"
        diff -u "$tmp/want" "$tmp/got" | sed -n '3,14p' | sed 's/^/          /'
    fi
done

printf '\n%d agree with fpc, %d do not\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
