# generate.awk -- Pascal of a given size and shape, for measuring with.
#
#   awk -v n=100 -v shape=width -f bench/generate.awk
#
# Four shapes, because a PEG can misbehave on one and not another:
#
#   width   n statements one after another -- the ordinary case
#   expr    one statement with an n-term expression -- a long repetition
#   nest    n nested parentheses -- recursion depth in the matcher
#   blocks  n nested begin/end -- recursion depth in the grammar
#
# What matters is not how long any of these takes but whether the work per
# token stays the same as n grows. A PEG without memoisation is where that
# would stop being true.

BEGIN {
    printf "program Bench(output);\nvar\n  x : integer;\nbegin\n"

    if (shape == "width") {
        for (i = 0; i < n; i++) printf "  x := x + 1;\n"
        printf "  writeln(x)\n"

    } else if (shape == "expr") {
        printf "  x := 0"
        for (i = 0; i < n; i++) printf " + %d", i % 7 + 1
        printf ";\n  writeln(x)\n"

    } else if (shape == "nest") {
        printf "  x := "
        for (i = 0; i < n; i++) printf "("
        printf "1"
        for (i = 0; i < n; i++) printf ")"
        printf ";\n  writeln(x)\n"

    } else if (shape == "blocks") {
        for (i = 0; i < n; i++) printf "  begin\n"
        printf "  x := 1;\n"
        for (i = 0; i < n; i++) printf "  end;\n"
        printf "  writeln(x)\n"
    }

    printf "end.\n"
}
