int printf(const char *format, ...);
enum flags { BOL = 1u << 0, SPACE = 1u << 1, BOTH = BOL | SPACE, HIGH = 0x80000000u >> 31 };
enum tests { LT = 1 < 2, GE = 'a' >= 'b', EQ = BOTH == 3, NE = -1 != -1, ULT = 1u > 0, SLT = -1 < 0,
             L2 = 2 < 2, LE2 = 2 <= 2, G2 = 2 > 2, GE2 = 2 >= 2, EQ2 = 2 == 3 };
enum logic { NOT = !0 + !7, AND = 1 && 0, OR = 0 || 3, NEST = !(LT && !GE) };
enum pick { P = LT ? 10 : 20, Q = GE ? -1 : -2, R = 0 ? -1 : 5u, S = (BOTH > 2 ? 100 : 200) + 1 };
int main(void) {
    char *p = 0, *q = 1 ? 0 : 0;
    printf("%d %d %d %d\n", BOL, SPACE, BOTH, HIGH);
    printf("%d %d %d %d %d %d\n", LT, GE, EQ, NE, ULT, SLT);
    printf("%d %d %d %d %d\n", L2, LE2, G2, GE2, EQ2);
    printf("%d %d %d %d\n", NOT, AND, OR, NEST);
    printf("%d %d %d %d\n", P, Q, R, S);
    return (p == q) + S;
}
