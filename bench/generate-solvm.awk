# generate-solvm.awk -- SolVM assembly of a given size and shape.
#
#   awk -v n=100 -v shape=width -f bench/generate-solvm.awk
#
# The point of measuring this grammar is that it is the opposite extreme from
# awk's. There is no expression ladder at all -- an instruction is a mnemonic
# and its operands, and which rule matches is settled by the first token. If
# ordered choice is what costs, this is where it should cost least.
#
#   width    n instructions one after another -- the ordinary case
#   labels   n labels, each jumped to from above -- the gathered table
#   blocks   n nested .block definitions -- recursion depth in the grammar.
#            Past 16 this is not a *loadable* program, since SolVM follows at
#            most 16 frames, but the assembler's checks are in a later pass and
#            what is being measured here is the matcher. `--tree` parses it.

BEGIN {
    if (shape == "width") {
        printf ".slots 1\n"
        for (i = 0; i < n; i++) printf "        const   #%d\n        pop\n", i % 9 + 1
        printf "        halt\n"

    } else if (shape == "labels") {
        printf ".slots 1\n"
        for (i = 0; i < n; i++) {
            printf "        global  x\n"
            printf "        jumpf   l%d, ifTrue\n", i
            printf "l%d:\n", i
        }
        printf "        halt\n"

    } else if (shape == "blocks") {
        printf ".slots self\n        block   b0\n        send    value, 0\n"
        printf "        pop\n        halt\n\n"
        for (i = 0; i < n; i++) printf ".block b%d arity 0 slots self\n", i
        printf "        nil\n        return\n"
        for (i = n - 1; i >= 0; i--) printf ".end\n"
    }
}
