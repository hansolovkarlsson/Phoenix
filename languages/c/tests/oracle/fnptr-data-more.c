int printf(const char *format, ...);
int twice(int x) { return 2 * x; }
int square(int x) { return x * x; }
int negate(int x) { return -x; }
struct named { const char *name; int (*fn)(int); };
struct holder { int tag; struct named inner; };
int (*gop)(int) = twice;
int (*gaddr)(int) = &square;
int (*gnone)(int) = 0;
int (*gstar)(int) = *twice;
int (*gstars[1])(int) = {**square};
int (*ops[])(int) = {twice, square, negate, 0};
int (*back[3])(int) = {[2] = twice, [0] = square};
struct named single = {.fn = negate, .name = "neg"};
struct named list[] = {{"twice", twice}, {"square", square}, {0, 0}};
struct holder held = {7, {"held", square}};
int (*say)(const char *, ...) = printf;
static int run(const struct named *t, int x) {
    int r = 0;
    for (; t->fn; t++) r = r * 100 + t->fn(x);
    return r;
}
int main(void) {
    static int (*kept)(int) = square;
    struct named local = {"local", twice};
    struct named both[2] = {[1].fn = negate, [0] = {"a", twice}};
    int n = 0;
    for (int i = 0; ops[i]; i++) n = n * 100 + ops[i](i + 3);
    printf("%d %d %d %d\n", gop(5), gaddr(5), gnone == 0, n);
    printf("%d %d %d %s\n", back[0](4), back[1] == 0, back[2](4), single.name);
    printf("%d %d %d %d\n", single.fn(8), run(list, 3), held.inner.fn(held.tag), kept(6));
    printf("%d %d %d %d\n", local.fn(9), both[0].fn(1), both[1].fn(2), say == printf);
    printf("%d %d\n", gstar(10), gstars[0](10));
    return list[1].fn(2) + (both[1].name == 0);
}
