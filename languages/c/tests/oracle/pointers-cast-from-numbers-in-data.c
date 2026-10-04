/* An integer cast to a pointer is an address constant, C11 6.6p9, so a
 * global, a static and a member in braces may be one, 0 cast to void *
 * among them, and a pointer to a function too. Each is the number. */
int printf(const char *, ...);
struct s { int a; char *n; int *m; };
int g = 7;
int *p = (void *)0;
char *c = (char *)0;
long *w = (long *)4294967304;
int *u = (int *)(1u - 2);
int *neg = (int *)-8;
int (*fp)(void) = (void *)0;
int *t[3] = { (void *)0, &g, (int *)16 };
struct s r = { 5, (char *)0, (void *)0 };
int *pp = (int *)(char *)(void *)32;
int after = 42;
int main(void) {
    static int *q = (void *)0;
    static char *k = (char *)24;
    static int (*sf)(void) = (void *)0;
    printf("%d %d %d %lx %lx %lx %d\n", p == 0, c == 0, fp == 0, (long)w, (long)u, (long)neg, after);
    printf("%d %d %ld %d %d %d %ld %ld\n", t[0] == 0, *t[1], (long)t[2], r.a, r.n == 0, r.m == 0, (long)k, (long)pp);
    return q == 0 && sf == 0 ? 3 : 4;
}
