int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct s { char a; char b[3]; char c; };
struct t { char a; int i; char b[2]; };
int main() {
    struct s x; struct t y;
    print(x.b - &x.a); print(&x.c - &x.a); print(&x.b[2] - x.b);
    print(y.b - &y.a); putchar(10);
    return 0;
}
