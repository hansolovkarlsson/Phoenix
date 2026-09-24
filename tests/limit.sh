# tests/limit.sh -- sourced by every harness, after it has set $root.
#
#   bounded program [argument ...]
#
# runs the program under bin/limit, which stops it when it has run PHX_LIMIT
# seconds, 20 unless that is set, or has written 16 MB, and then exits 124
# with a sentence beginning `did not finish` on standard error. See
# tests/limit.c for why, and for what it passes through.
#
# What goes through it is everything a harness runs that the tree can break:
# `phx`, every program `phx` or `cc` has just made, and the interpreters,
# `awk` and `solvm`, running something `phx` wrote or rendered. The compilers
# the oracles are, `cc`, `fpc`, `solas` and `z80asm`, do not, because nothing
# here can make one of them loop; a harness is itself run under a longer limit
# by tests/run.sh, which covers them too.

limit="$root/bin/limit"
if [ ! -x "$limit" ]; then
    echo "no $limit: run make first"
    exit 1
fi

bounded() { "$limit" "${PHX_LIMIT:-20}" "$@"; }
