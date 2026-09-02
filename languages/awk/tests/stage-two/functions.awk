# Valid awk, and not stage one: a call frame, parameters that are locals, and
# recursion.
function f(x) { return x + 1 }
BEGIN { print f(1) }
