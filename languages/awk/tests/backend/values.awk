# The value model, which is the whole of stage one.
BEGIN {
    print (x == 0), (x == ""), (x < 1)
    n = 10; s = "10"
    print (n == s), (n == 10), (s == "10")
    print 1, 1.0, 1.5, -0.0, 100000, 1000000, 0.000001
    print 1/3
    print "" 1, "" 1.5, "" 100000
}
