# The one construct left, and the only one whose *grammar* is the problem
# rather than its runtime.
#
# `getline` has six forms -- plain, `getline var`, `< file`, `var < file`,
# `cmd | getline`, `cmd | getline var` -- and they sit at different rungs of
# the expression ladder, which is why awk's own grammar has a note about it
# and why every awk implementation gets it slightly differently. It appears
# nowhere in the corpus, so it is refused by not being described at all: this
# does not parse.
BEGIN { while ((getline line < "f") > 0) print line }
