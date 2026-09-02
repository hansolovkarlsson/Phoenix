# `/ +/` -- a regular expression that begins with a space.
#
# The guess in `awk.phx` is that the character after a `/` is not a space, a
# tab or an `=`, because `a / b` is division and `/^x/` is a regexp and nothing
# else can tell them apart without a parser. A regexp that *starts* with a
# space is the price, and this is one: `split($0, parts, / +/)` is ordinary awk
# and will not parse here.
#
# It has a way out that costs nothing -- `" +"` is a string used as a regexp,
# which awk allows everywhere a literal is allowed -- so this is a limit rather
# than a wall. Found by writing a conformance program, not by thinking about
# it, which is why it is checked in.
BEGIN { n = split("a  b", parts, / +/); print n }
