int printf(const char *format, ...);
struct flags { _Bool on; _Bool seen; int n; };
_Bool odd(int x) { return x % 2; }
int count(_Bool *v, int n) { int c = 0; for (int i = 0; i < n; i++) c += v[i]; return c; }
int main(void) {
    _Bool a = 256;
    _Bool b = 0;
    _Bool c = (_Bool)-3;
    int x = 5;
    int *q = &x;
    _Bool p = q;
    _Bool v[5] = {1, 0, 7, 0, 1};
    struct flags f = {2, 0, 3};
    b++;
    printf("%d %d %d %d %d\n", a, b, c, p, (int)sizeof(_Bool));
    printf("%d %d %d %d\n", odd(7), odd(4), count(v, 5), f.on + f.seen + f.n);
    if (a && !f.seen) printf("taken\n");
    return a + b + c + v[2];
}
