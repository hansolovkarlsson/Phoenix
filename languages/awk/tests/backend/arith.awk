# Arithmetic, the assignment operators, and the two steps.
BEGIN {
    print 1 + 2 * 3, (1 + 2) * 3, 7 / 2, 7 % 3, 2 ^ 10
    print -2 ^ 2, - (2 ^ 2), (-2) ^ 2
    print int(3.7), int(-3.7), int("12abc")
    x = 5; x += 2; x -= 1; x *= 3; x /= 2; x %= 5; x ^= 2
    print x
    i = 1
    print i++, i, ++i, i, i--, i, --i, i
    print 1 && 1, 1 && 0, 0 || 1, !0, !1, !""
    print (1 < 2), (2 <= 2), (3 > 4), (4 >= 4), (5 == 5), (6 != 6)
}
