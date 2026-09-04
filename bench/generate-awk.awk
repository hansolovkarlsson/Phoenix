# generate-awk.awk -- awk of a given size and shape, for measuring with.
#
#   awk -v n=100 -v shape=width -f bench/generate-awk.awk
#
# awk is the grammar that ought to break a PEG: fourteen rungs from `expr` down
# to `primary`, concatenation with no operator, and a `print` whose arguments
# need six of those rungs duplicated. Two shapes are enough to see the curve.
#
#   width   n statements one after another
#   expr    one n-term expression -- a long climb down the ladder, n times
#
# The sizes are smaller than Pascal's because the constant is a hundred times
# larger; the question is the shape of the curve, and it is visible either way.

BEGIN {
    printf "BEGIN {\n"

    if (shape == "width") {
        for (i = 0; i < n; i++) printf "  x = x + 1\n"
        printf "  print x\n"

    } else if (shape == "expr") {
        printf "  x = 0"
        for (i = 0; i < n; i++) printf " + %d", i % 7 + 1
        printf "\n  print x\n"
    }

    printf "}\n"
}
