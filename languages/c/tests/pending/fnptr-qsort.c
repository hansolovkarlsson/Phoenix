int printf(const char *format, ...);
void qsort(void *base, unsigned long count, unsigned long size, int (*compare)(const void *, const void *));
struct entry { int key; const char *word; };
static int by_value(const void *a, const void *b) {
    const int *x = a;
    const int *y = b;
    return *x - *y;
}
static int by_key_down(const void *a, const void *b) {
    const struct entry *x = a;
    const struct entry *y = b;
    return y->key - x->key;
}
int main(void) {
    int v[6] = {5, 3, 9, 1, 7, 2};
    struct entry e[3] = {{2, "two"}, {9, "nine"}, {4, "four"}};
    qsort(v, 6, sizeof v[0], by_value);
    qsort(e, 3, sizeof e[0], &by_key_down);
    printf("%d %d %d %d %d %d\n", v[0], v[1], v[2], v[3], v[4], v[5]);
    printf("%s %s %s\n", e[0].word, e[1].word, e[2].word);
    return v[5];
}
