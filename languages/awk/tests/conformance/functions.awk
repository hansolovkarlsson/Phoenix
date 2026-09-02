# A function called above where it is defined, which is the whole reason awk
# is here: no declaration, and the call is resolved by name at run time.
BEGIN {
    print greet("world")
    print twice(21)
    print depth(4)
}

function greet(who,   prefix) {
    prefix = "hello, "
    return prefix who
}

function twice(x) { return x + x }

function depth(n) {
    if (n <= 0) return 0
    return 1 + depth(n - 1)
}
