#!/bin/sh
# languages/solveig/tests/bytecode.sh -- the .sob backend, against solas.
#
# **The oracle is the real compiler.** Every `.sol` file in the Solveig
# repository is compiled twice -- once by `solas`, once by `solveig-sob.phx` --
# and both `.sob` files are run by `solvm`. What they print must agree.
#
# `@include` is compiled now, which is what `%include` in `solveig.phx` bought:
# the file is read and its statements take the directive's place before the
# first pass, so the backend needs no clause for one and never sees one. The
# library those files include lives in `lib/` beside the Solveig binaries, so
# `-I` says where -- the same thing `bin/solas` does with `bin/../lib`.
#
# **Nothing is normalised, and nothing is counted apart.** A traceback names a
# file and a line, and those are compared like any other byte. They used to be
# thrown away, because this backend wrote one line run for a whole chunk and no
# file table: every message said `[line 1]`. Four stages closed that --
# `%include` gave a chunk more than one file to be about, `$pos` gave a clause
# the position it needed, `%rewrite inline` made the frames agree, `otherwise`
# gave every node a line run and a row in its chunk's file table, and
# `$pos.endline` put a send's own bytes where `solas` puts them, after its
# arguments.
#
# So the only thing counted apart is **a program that does not print the same
# thing twice under `solas`** -- one that reads the clock or the file system,
# which is not a disagreement about compiling. Everything else is a failure.
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

# Run one chunk in a directory of its own, and answer what it printed --
# exactly what it printed, with nothing normalised away.
run() {
    sandbox="$out/run/$2"
    mkdir -p "$sandbox"
    ( cd "$sandbox" && perl -e 'alarm 30; exec @ARGV' "$sol/bin/solvm" "$1" 2>&1 </dev/null )
}

# And what it printed under `--trace`, which is where the **slot names** show:
# a call is written `value(e: #1)` rather than `value(#1)` when the chunk
# remembers what the parameter was called. Nothing else compares those, and a
# wrong slot-name table changes no instruction -- so the byte-for-byte
# comparison above cannot see one at all.
#
# The `[file:line]` prefix comes off because `--trace` writes the path it was
# given, and the two compilers are given different ones. Everything after it is
# compared as it stands.
trace() {
    sandbox="$out/run/$2"
    mkdir -p "$sandbox"
    ( cd "$sandbox" \
      && LC_ALL=C perl -e 'alarm 30; exec @ARGV' "$sol/bin/solvm" --trace "$1" 2>&1 </dev/null ) \
    | LC_ALL=C sed -E 's/\[[^]]*\] //'
}


same=0; differ=0; unsteady=0
tsame=0; tdiffer=0; tunsteady=0
for f in "$sol"/examples/*.sol "$sol"/programs/*.sol "$sol"/lib/*.sol "$here"/conformance/*.sol; do
    [ -f "$f" ] || continue
    "$sol/bin/solas" "$f" -o "$tmp/oracle.sob" >/dev/null 2>&1 || continue

    name=$(basename "$f" .sol)
    want=$(run "$tmp/oracle.sob" "$name.oracle")

    if ! "$phx" --raw --driver sob "$desc" -I "$sol/lib" "$f" > "$tmp/mine.sob" 2>"$tmp/err"; then
        differ=$((differ+1)); echo "  refused: $f"
        sed 's/^/      /' "$tmp/err" | head -2; continue
    fi

    # The traces, held to the same rule as the output below: they differ, or
    # the program does not repeat itself. An object's address is printed as it
    # is and no two runs agree about one, which is what puts a third of the
    # corpus in the unsteady column here and almost none of it there.
    twant=$(trace "$tmp/oracle.sob" "$name.trace-oracle")
    tmine=$(trace "$tmp/mine.sob" "$name.trace-mine")
    if [ "$twant" = "$tmine" ]; then
        tsame=$((tsame+1))
    elif [ "$twant" != "$(trace "$tmp/oracle.sob" "$name.trace-again")" ]; then
        tunsteady=$((tunsteady+1))
    else
        tdiffer=$((tdiffer+1)); echo "  traces differ: $f"
        printf '%s\n' "$twant" > "$tmp/tw"; printf '%s\n' "$tmine" > "$tmp/tm"
        diff "$tmp/tw" "$tmp/tm" | head -6 | sed 's/^/      /'
    fi

    mine=$(run "$tmp/mine.sob" "$name.mine")
    if [ "$mine" = "$want" ]; then same=$((same+1)); continue; fi

    # They differ, and **a program that does not repeat itself is the first
    # explanation to rule out**: `programs/diff.sol` prints a file's timestamp
    # to the second and `programs/system.sol` prints how long a loop took, so
    # two runs a moment apart disagree about neither compiler. Both are asked
    # again, which is two extra runs on the few that got here rather than on
    # all of them.
    again=$(run "$tmp/oracle.sob" "$name.again")
    mine2=$(run "$tmp/mine.sob" "$name.mine-again")
    if [ "$want" != "$again" ] || [ "$mine" != "$mine2" ]; then
        unsteady=$((unsteady+1)); continue
    fi

    differ=$((differ+1)); echo "  differs: $f"
    printf '%s\n' "$want" > "$tmp/want"; printf '%s\n' "$mine" > "$tmp/mine"
    diff "$tmp/want" "$tmp/mine" | head -6 | sed 's/^/      /'
done

# Keep only the directories a program actually wrote something into.
find "$out/run" -type d -empty -delete 2>/dev/null
rm -rf "$tmp"
[ -d "$out/run" ] && printf '  (programs that wrote files left them in build/oracle/run/)\n'

printf '%d programs print exactly what solas compiled prints, %d do not' "$same" "$differ"
printf ' (%d do not repeat themselves)\n' "$unsteady"
printf '  and %d trace identically, argument names included, %d do not' "$tsame" "$tdiffer"
printf ' (%d do not repeat themselves)\n' "$tunsteady"
[ "$differ" -eq 0 ] && [ "$tdiffer" -eq 0 ]
