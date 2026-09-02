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
#
# **Nothing here writes outside Phoenix.** The Solveig checkout is a resource
# that happens to be on the same computer: it is read, and its `solas` and
# `solvm` are run, and that is all. So every program under test runs with its
# working directory in `build/oracle/` here, never beside the source -- a
# program that writes a relative path (`examples/files.sol` writes
# `build/example-notes.txt`) then writes into this repository, where it
# belongs, instead of into somebody else's.
#
# Each run gets its **own empty directory**, which the sharing of one
# directory was quietly getting wrong as well: two compilers writing the same
# file in turn is not two independent runs, and a program that writes and
# reads back would have been comparing the second run against the first run's
# leavings. The directories that stay behind are the ones something wrote
# into, which is the evidence worth keeping; the empty ones are removed.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/../../.." && pwd)
phx="$root/bin/phx"
desc="$root/languages/solveig/solveig-sob.phx"
sol=${SOLVEIG:-$root/../Solveig}

[ -x "$sol/bin/solas" ] || { echo "  --    needs Solveig, which is not here"; exit 0; }

out="$root/build/oracle"
rm -rf "$out"; mkdir -p "$out"
tmp="$out/tmp"; mkdir -p "$tmp"

# Run one chunk in a directory of its own, and answer what it printed.
run() {
    sandbox="$out/run/$2"
    mkdir -p "$sandbox"
    ( cd "$sandbox" && perl -e 'alarm 30; exec @ARGV' "$sol/bin/solvm" "$1" 2>&1 </dev/null ) \
        | sed 's/\[[^]]*\]/[at]/'
}

same=0; differ=0; included=0; unsteady=0
for f in "$sol"/examples/*.sol "$sol"/programs/*.sol "$sol"/lib/*.sol "$here"/conformance/*.sol; do
    [ -f "$f" ] || continue
    "$sol/bin/solas" "$f" -o "$tmp/oracle.sob" >/dev/null 2>&1 || continue

    name=$(basename "$f" .sol)
    want=$(run "$tmp/oracle.sob" "$name.oracle")
    again=$(run "$tmp/oracle.sob" "$name.again")
    [ "$want" = "$again" ] || { unsteady=$((unsteady+1)); continue; }

    if ! "$phx" --raw --driver sob "$desc" "$f" > "$tmp/mine.sob" 2>"$tmp/err"; then
        if grep -q '@include' "$tmp/err"; then included=$((included+1)); continue; fi
        differ=$((differ+1)); echo "  refused: $f"
        sed 's/^/      /' "$tmp/err" | head -2; continue
    fi

    mine=$(run "$tmp/mine.sob" "$name.mine")
    if [ "$mine" = "$want" ]; then same=$((same+1))
    else
        differ=$((differ+1)); echo "  differs: $f"
        printf '%s\n' "$want" > "$tmp/want"; printf '%s\n' "$mine" > "$tmp/mine"
        diff "$tmp/want" "$tmp/mine" | head -6 | sed 's/^/      /'
    fi
done

# Keep only the directories a program actually wrote something into.
find "$out/run" -type d -empty -delete 2>/dev/null
rm -rf "$tmp"
[ -d "$out/run" ] && printf '  (programs that wrote files left them in build/oracle/run/)\n'

printf '%d programs run the same compiled either way, %d do not' "$same" "$differ"
printf ' (%d use @include, %d do not repeat themselves)\n' "$included" "$unsteady"
[ "$differ" -eq 0 ]
