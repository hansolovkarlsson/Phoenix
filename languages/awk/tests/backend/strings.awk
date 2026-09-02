# The string and number builtins.
BEGIN {
    s = "hello world"
    print length(s), substr(s, 1, 5), substr(s, 7)
    print index(s, "world"), index(s, "zz")
    print toupper(s), tolower("ABC")
    print sprintf("%s-%d-%.2f", "x", 7, 1.5)
    n = split(s, w, " "); print n, w[1], w[2]
    print int(sqrt(16)), int(exp(0)), int(log(1)), int(atan2(0, 1))
    srand(1); x = rand(); print (x >= 0 && x < 1)
    print substr("abc", 0, 2), substr("abc", 2, 99), substr("abc", 5)
}
