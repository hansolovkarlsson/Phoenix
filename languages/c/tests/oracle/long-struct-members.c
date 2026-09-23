int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct t { char c; long l; int i; };
struct u { int i; long l; };
int main() {
    struct t s; struct u v; struct t *q = &s;
    s.c = 3; s.l = -7000000000; s.i = 9; v.i = -1; v.l = 1;
    print(sizeof(struct t)); print(sizeof(struct u)); print(s.l + s.c + s.i); print(q->l / 1000);
    print(v.l + v.i); putchar(10); return 0;
}
