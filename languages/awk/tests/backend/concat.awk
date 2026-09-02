# Concatenation has no operator, and binds looser than arithmetic.
BEGIN {
    a = "x"; b = 2
    print a b, a b + 1, a "" (b + 1)
    print 1 " " 2
    print "n=" 1 + 1
    print length("hello"), length("")
}
