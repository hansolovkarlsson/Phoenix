# Associative arrays, for-in with a sorted walk, and delete.
BEGIN {
    n["one"] = 1; n["two"] = 2; n["three"] = 3
    total = 0
    for (k in n) total += n[k]
    print "total", total
    delete n["two"]
    count = 0
    for (k in n) count++
    print "left", count
    delete n
    count = 0
    for (k in n) count++
    print "empty", count
}
