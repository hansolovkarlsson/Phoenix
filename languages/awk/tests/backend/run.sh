#!/bin/sh
# languages/awk/tests/backend/run.sh -- awk compiled to C, against awk.
#
# **The conformance rule, with a third language under it.** Each program is
# compiled by `awk-c.phx` into C, that C is compiled by `cc`, and what it
# prints has to be what `/usr/bin/awk` prints on the same input -- byte for
# byte, with nothing normalised.
#
# These are stage one: values, fields, the main loop, `print` and `printf`,
# arithmetic, comparison, concatenation and control flow. Arrays, functions and
# regular expressions are refused by name, and `../refused-by-the-backend/`
# holds one of each so that the refusals are checked rather than assumed.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/awk/awk-c.phx"

command -v awk >/dev/null 2>&1 || { echo "  --    needs awk, which is not here"; exit 0; }

out="$root/build/awk-backend"; rm -rf "$out"; mkdir -p "$out/run"
trap 'rm -rf "$out"' EXIT

same=0; differ=0
for f in "$here"/*.awk; do
    n=$(basename "$f" .awk)
    in=/dev/null; [ -f "$here/$n.in" ] && in="$here/$n.in"

    if ! "$phx" --driver c "$desc" "$f" > "$out/$n.c" 2>"$out/err"; then
        differ=$((differ+1)); echo "  will not compile: $n.awk"
        sed 's/^/      /' "$out/err" | head -3; continue
    fi
    if ! cc -o "$out/$n" "$out/$n.c" 2>"$out/cc-err"; then
        differ=$((differ+1)); echo "  the C will not build: $n.awk"
        sed 's/^/      /' "$out/cc-err" | head -3; continue
    fi

    ( cd "$out/run" && awk -f "$f" "$in" ) > "$out/want" 2>&1
    ( cd "$out/run" && "$out/$n" < "$in" )  > "$out/mine" 2>&1

    if cmp -s "$out/want" "$out/mine"; then same=$((same+1))
    else
        differ=$((differ+1)); echo "  $n.awk: compiled and interpreted disagree"
        diff "$out/want" "$out/mine" | head -8 | sed 's/^/      /'
    fi
done
printf '%d awk programs compiled to C print what awk prints, %d do not\n' "$same" "$differ"
[ "$differ" -eq 0 ]
