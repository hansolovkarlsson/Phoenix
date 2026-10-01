int printf(const char *format, ...);
typedef int binop(int, int);
typedef int (*binop_p)(int, int);
struct pair { int a; int b; };
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
long widen(long x) { return x * 4294967296L; }
char *skip(char *s) { return s + 1; }
struct pair make(int a, int b) { struct pair p; p.a = a; p.b = b; return p; }
void bump(int *p) { *p += 1; }
binop_p pick(int which) { return which ? add : sub; }
int (*pick2(int which))(int, int) { return which ? sub : add; }
int main(void) {
    binop *f = add;
    long (*w)(long) = widen;
    char *(*g)(char *) = skip;
    struct pair (*m)(int, int) = make;
    void (*v)(int *) = bump;
    int (*pf)(const char *, ...) = printf;
    int n = 1;
    v(&n);
    int k = -1;
    pf("%d %d %d %s %d\n", f(2, 3), pick(1)(10, 4), pick2(1)(10, 4), g("xhello"), m(3, 4).b);
    pf("%ld %d %d\n", w(k), (int)sizeof w, n);
    binop_p back = (binop_p)sub;
    return back(9, 2);
}
