#!/bin/sh
# languages/solveig/tests/bytecode.sh -- the .sob backend, against solas.
#
# **The oracle is the real compiler.** Every `.sol` file in the Solveig
# repository is compiled twice -- once by `solas`, once by `solveig-sob.phx` --
# and both `.sob` files are run by `solvm`. What they print must agree.
#
# Two things are normalised away, and both are absences rather than
# differences:
#
#   - **a location in a traceback**, because this backend emits one line run
#     for a whole chunk and no file table at all, so a message says
#     `[line 1]` where `solas` says the file and the line
#   - **a file that does not print the same thing twice under `solas`**,
#     which is a program that reads the clock or the file system rather than
#     a disagreement about what it compiles to
#
# `@include` is refused by the backend -- splicing another file in is a thing
# a reader does, and this is a pass over one tree -- so those files are
# counted separately rather than as failures.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/solveig/solveig-sob.phx"
sol=${SOLVEIG:-$root/../Solveig}

[ -x "$sol/bin/solas" ] || { echo "  --    needs Solveig, which is not here"; exit 0; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
run() { perl -e 'alarm 30; exec @ARGV' "$sol/bin/solvm" "$1" 2>&1 </dev/null | sed 's/\[[^]]*\]/[at]/'; }

same=0; differ=0; included=0; unsteady=0
for f in "$sol"/examples/*.sol "$sol"/programs/*.sol "$sol"/lib/*.sol "$here"/conformance/*.sol; do
    [ -f "$f" ] || continue
    "$sol/bin/solas" "$f" -o "$tmp/oracle.sob" >/dev/null 2>&1 || continue

    want=$(cd "$(dirname "$f")" && run "$tmp/oracle.sob")
    again=$(cd "$(dirname "$f")" && run "$tmp/oracle.sob")
    [ "$want" = "$again" ] || { unsteady=$((unsteady+1)); continue; }

    if ! "$phx" --raw --driver sob "$desc" "$f" > "$tmp/mine.sob" 2>"$tmp/err"; then
        if grep -q '@include' "$tmp/err"; then included=$((included+1)); continue; fi
        differ=$((differ+1)); echo "  refused: $f"
        sed 's/^/      /' "$tmp/err" | head -2; continue
    fi

    mine=$(cd "$(dirname "$f")" && run "$tmp/mine.sob")
    if [ "$mine" = "$want" ]; then same=$((same+1))
    else
        differ=$((differ+1)); echo "  differs: $f"
        printf '%s\n' "$want" > "$tmp/want"; printf '%s\n' "$mine" > "$tmp/mine"
        diff "$tmp/want" "$tmp/mine" | head -6 | sed 's/^/      /'
    fi
done

printf '%d programs run the same compiled either way, %d do not' "$same" "$differ"
printf ' (%d use @include, %d do not repeat themselves)\n' "$included" "$unsteady"
[ "$differ" -eq 0 ]
