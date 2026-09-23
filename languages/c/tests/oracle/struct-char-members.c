int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct c { char a; char b; int n; };
int main() {
    struct c s; s.a = 200; s.b = 0 - 3; s.n = s.a + s.b;
    print(s.a); print(s.b); print(s.n); print((s.b = 300) / 2); putchar(10);
    return 0;
}
