/* A name in parentheses is the name, C11 6.7.6p6: in a global, an
 * array, a static, a member, a typedef, a local and a static local,
 * inside a pointer's parentheses too, and in scope in its own
 * initialiser as any name is. A typedef's name is hidden by one. */
int printf(const char *, ...);
typedef int T;
int (g) = 4;
int ((h))[2] = { 5, 6 };
static long (s);
struct pt { int (a); char *(b); int (*(c))[2]; };
typedef long (L);
int main(void) {
    int (x) = 3;
    int ((y));
    y = x;
    int *(p) = &x;
    int (*(q)) = &y;
    int (a)[2] = { 1, 2 };
    int (*(r))[2] = &a;
    static int (st) = 9;
    T (T) = sizeof(T);
    L (z) = sizeof (z);
    int (self) = sizeof self;
    struct pt (v) = { 7, "hi", &a };
    printf("%d %d %d %d %d %d %d %d %ld %d\n", x, y, g, *p, *q, a[1], (*r)[0], st, (long)s, T);
    printf("%d %d %d %ld %d %d %s %d\n", h[0], h[1], (int)z, (long)sizeof(L), self, v.a, v.b, (*v.c)[1]);
    return x + y;
}
