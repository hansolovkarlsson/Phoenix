int printf(char *format, ...);
struct pair { int a; long b; };
struct named { const char *spelling; int code; };
struct box { char tag; int dims[3]; struct pair p; };
static const struct named table[] = {
    {"+", 1}, {"-", 2},
    {"<<", 3}, {">>=", 4},
};
struct pair origin = {3, 4};
struct box global_box = {'g', {1, 2, 3}, {5, 6}};
struct box elided = {'e', 7, 8, 9, 10, 11};
struct pair zeroed = {0};
int count(const struct named *t, int n) { int s = 0; for (int i = 0; i < n; i++) s += t[i].code; return s; }
int main(void) {
    struct pair local = {1, 2};
    struct pair from = {local.a + 10, origin.b * 2};
    struct pair none = {0};
    struct box b = {'b', {4, 5}, {6, 7}};
    struct pair two[2] = {{1, 2}, {3, 4}};
    static struct pair once = {8, 9};
    printf("%d %ld %d %ld %d %ld\n", local.a, local.b, from.a, from.b, none.a, none.b);
    printf("%c %d %d %d %ld %d\n", b.tag, b.dims[1], b.dims[2], b.p.a, b.p.b, two[1].a);
    printf("%c %d %ld %c %d %d %ld %d %ld\n", global_box.tag, global_box.dims[2], global_box.p.b,
           elided.tag, elided.dims[2], elided.p.a, elided.p.b, zeroed.a, zeroed.b);
    printf("%s %d %d %lu %d %ld\n", table[3].spelling, table[2].code, count(table, 4), sizeof table / sizeof table[0], once.a, once.b);
    return local.a + b.dims[0];
}
