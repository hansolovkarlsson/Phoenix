#!/bin/sh
# languages/z80/tests/oracle/run.sh -- the same assembly, assembled twice.
#
# Every program here is assembled by `z80asm` and by Phoenix, and the two
# binaries are compared **byte for byte**. `z80asm` is the oracle: where they
# differ, Phoenix is wrong until somebody shows otherwise.
#
# This is a better oracle than the ones the other languages have, and the
# reason is worth writing down. Pascal and Solveig are compared on what a
# program *prints*, which is agreement about behaviour and can hide a
# consistently wrong translation -- journal.md records that happening three
# times. An assembler's whole output is the artefact, so there is nothing for
# it to be right about privately: the bytes match or they do not.
#
#   languages/z80/tests/oracle/run.sh            all of them
#   languages/z80/tests/oracle/run.sh forward    one of them
#
# Skipped, not failed, when there is no z80asm: it is an oracle and not a
# dependency, the same bargain `fpc` and `solas` are on.
#
# `-o` is not optional. z80asm writes `a.bin` in the working directory when it
# is left off, which is how a stray one appeared in the repository root the
# first time it was run by hand.

set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/z80/z80.phx"

if ! command -v z80asm >/dev/null 2>&1; then
    echo "no z80asm on this machine -- the oracle is skipped, not failed"
    exit 0
fi

tmp="$root/build/z80-oracle"; rm -rf "$tmp"; mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
only=${1:-}

for src in "$here"/*.z80; do
    name=$(basename "$src" .z80)
    [ -n "$only" ] && [ "$only" != "$name" ] && continue

    # The oracle.
    if ! z80asm -o "$tmp/$name.want" "$src" >"$tmp/$name.z80asm.log" 2>&1; then
        printf '  SKIP  %-12s z80asm would not assemble it\n' "$name"
        sed 's/^/          /' "$tmp/$name.z80asm.log" | head -2
        continue
    fi

    # Phoenix.
    if ! "$phx" --driver code --raw "$desc" "$src" \
             >"$tmp/$name.got" 2>"$tmp/$name.phx.log"; then
        printf '  FAIL  %-12s phoenix would not assemble it\n' "$name"
        sed 's/^/          /' "$tmp/$name.phx.log" | head -3
        fail=$((fail + 1))
        continue
    fi

    if cmp -s "$tmp/$name.want" "$tmp/$name.got"; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$name"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s\n' "$name"
        printf '          z80asm  %s\n' "$(xxd -p "$tmp/$name.want" | tr -d '\n')"
        printf '          phoenix %s\n' "$(xxd -p "$tmp/$name.got"  | tr -d '\n')"
    fi
done

printf '\n%d agree with z80asm, %d do not\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
