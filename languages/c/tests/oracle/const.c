int printf(char *format, ...);
typedef const char *text;
struct point { const int x; int y; };
const int limit = 3;
int const answer = 42;
const char *const greeting = "hello";
int length(const char *s) { const char *p = s; while (*p) p++; return p - s; }
int total(const int *v, const int n) { int i; int t = 0; for (i = 0; i < n; i++) t += v[i]; return t; }
const int *pick(const int *a, const int *b) { return *a > *b ? a : b; }
const char *label(int n) { return n ? "yes" : "no"; }
int zeros(void) { static const int none[2]; return none[1]; }
int main(void) {
    const int local = 5;
    int values[3];
    int *const fixed = values;
    const int *walk = values;
    text t = "four";
    struct point pt;
    const struct point *pp = &pt;
    const long big = 9000000000;
    const text u = "seven";
    const const int twice = 2;
    values[0] = 1; values[1] = 2; values[2] = local;
    *fixed = 10;
    walk++;
    pt.y = 7;
    printf("%d %d %d %d\n", length(greeting), length(t), total(values, limit), *walk);
    printf("%d %d %ld %d\n", *pick(&values[1], &values[2]), pp->y, big / 1000, (int)sizeof(const int));
    printf("%d %d\n", answer, (int)sizeof(const char *const));
    printf("%d %d %s %d\n", length(u), twice, label(0), zeros());
    return answer - local * 8 + (const int)1;
}
