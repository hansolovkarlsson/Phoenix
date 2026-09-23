int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct mix { char a; int b; char c; char *d; int e[3]; char f; };
int main() {
    struct mix m; char k;
    m.a = 1; m.b = 2000000; m.c = 3; m.d = &k; m.e[0] = 5; m.e[1] = 6; m.e[2] = 7; m.f = 8; k = 9;
    print(m.a); print(m.b); print(m.c); print(*m.d); print(m.e[0]); print(m.e[1]); print(m.e[2]); print(m.f);
    putchar(10); return sizeof m;
}
