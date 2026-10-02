int printf(const char *format, ...);
void *malloc(unsigned long n);
typedef char T;
struct node { long value; struct node *next; };
int main(void) {
    int x = sizeof(x);
    long y = sizeof y + 1;
    int x2 = 1, y2 = sizeof y2 + x2;
    int T = sizeof(T);
    struct node *n = malloc(sizeof *n);
    char **pp = malloc(4 * sizeof *pp);
    const char *s = sizeof *s == 1 ? "one" : "more";
    void *self = &self;
    int *r = ((void)&r, (int[]){3, 4});
    void *where = 0;
    int *r2 = (where = &r2, (int[]){5, 6});
    int after = 9;
    int sum = 0;
    for (int i = sizeof i; i < 8; i++) sum += i;
    n->value = sizeof *n;
    pp[3] = "pp";
    printf("%d %ld %d %ld %s %s\n", x, y, T, n->value, pp[3], s);
    printf("%d %d %d %d %d\n", self == (void *)&self, r[0] + r[1], (void *)r != (void *)&r, after, sum);
    printf("%d %d %d\n", where == (void *)&r2, r2[0], r2[1]);
    return x + T + y2;
}
