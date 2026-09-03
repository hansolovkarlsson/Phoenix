#!/bin/sh
# languages/units/tests/run.sh -- the unit experiment, against `fpc -Mtp`.
#
# Every program under `programs/` holds its units and its program in **one
# file**, because reading a second file is `%include`'s question and this one
# is about resolution. `fpc` wants them separate, so the file is split back
# into the units it describes and handed to the real compiler -- and what the
# two print must agree.
#
# `tests/` holds what must be refused and `divergent/` what this description
# gets wrong, which is one thing and is written down in it.

set -u

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$root" || exit 1
phx=$root/bin/phx
desc=languages/units/units.phx
lang=languages/units

fail=0
ok() { printf '  ok    %s\n' "$1"; }
no() { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

tmp=${TMPDIR:-/tmp}/units-tests.$$
mkdir -p "$tmp" || exit 1
trap 'rm -rf "$tmp"' EXIT

# One file back into the units it describes, which is how it was written.
split_units() {
    awk -v d="$2" '
        /^unit |^program /{ n = $2; sub(/;.*/, "", n); f = d "/" n ".pas" }
        f { print > f }
    ' "$1"
}

# ---- what each program answers, and what fpc answers for the same thing ----

for f in $lang/programs/*.pas; do
    n=$(basename "$f" .pas)
    if ! "$phx" "$desc" "$f" > "$tmp/$n.out" 2>&1; then
        no "$n resolves"; sed 's/^/        /' "$tmp/$n.out" | head -3; continue
    fi
    if cmp -s "$tmp/$n.out" "$lang/programs/$n.expected"; then
        ok "$n resolves as it did"
    else
        no "$n resolves as it did"
        diff "$lang/programs/$n.expected" "$tmp/$n.out" | sed 's/^/        /' | head -6
    fi
done

for f in $lang/tests/*.pas; do
    n=$(basename "$f" .pas)
    want=$(sed -n 's/^{ fpc -Mtp: \(.*\) }$/\1/p' "$f" | head -1)
    if out=$("$phx" --quiet "$desc" "$f" 2>&1); then
        no "$n is refused"
    elif printf '%s' "$out" | grep -qiF -- "$want"; then
        ok "$n: $want"
    else
        no "$n is refused for the right reason"
        printf '%s\n' "$out" | sed 's/^/        /' | head -2
    fi
done

# ---- and fpc is the arbiter, when it is here ----

if ! command -v fpc >/dev/null 2>&1; then
    printf '  --    the oracle needs fpc, which is not on this machine\n'
    [ "$fail" -eq 0 ]
    exit $?
fi

for f in $lang/programs/*.pas; do
    n=$(basename "$f" .pas)
    d="$tmp/fpc-$n"; mkdir -p "$d"
    split_units "$f" "$d"
    main=$(sed -n 's/^program \([a-z_0-9]*\);.*/\1/p' "$f" | head -1)
    if ! ( cd "$d" && fpc -Mtp "$main.pas" >/dev/null 2>&1 ); then
        no "fpc compiles $n"
        ( cd "$d" && fpc -Mtp "$main.pas" 2>&1 | grep -E 'Error|Fatal' | head -2 | sed 's/^/        /' )
        continue
    fi
    ( cd "$d" && "./$main" ) > "$tmp/$n.fpc" 2>&1
    if cmp -s "$tmp/$n.fpc" "$lang/programs/$n.expected"; then
        ok "$n: fpc -Mtp prints the same"
    else
        no "$n: fpc -Mtp prints something else"
        diff "$tmp/$n.fpc" "$lang/programs/$n.expected" | sed 's/^/        /' | head -6
    fi
done

# What this description gets wrong, written down inside each file. The test is
# that it still gets it wrong in the way it says: a divergence that quietly
# went away would mean the file is now a lie, and one that changed shape means
# something else moved.
for f in $lang/divergent/*.pas; do
    n=$(basename "$f" .pas)
    d="$tmp/div-$n"; mkdir -p "$d"
    split_units "$f" "$d"
    main=$(sed -n 's/^program \([a-z_0-9]*\);.*/\1/p' "$f" | head -1)

    mine=$("$phx" "$desc" "$f" 2>&1); mine_ok=$?
    theirs=""
    if ( cd "$d" && fpc -Mtp "$main.pas" >/dev/null 2>&1 ); then
        theirs=$( cd "$d" && "./$main" 2>&1 ); their_ok=0
    else
        their_ok=1
    fi

    if [ "$mine_ok" -eq 0 ] && [ "$their_ok" -ne 0 ]; then
        ok "$n: fpc refuses it and this does not, as the file says"
    elif [ "$mine_ok" -eq 0 ] && [ "$their_ok" -eq 0 ] && [ "$mine" != "$theirs" ]; then
        ok "$n: both run and differ, as the file says"
    else
        no "$n: the divergence this file describes is no longer there"
    fi
done

[ "$fail" -eq 0 ]
