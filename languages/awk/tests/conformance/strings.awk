# The string builtins, and concatenation, which has no operator.
BEGIN {
    s = "hello world"
    print length(s), length
    print substr(s, 1, 5)
    print index(s, "world")
    print toupper(s), tolower("ABC")
    n = split(s, parts, " ")
    print n, parts[1], parts[2]
    t = s
    sub(/world/, "there", t)
    print t
    u = "aaa"
    gsub(/a/, "b", u)
    print u
    print match(s, /wor/), RSTART, RLENGTH
    print sprintf("%s-%d", "x", 7)
    print "a" "b" 1 + 1
}
