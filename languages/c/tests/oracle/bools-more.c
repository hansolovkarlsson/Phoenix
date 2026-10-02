int printf(const char *format, ...);
struct s { char c; _Bool on; int n; };
_Bool g = 512;
static _Bool table[3] = {0, 1024, [2] = 768};
_Bool truth(long x) { return x; }
int take(_Bool b) { return b; }
static const char *kind(int v) {
    switch (v) {
    case (_Bool)512: return "one";
    default: return "other";
    }
}
int main(void) {
    static _Bool once = 640;
    long wide = 4294967296L;
    int i = 256;
    _Bool a = wide;
    _Bool b;
    b = i;
    _Bool c = 0;
    c += 256;
    _Bool d = 0;
    d--;
    _Bool e = 1;
    e -= 1;
    _Bool v[2] = {i, 0};
    _Bool *p = &e;
    *p = 300;
    struct s st = {'x', 0, 7};
    st.on = 512;
    _Bool *lit = (_Bool []){i, 0};
    printf("%d %d %d %d %d %d\n", a, b, c, d, e, v[0]);
    printf("%d %d %d %d %d %d\n", g, table[1], table[2], truth(wide), take(i), (_Bool)i);
    printf("%d %d %s %d %d %d\n", st.on, lit[0], kind(1), (int)sizeof st, !a, once);
    return a + b + c + d + e + g;
}
