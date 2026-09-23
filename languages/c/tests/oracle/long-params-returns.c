int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
long mul(long a, int b) { return a * b; }
int narrow(long x) { return x; }
long widen(int x) { return x; }
long twice(long x);
int main() {
    print(mul(3000000000, -2)); print(mul(-1, 2)); print(mul(5, 7));
    print(narrow(4294967298)); print(narrow(-1)); print(widen(-9)); print(widen(2147483647));
    print(twice(-3000000000)); if (narrow(4294967296)) print(1); else print(0);
    putchar(10); return 0;
}
long twice(long x) { return x + x; }
