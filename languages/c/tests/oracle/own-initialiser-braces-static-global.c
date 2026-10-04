int printf(const char *format, ...);
struct node { void *self; long size; int *more; };
void *g = &g;
long gn = sizeof gn;
struct node gs = { &gs, sizeof gs, 0 };
static struct node hidden = { &hidden, sizeof(hidden) + 1, 0 };
int main(void) {
    int before = 7;
    struct node x = { &x, sizeof x, (int[]){1, 2, 3} };
    struct node y = { &y, sizeof y.size, (int[]){4, 5} };
    static long n = sizeof n;
    static void *sp = &sp;
    static struct node ss = { &ss, sizeof ss, 0 };
    int after = 8;
    printf("%d %ld %d %d %d\n", x.self == (void *)&x, x.size, x.more[0] + x.more[2], before, after);
    printf("%d %ld %d %d\n", y.self == (void *)&y, y.size, y.more[1], y.more != x.more);
    printf("%ld %d %d %ld\n", n, sp == (void *)&sp, ss.self == (void *)&ss, ss.size);
    printf("%d %ld %d %ld %d %ld\n", g == (void *)&g, gn, gs.self == (void *)&gs, gs.size, hidden.self == (void *)&hidden, hidden.size);
    return (int)(x.size + n);
}
