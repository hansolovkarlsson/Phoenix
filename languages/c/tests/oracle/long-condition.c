int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long big = 4294967296; long zero = 0; int r = 0;
    if (big) r = r + 1; if (zero) r = r + 10; while (big) { big = big / 2; r = r + 100; }
    print(r); print(4294967296 > 1); print(-1 < zero); putchar(10); return 0;
}
