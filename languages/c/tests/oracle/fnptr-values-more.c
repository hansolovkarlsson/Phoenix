int printf(const char *format, ...);
void qsort(void *, unsigned long, unsigned long, int (*)(const void *, const void *));
void *bsearch(const void *key, const void *base, unsigned long count, unsigned long size, int (*compare)(const void *, const void *));
typedef int (*cmp_t)(const void *, const void *);
static int up(const void *a, const void *b) { const int *x = a; const int *y = b; return *x - *y; }
static int down(const void *a, const void *b) { return up(b, a); }
cmp_t chosen;
int (*global_cmp)(const void *, const void *);
int sorted(int *v, int n, cmp_t c) { qsort(v, n, sizeof *v, c); return v[0]; }
int main(void) {
    int v[5] = {4, 1, 5, 2, 3};
    int b = 7;
    int (*say)(const char *, ...) = printf;
    int (*both)(int a, int b) = 0;
    cmp_t table[2] = {up, down};
    int (*direct[2])(const void *, const void *);
    direct[0] = down;
    direct[1] = &up;
    static cmp_t kept;
    kept = table[1];
    chosen = *up == up ? up : down;
    global_cmp = (int (*)(const void *, const void *))down;
    int first = sorted(v, 5, chosen);
    int key = 4;
    int *found = bsearch(&key, v, 5, sizeof v[0], up);
    int last = sorted(v, 5, global_cmp);
    printf("%d %d %d %d\n", first, (int)(found - v), last, v[4]);
    printf("%d %d %d %d %d\n", table[0] == up, direct[0] == table[1], kept == down, chosen != 0, (int)sizeof(int (*)(int)));
    cmp_t *pp = &table[1];
    int (**qq)(const void *, const void *) = direct;
    printf("%d %d %d %d %d\n", *pp == down, qq[1] == up, &up == up, say == printf, both == 0 ? b : 0);
    return sorted(v, 5, *pp);
}
