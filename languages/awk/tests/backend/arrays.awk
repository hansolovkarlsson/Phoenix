# awk's one aggregate: a hash from strings, subscripted into existence.
BEGIN {
    n["one"] = 1; n["two"] = 2; n["three"] = 3
    total = 0
    for (k in n) total += n[k]
    print "total", total, length("x")
    print ("two" in n), ("four" in n)
    delete n["two"]
    c = 0; for (k in n) c++
    print "left", c
    delete n
    c = 0; for (k in n) c++
    print "empty", c
    # a subscript with several parts is one key with SUBSEP between them
    g[1, 2] = "a"; g[1, 3] = "b"
    print g[1, 2], g[1, 3], ((1, 2) in g)
}
