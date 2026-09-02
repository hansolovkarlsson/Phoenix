# awk: `function g called with 2 args, uses only 1`. Fewer than the parameters
# is allowed and is how awk says local; more is a mistake.
function g(x) { return x }
BEGIN { print g(1, 2) }
