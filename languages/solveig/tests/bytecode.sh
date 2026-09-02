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
# **Locations in a traceback are compared, not normalised.** They used to be
# thrown away, because this backend wrote one line run for a whole chunk and no
# file table: every message said `[line 1]`. `%include` gave a chunk more than
# one file to be about and `$pos` gave a clause the position it needed, so the
# line table is now a run per statement and the file table is written whenever
# a chunk is about one file. Sixty-six programs agree on every byte of their
# output, tracebacks included.
#
# What is still counted apart is one missing optimisation seen three ways, and
# none of the three is a disagreement about what a program *means*:
#
#   - **where a traceback points.** `solas` *inlines* the block of an
#     `ifTrue:`, a `whileTrue:`, an `and:` and an `or:`; this backend compiles
#     every block as a block. So a frame `solas` puts at the send inside the
#     block, this one puts at the statement the block is written in, and adds a
#     frame `solas` has not got. A run where **every** differing line is a
#     traceback line is counted here; anything else is a failure.
#
#     Six of those also lose the file name, and that is a second reason rather
#     than the same one: a chunk holding code from two files would need a run
#     per statement naming a row of a table of the distinct files, and the
#     notation cannot compute a value per element of a list. The format's own
#     answer for that is no file table and a bare line, which is what is
#     written -- see ROADMAP 1.3 and 2.4.
#
#   - **the format's nesting limit.** `programs/pascal.sol` nests blocks 19
#     deep and `.sob` allows 16. `solas` inlines its way under; this backend
#     cannot, and the loader refuses what it writes.
#
#   - **the call depth.** `programs/basic.sol` is a BASIC interpreter whose own
#     suite calls something recursive until the machine stops it and prints
#     what happened. One extra frame per level stops it a test earlier.
#
#   - **a file that does not print the same thing twice under `solas`**,
#     which is a program that reads the clock or the file system rather than
#     a disagreement about what it compiles to
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

# Whether every line the two disagree about is a **traceback line** -- a frame,
# which is the one thing a block that was not inlined moves. A program that
# printed something different is not this and is a failure.
only_traceback() {
    printf '%s\n' "$1" > "$tmp/a"
    printf '%s\n' "$2" > "$tmp/b"
    diff "$tmp/a" "$tmp/b" | grep '^[<>]' > "$tmp/d"
    [ -s "$tmp/d" ] || return 1
    grep -qv '^[<>] *\[[^]]*\] in ' "$tmp/d" && return 1
    return 0
}

# Whether they differ only in that one of them ran out of call depth -- the
# same missing optimisation arriving as output rather than as a frame. Every
# line this backend produced that the oracle did not has to be that one
# message, and the two have to be the same length: a program that printed
# *fewer* lines is a real difference and not this.
only_depth() {
    printf '%s\n' "$1" > "$tmp/a"
    printf '%s\n' "$2" > "$tmp/b"
    [ "$(wc -l < "$tmp/a")" = "$(wc -l < "$tmp/b")" ] || return 1
    diff "$tmp/a" "$tmp/b" | grep '^>' > "$tmp/added"
    [ -s "$tmp/added" ] || return 1
    grep -qv '^> call depth exceeded$' "$tmp/added" && return 1
    return 0
}

same=0; differ=0; uninlined=0; framed=0; unsteady=0
for f in "$sol"/examples/*.sol "$sol"/programs/*.sol "$sol"/lib/*.sol "$here"/conformance/*.sol; do
    [ -f "$f" ] || continue
    "$sol/bin/solas" "$f" -o "$tmp/oracle.sob" >/dev/null 2>&1 || continue

    name=$(basename "$f" .sol)
    want=$(run "$tmp/oracle.sob" "$name.oracle")

    if ! "$phx" --raw --driver sob "$desc" -I "$sol/lib" "$f" > "$tmp/mine.sob" 2>"$tmp/err"; then
        differ=$((differ+1)); echo "  refused: $f"
        sed 's/^/      /' "$tmp/err" | head -2; continue
    fi

    mine=$(run "$tmp/mine.sob" "$name.mine")

    # The oracle again, **after** this backend's run rather than before it, so
    # that the two bracket it. `programs/diff.sol` prints a file's timestamp to
    # the second, and two oracle runs back to back nearly always agree while
    # the third, a moment later, does not -- which read as a disagreement about
    # compiling and was a disagreement about what time it was.
    again=$(run "$tmp/oracle.sob" "$name.again")
    [ "$want" = "$again" ] || { unsteady=$((unsteady+1)); continue; }

    if [ "$mine" = "$want" ]; then same=$((same+1)); continue; fi

    # The three shapes of the one missing optimisation, counted apart.
    case "$mine" in
      *"nested deeper than the format allows"*)
          uninlined=$((uninlined+1)); continue;;
    esac
    if only_traceback "$want" "$mine"; then framed=$((framed+1)); continue; fi
    if only_depth     "$want" "$mine"; then uninlined=$((uninlined+1)); continue; fi

    differ=$((differ+1)); echo "  differs: $f"
    printf '%s\n' "$want" > "$tmp/want"; printf '%s\n' "$mine" > "$tmp/mine"
    diff "$tmp/want" "$tmp/mine" | head -6 | sed 's/^/      /'
done

# Keep only the directories a program actually wrote something into.
find "$out/run" -type d -empty -delete 2>/dev/null
rm -rf "$tmp"
[ -d "$out/run" ] && printf '  (programs that wrote files left them in build/oracle/run/)\n'

printf '%d programs print exactly what solas compiled prints, %d do not' "$same" "$differ"
printf ' (%d differ only in a traceback, %d nest a block solas inlines,' "$framed" "$uninlined"
printf ' %d do not repeat themselves)\n' "$unsteady"
[ "$differ" -eq 0 ]
