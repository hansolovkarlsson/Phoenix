int printf(const char *format, ...);
static int twice(int a) { return a * 2; }
static int add(int a, int b) { return a + b; }
struct ops { int (*f)(int); };
static int apply(int (*f)(int), int x) { return f ? f(x) : -1; }
static int fold(int (*g)(int, int), int a, int b) { return g(a, b); }
static int (*pick(int which))(int) { if (which) return twice; return (void *)0; }
static int (*none(void))(int) { return 0; }
int main(void) {
    int (*f)(int) = (void *)0;
    struct ops v = {(void *)0};
    printf("%d %d %d\n", apply(twice, 5), apply((void *)0, 5), apply(0, 5));
    printf("%d %d %d\n", fold(add, 3, 4), pick(1)(21), pick(0) == 0);
    f = pick(1);
    printf("%d %d %d\n", f(4), none() == 0, v.f == 0);
    f = (void *)0;
    return apply(f, 1) + 3;
}
