int printf(const char *format, ...);
typedef int binop(int, int);
typedef binop *binop_p;
typedef void handler(int *);
struct pair { int a; int b; };
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
static int mul(int a, int b) { return a * b; }
void bump(int *p) { *p += 10; }
struct pair swap(struct pair p) { struct pair q; q.a = p.b; q.b = p.a; return q; }
int (*choose(int which))(int, int);
binop_p (*meta(int which))(int);
binop_p by(int k) { return k == 1 ? add : k == 2 ? sub : mul; }
int (*choose(int which))(int, int) { return which ? mul : add; }
binop_p (*meta(int which))(int) { if (which) return by; return 0; }
struct pair (*swapper(void))(struct pair) { return swap; }
int fold(binop *f, int *v, int n) { int r = v[0]; for (int i = 1; i < n; i++) r = f(r, v[i]); return r; }
int main(void) {
    binop *ops[3] = {add, sub, mul};
    handler *h = bump;
    int (*pf)(const char *, ...) = printf;
    int v[4] = {2, 3, 4, 5};
    int n = 1;
    h(&n);
    struct pair p = {1, 2};
    long (*cast)(long) = (long (*)(long))add;
    binop_p back = (binop_p)cast;
    pf("%d %d %d %d %d\n", fold(ops[0], v, 4), fold(ops[2], v, 4), choose(1)(6, 7), choose(0)(6, 7), n);
    pf("%d %d %d %ld %s\n", meta(1)(2)(9, 4), meta(0) == 0, swapper()(p).a, 4294967296L, "end");
    pf("%d %d %d\n", (n > 5 ? add : sub)(8, 3), (v[0] = 2, mul)(4, 5), back(20, 22));
    return by(3)(2, 3) + (pf != 0);
}
