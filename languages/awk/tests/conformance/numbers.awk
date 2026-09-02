# Arithmetic, including the two things awk gets from C and the one it does not.
BEGIN {
    print 1 + 2 * 3
    print (1 + 2) * 3
    print 7 / 2
    print 7 % 3
    print 2 ^ 10
    print -2 ^ 2
    print int(3.7), int(-3.7)
    x = 5; x += 2; x -= 1; x *= 3; x /= 2; x %= 5
    print x
    i = 1
    print i++, i, ++i, i
    print (1 < 2), (2 < 1), ("a" < "b")
    print 1 && 1, 1 && 0, 0 || 1, !0
}
