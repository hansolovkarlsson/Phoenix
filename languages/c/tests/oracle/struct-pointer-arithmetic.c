int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct t { int a; int b; int c; };
int main() {
    struct t a[5]; struct t *p; struct t *q;
    p = &a[1]; q = p + 3;
    print(q - p); print(p - q); print(&a[4] - a); print(a - &a[3]);
    (p + 2)->b = 77; print(a[3].b);
    q = q - 1; q->c = 88; print(a[3].c);
    p[-1].a = 55; print(a[0].a); print((q + (0 - 2))->c = 66); print(a[1].c);
    putchar(10);
    return 0;
}
