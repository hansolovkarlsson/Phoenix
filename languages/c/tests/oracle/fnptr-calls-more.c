int printf(const char *format, ...);
struct pair { int a; int b; };
struct big { long v[4]; };
int add(int a, int b) { return a + b; }
long widen(long x) { return x * 4294967296L; }
int area(struct pair p) { return p.a * p.b; }
struct pair make(int a, int b) { struct pair p; p.a = a; p.b = b; return p; }
struct big fill(long k) { struct big g; for (int i = 0; i < 4; i++) g.v[i] = k + i; return g; }
long total(struct big g) { return g.v[0] + g.v[1] + g.v[2] + g.v[3]; }
void bump(int *p) { *p += 1; }
char *skip(char *s) { return s + 1; }
int (*again)(int);
int fact(int n) { return n < 2 ? 1 : n * again(n - 1); }
int main(void) {
    int k = -1;
    long (*w)(long) = widen;
    int (*ar)(struct pair) = area;
    struct pair (*mk)(int, int) = make;
    struct big (*fb)(long) = fill;
    long (*tot)(struct big) = total;
    void (*v)(int *) = bump;
    char *(*g)(char *) = skip;
    int (*op)(int, int) = add;
    int (**pp)(int, int) = &op;
    int (*table[2])(int, int) = {add, add};
    int n = 1;
    v(&n);
    (*v)(&n);
    again = fact;
    printf("%ld %d %d %ld %d\n", w(k), ar(mk(3, 4)), mk(5, 6).b, tot(fb(10)), n);
    printf("%s %d %d %d %d\n", g("xhello"), (*add)(1, 2), (&add)(3, 4), (**pp)(5, 6), (*table[1])(7, 8));
    struct pair kept[2] = {mk(7, 8), {9, 10}};
    struct pair one = mk(11, 12);
    printf("%d %d %d %d\n", op(op(1, 2), op(3, 4)), again(5), kept[0].b + kept[1].a, one.a);
    return fb(1).v[3] + (int)w(0);
}
