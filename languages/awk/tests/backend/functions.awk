# Called above where it is defined, recursive, with locals and an array by
# reference -- which is all four things awk functions do.
BEGIN {
    print greet("world")
    print depth(4)
    fill(box); print box["k"], box["n"]
    print add(1), add(1, 2)
}
function greet(who,   prefix) { prefix = "hello, "; return prefix who }
function depth(n) { if (n <= 0) return 0; return 1 + depth(n - 1) }
function fill(a) { a["k"] = "filled"; a["n"] = 7 }
function add(x, y) { return x + y }
