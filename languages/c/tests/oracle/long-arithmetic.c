int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long a = 2000000000; long b = a + a; long c = 100000; long d;
    print(b); print(c * c); print(b / 3); print(0 - b / 7); print(b - a * 3);
    d = c * c * 90000; print(d); print(d / c); putchar(10); return 0;
}
