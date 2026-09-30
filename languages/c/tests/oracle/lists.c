int printf(char *format, ...);
struct rec { int x, y, *p; char name[4], c; long total; };
typedef int I, *IP;
extern int seen;
int seen;
int a[2], b = 3, *c = &b;
int seen = 9;
extern int later(int);
static long kept, many[3], plenty = 7;
int count(void) { static int n = 1, m[2]; n += 1; m[1] += n; return m[1]; }
int later(int x) { return x + 1; }
int again(void) {
    extern int a[2];
    int n = 0;
    for (int k = 0; k < 3; k++) n += k;
    int k = 10;
    for (int I = 0; I < 2; I++) n += I;
    I after = 5;
    return n + k + after + a[1];
}
int main(void) {
    struct rec r;
    I i = 4, *ip = &i;
    IP q = &b, *qq = &q;
    int total = 0;
    int s = 0, t, *u = &s;
    extern int seen;
    r.x = 1; r.y = 2; r.p = &r.x; r.name[1] = 'n'; r.c = 'c'; r.total = 10;
    a[0] = 5; a[1] = 6; kept = 8; many[2] = 11;
    for (int k = 0, *pk = &k; k < 4; k++) total += *pk + k;
    for (long m = 3; m > 0; m--) { int inner = (int)m, dup = 2; s += inner * dup; }
    t = count(); t = count();
    printf("%d %d %d %c %c %ld\n", r.x, r.y, *r.p, r.name[1], r.c, r.total);
    printf("%d %d %d %d %d %d %d\n", i, *ip, *q, **qq, a[0] + a[1], b, *c);
    printf("%d %d %d %d %ld %ld %ld\n", seen, total, s, t, kept, many[2], plenty);
    printf("%d %lu %lu %d\n", later(*u), sizeof(struct rec), sizeof(IP), again());
    return seen + t;
}
